import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';
import 'package:binance_spot_pro/services/scanner/scan_models.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';
import 'package:binance_spot_pro/services/strategy_engine/rsi_ema_strategy.dart';

/// Derives the named setup tags for one symbol from data already computed
/// by the Strategy/SMC/Signal engines — no indicator is calculated twice.
Set<ScanSetupTag> detectSetupTags(
  List<Candle> candles,
  StrategyEvaluation evaluation,
  SignalResult signal, {
  int breakoutLookback = 20,
  double volumeSpikeMultiplier = 2.0,
}) {
  final tags = <ScanSetupTag>{};
  final closes = candles.closes();
  final volumes = candles.volumes();

  if (evaluation.rsiTriggered) tags.add(ScanSetupTag.oversold);
  if (signal.type == SignalType.buy) tags.add(ScanSetupTag.buySetup);

  // Breakout: current close clears the highest high of the prior N bars.
  if (candles.length > breakoutLookback) {
    final windowStart = candles.length - 1 - breakoutLookback;
    var priorHigh = candles[windowStart].high;
    for (var i = windowStart; i < candles.length - 1; i++) {
      if (candles[i].high > priorHigh) priorHigh = candles[i].high;
    }
    if (candles.last.close > priorHigh) tags.add(ScanSetupTag.breakout);
  }

  // Volume spike: current volume well above its 20-bar average.
  final volSma = sma(volumes, 20);
  if (volSma.isNotEmpty && volSma.last != null && volSma.last! > 0) {
    if (volumes.last > volSma.last! * volumeSpikeMultiplier) {
      tags.add(ScanSetupTag.volumeSpike);
    }
  }

  // FVG: an unfilled gap exists anywhere in the recent structure.
  if (evaluation.smc.fairValueGaps.any((g) => !g.filled)) tags.add(ScanSetupTag.fvg);

  // BOS / CHoCH: the most recent structure event, if it happened recently
  // (within the last 5 bars — otherwise it's stale, not a live setup).
  final lastEvent = evaluation.smc.lastEvent;
  if (lastEvent != null && lastEvent.index >= candles.length - 5) {
    if (lastEvent.type == StructureEventType.bos) tags.add(ScanSetupTag.bos);
    if (lastEvent.type == StructureEventType.choch) tags.add(ScanSetupTag.choch);
  }

  // Support bounce: price dipped into a demand zone/support level on a
  // recent bar and closed back above it.
  if (_isSupportBounce(candles, evaluation)) tags.add(ScanSetupTag.supportBounce);

  // EMA cross: EMA(21) crossed above EMA(50) within the last 3 bars.
  if (_recentBullishEmaCross(closes)) tags.add(ScanSetupTag.emaCross);

  return tags;
}

bool _isSupportBounce(List<Candle> candles, StrategyEvaluation evaluation) {
  if (candles.length < 2) return false;
  final last = candles.last;
  final prior = candles[candles.length - 2];
  final dippedIntoSupport = evaluation.smc.demandZones.any(
    (z) => prior.low <= z.high && prior.low >= z.low * 0.98,
  );
  return dippedIntoSupport && last.close > prior.low && last.close > last.open;
}

bool _recentBullishEmaCross(List<double> closes, {int lookback = 3}) {
  final ema21 = ema(closes, 21);
  final ema50 = ema(closes, 50);
  if (ema21.length < lookback + 1 || ema50.length < lookback + 1) return false;

  for (var i = closes.length - lookback; i < closes.length; i++) {
    if (i < 1) continue;
    final prev21 = ema21[i - 1];
    final prev50 = ema50[i - 1];
    final cur21 = ema21[i];
    final cur50 = ema50[i];
    if (prev21 == null || prev50 == null || cur21 == null || cur50 == null) continue;
    if (prev21 <= prev50 && cur21 > cur50) return true;
  }
  return false;
}
