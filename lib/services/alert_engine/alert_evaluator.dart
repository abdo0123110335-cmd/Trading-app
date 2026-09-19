import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/alert_engine/alert_models.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/rsi.dart';
import 'package:binance_spot_pro/services/scanner/scan_models.dart';
import 'package:binance_spot_pro/services/scanner/setup_detector.dart';
import 'package:binance_spot_pro/services/signal_engine/score_calculator.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_engine.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';
import 'package:binance_spot_pro/services/strategy_engine/rsi_ema_strategy.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

class AlertTriggerResult {
  const AlertTriggerResult({required this.message, required this.price});
  final String message;
  final double price;
}

/// Evaluates one alert against the latest candle close. Reuses the
/// Strategy/Score/SMC/Signal/Scanner engines built in earlier phases
/// rather than re-deriving RSI/EMA/SMC logic here — an alert firing and a
/// signal/scan result agreeing with each other matters more than this
/// function being self-contained.
AlertTriggerResult? evaluateAlert(
  AlertType type,
  AlertCondition condition,
  List<Candle> candles,
  StrategyConfig config,
) {
  if (candles.length < 60) return null;
  final price = candles.last.close;
  final closes = candles.closes();

  switch (type) {
    case AlertType.price:
      return _thresholdResult(condition, price, price, (v) => 'Price crossed $v');

    case AlertType.rsi:
      final rsiSeries = rsi(closes, config.rsiLength);
      final rsiNow = rsiSeries.isEmpty ? null : rsiSeries.last;
      if (rsiNow == null) return null;
      return _thresholdResult(
        condition,
        rsiNow,
        price,
        (v) => 'RSI(${config.rsiLength}) at ${rsiNow.toStringAsFixed(1)}',
      );

    case AlertType.scoreThreshold:
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      final score = computeScore(evaluation, config);
      return _thresholdResult(
        condition,
        score.total.toDouble(),
        price,
        (v) => 'Score ${score.total}/100',
      );

    case AlertType.emaCross:
    case AlertType.volumeSpike:
    case AlertType.breakout:
      return _eventTagResult(type, candles, config, price);

    case AlertType.macdCross:
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      if (!evaluation.macdFilter.passed) return null;
      return AlertTriggerResult(message: 'MACD bullish (histogram positive)', price: price);

    case AlertType.smcSignal:
      return _smcSignalResult(candles, config, price);

    case AlertType.supportBreak:
      return _structureBreakResult(candles, price, breakBelow: true);

    case AlertType.resistanceBreak:
      return _structureBreakResult(candles, price, breakBelow: false);

    case AlertType.bos:
    case AlertType.choch:
      return _structureEventResult(type, candles, config, price);

    case AlertType.fvg:
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      final hasFreshGap = evaluation.smc.fairValueGaps.any(
        (g) => !g.filled && g.index >= candles.length - 3,
      );
      if (!hasFreshGap) return null;
      return AlertTriggerResult(message: 'New Fair Value Gap formed', price: price);

    case AlertType.buySignal:
      final signal = generateSignal('', '', candles, config);
      if (signal.type != SignalType.buy) return null;
      return AlertTriggerResult(message: 'BUY setup — score ${signal.score}/100', price: price);
  }
}

AlertTriggerResult? _thresholdResult(
  AlertCondition condition,
  double comparedValue,
  double price,
  String Function(double value) message,
) {
  final op = condition.operator;
  final value = condition.value;
  if (op == null || value == null) return null;
  if (!op.compare(comparedValue, value)) return null;
  return AlertTriggerResult(message: message(value), price: price);
}

AlertTriggerResult? _eventTagResult(
  AlertType type,
  List<Candle> candles,
  StrategyConfig config,
  double price,
) {
  final evaluation = evaluateRsiEmaStrategy(candles, config);
  final signal = generateSignal('', '', candles, config);
  final tags = detectSetupTags(candles, evaluation, signal);
  final tag = type == AlertType.emaCross
      ? ScanSetupTag.emaCross
      : type == AlertType.volumeSpike
      ? ScanSetupTag.volumeSpike
      : ScanSetupTag.breakout;
  if (!tags.contains(tag)) return null;
  return AlertTriggerResult(message: '${type.label} detected', price: price);
}

AlertTriggerResult? _smcSignalResult(List<Candle> candles, StrategyConfig config, double price) {
  final evaluation = evaluateRsiEmaStrategy(candles, config);
  final signal = generateSignal('', '', candles, config);
  final tags = detectSetupTags(candles, evaluation, signal);
  final hasAnySmcEvent = tags.contains(ScanSetupTag.bos) ||
      tags.contains(ScanSetupTag.choch) ||
      tags.contains(ScanSetupTag.fvg) ||
      tags.contains(ScanSetupTag.supportBounce);
  if (!hasAnySmcEvent) return null;
  return AlertTriggerResult(message: 'New SMC event detected', price: price);
}

AlertTriggerResult? _structureEventResult(
  AlertType type,
  List<Candle> candles,
  StrategyConfig config,
  double price,
) {
  final evaluation = evaluateRsiEmaStrategy(candles, config);
  final lastEvent = evaluation.smc.lastEvent;
  final isRecent = lastEvent != null && lastEvent.index >= candles.length - 2;
  if (!isRecent) return null;
  final matches = (type == AlertType.bos && lastEvent.type == StructureEventType.bos) ||
      (type == AlertType.choch && lastEvent.type == StructureEventType.choch);
  if (!matches) return null;
  return AlertTriggerResult(
    message: '${type.label} detected (${lastEvent.direction.name})',
    price: price,
  );
}

/// Support/Resistance break: the latest bar closes through the nearest
/// demand/supply zone (or, failing that, the nearest recent swing
/// low/high) — and the *prior* bar had not already closed through it, so
/// the alert fires once on the break rather than repeatedly while price
/// sits beyond the level.
AlertTriggerResult? _structureBreakResult(
  List<Candle> candles,
  double price, {
  required bool breakBelow,
}) {
  final smc = analyzeSmc(candles);
  double? level;

  if (breakBelow) {
    final zonesBelow = smc.demandZones.where((z) => z.low < price).toList()
      ..sort((a, b) => b.low.compareTo(a.low));
    if (zonesBelow.isNotEmpty) {
      level = zonesBelow.first.low;
    } else {
      final lows = smc.swingPoints.where((s) => s.type == SwingType.low && s.price < price);
      if (lows.isNotEmpty) level = lows.last.price;
    }
  } else {
    final zonesAbove = smc.supplyZones.where((z) => z.high > price).toList()
      ..sort((a, b) => a.high.compareTo(b.high));
    if (zonesAbove.isNotEmpty) {
      level = zonesAbove.first.high;
    } else {
      final highs = smc.swingPoints.where((s) => s.type == SwingType.high && s.price > price);
      if (highs.isNotEmpty) level = highs.last.price;
    }
  }

  if (level == null || candles.length < 2) return null;
  final priorClose = candles[candles.length - 2].close;

  final brokeNow = breakBelow
      ? (price < level && priorClose >= level)
      : (price > level && priorClose <= level);
  if (!brokeNow) return null;

  return AlertTriggerResult(
    message: breakBelow
        ? 'Support broken near ${level.toStringAsFixed(4)}'
        : 'Resistance broken near ${level.toStringAsFixed(4)}',
    price: price,
  );
}
