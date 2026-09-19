import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/atr.dart';
import 'package:binance_spot_pro/services/signal_engine/score_calculator.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';
import 'package:binance_spot_pro/services/strategy_engine/rsi_ema_strategy.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

/// Spot-only signal types. There is deliberately no SHORT/SELL-to-open
/// value here, per the "no Short" hard requirement.
enum SignalType { buy, hold, exit }

class SignalResult {
  const SignalResult({
    required this.symbol,
    required this.timeframe,
    required this.type,
    required this.price,
    required this.score,
    required this.reasons,
    required this.entryLow,
    required this.entryHigh,
    required this.invalidation,
    required this.tp1,
    required this.tp2,
    required this.timestamp,
  });

  final String symbol;
  final String timeframe;
  final SignalType type;
  final double price;
  final int score;
  final List<String> reasons;
  final double? entryLow;
  final double? entryHigh;
  final double? invalidation;
  final double? tp1;
  final double? tp2;
  final DateTime timestamp;
}

/// Generates one signal for the latest candle of [candles], per the
/// spec's Signal Engine rules:
///   * Score below `minBuyScore` → never BUY, regardless of the strategy
///     condition (a below-threshold score is HOLD at best).
///   * Score at/above `minBuyScore` AND the RSI+EMA strategy condition
///     (with its enabled filters) passes → BUY.
///   * RSI reaching the overbought threshold, or a fresh bearish CHoCH,
///     signals taking profit / exiting an existing long → EXIT.
///   * Anything else → HOLD.
SignalResult generateSignal(
  String symbol,
  String timeframe,
  List<Candle> candles,
  StrategyConfig config,
) {
  final evaluation = evaluateRsiEmaStrategy(candles, config);
  final scoreResult = computeScore(evaluation, config);
  final price = candles.last.close;

  final reasons = <String>[];
  if (evaluation.rsiTriggered) {
    reasons.add('RSI(${config.rsiLength}) at ${evaluation.rsiValue?.toStringAsFixed(1)} — oversold');
  }
  for (final f in evaluation.allFilters) {
    if (f.enabled) reasons.add(f.reason);
  }

  final recentChoch = evaluation.smc.structureEvents.isNotEmpty &&
      evaluation.smc.structureEvents.last.type == StructureEventType.choch &&
      evaluation.smc.structureEvents.last.direction == TrendDirection.bearish &&
      evaluation.smc.structureEvents.last.index >= candles.length - 3;

  final isOverbought = evaluation.rsiValue != null && evaluation.rsiValue! >= config.rsiOverbought;

  SignalType type;
  if (scoreResult.total >= config.minBuyScore && evaluation.passesStrategy) {
    type = SignalType.buy;
  } else if (isOverbought || recentChoch) {
    type = SignalType.exit;
    if (isOverbought) reasons.add('RSI(${config.rsiLength}) at ${evaluation.rsiValue?.toStringAsFixed(1)} — overbought');
    if (recentChoch) reasons.add('Bearish CHoCH detected — structure turning down');
  } else {
    type = SignalType.hold;
  }

  double? entryLow, entryHigh, invalidation, tp1, tp2;
  if (type == SignalType.buy) {
    final atrSeries = atrFromOhlc(candles.highs(), candles.lows(), candles.closes(), length: 14);
    final atr = atrSeries.isNotEmpty && atrSeries.last != null ? atrSeries.last! : price * 0.01;

    entryLow = price - atr * 0.3;
    entryHigh = price + atr * 0.3;

    // Invalidation below the nearest recent swing low, if one is close
    // enough to be relevant; otherwise a straight ATR-based stop.
    final recentLow = evaluation.smc.swingPoints
        .where((s) => s.type == SwingType.low && s.price < price)
        .toList();
    if (recentLow.isNotEmpty) {
      final nearest = recentLow.last;
      invalidation = nearest.price - atr * 0.2;
    } else {
      invalidation = price - atr * 1.5;
    }

    final risk = price - invalidation;
    tp1 = price + risk * 1.5;
    tp2 = price + risk * 3.0;
  }

  return SignalResult(
    symbol: symbol,
    timeframe: timeframe,
    type: type,
    price: price,
    score: scoreResult.total,
    reasons: reasons,
    entryLow: entryLow,
    entryHigh: entryHigh,
    invalidation: invalidation,
    tp1: tp1,
    tp2: tp2,
    timestamp: candles.last.openTime,
  );
}
