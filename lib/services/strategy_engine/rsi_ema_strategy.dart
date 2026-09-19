import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/macd.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/rsi.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_engine.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

/// Result of one optional filter check - carries enough to build a
/// human-readable "reason" for the Signal Engine's `reasonsJson`.
class FilterCheck {
  const FilterCheck({required this.enabled, required this.passed, required this.reason});
  final bool enabled;
  final bool passed;
  final String reason;

  /// A disabled filter never blocks a BUY - only enabled-and-failed does.
  bool get blocks => enabled && !passed;
}

class StrategyEvaluation {
  const StrategyEvaluation({
    required this.rsiValue,
    required this.rsiTriggered,
    required this.emaFilter,
    required this.volumeFilter,
    required this.macdFilter,
    required this.trendFilter,
    required this.supportFilter,
    required this.smcFilter,
    required this.smc,
  });

  final double? rsiValue;
  final bool rsiTriggered;
  final FilterCheck emaFilter;
  final FilterCheck volumeFilter;
  final FilterCheck macdFilter;
  final FilterCheck trendFilter;
  final FilterCheck supportFilter;
  final FilterCheck smcFilter;
  final SmcAnalysis smc;

  List<FilterCheck> get allFilters =>
      [emaFilter, volumeFilter, macdFilter, trendFilter, supportFilter, smcFilter];

  /// The core RSI condition fired AND no enabled filter blocked it. This
  /// is the strategy's raw pass/fail - the Score System separately scores
  /// how strongly each component supports the trade.
  bool get passesStrategy => rsiTriggered && allFilters.every((f) => !f.blocks);
}

/// Evaluates the RSI+EMA strategy (with optional filters) against the
/// most recent candle in [candles]. Requires at least ~60 candles for the
/// slower filters (EMA 50, MACD 26/9) to be meaningful.
StrategyEvaluation evaluateRsiEmaStrategy(List<Candle> candles, StrategyConfig config) {
  final closes = candles.closes();
  final volumes = candles.volumes();
  final smc = analyzeSmc(candles);

  final rsiSeries = rsi(closes, config.rsiLength);
  final rsiNow = rsiSeries.isEmpty ? null : rsiSeries.last;
  final rsiPrev = rsiSeries.length >= 2 ? rsiSeries[rsiSeries.length - 2] : null;
  final rsiTriggered = rsiNow != null &&
      (rsiNow <= config.rsiOversold ||
          (rsiPrev != null && rsiPrev > config.rsiOversold && rsiNow <= config.rsiOversold));

  final ema50 = ema(closes, 50);
  final emaOk = ema50.isNotEmpty && ema50.last != null && closes.last > ema50.last!;
  final emaFilter = FilterCheck(
    enabled: config.filterEmaEnabled,
    passed: emaOk,
    reason: emaOk ? 'Price above EMA(50)' : 'Price below EMA(50)',
  );

  final volSma = sma(volumes, 20);
  final volOk = volSma.isNotEmpty && volSma.last != null && volumes.last > volSma.last!;
  final volumeFilter = FilterCheck(
    enabled: config.filterVolumeEnabled,
    passed: volOk,
    reason: volOk ? 'Volume above 20-bar average' : 'Volume below 20-bar average',
  );

  final macdResult = macd(closes);
  final macdOk = macdResult.histogram.isNotEmpty &&
      macdResult.histogram.last != null &&
      macdResult.histogram.last! > 0;
  final macdFilter = FilterCheck(
    enabled: config.filterMacdEnabled,
    passed: macdOk,
    reason: macdOk ? 'MACD histogram positive' : 'MACD histogram negative',
  );

  final ema21 = ema(closes, 21);
  final trendOk = ema21.isNotEmpty &&
      ema50.isNotEmpty &&
      ema21.last != null &&
      ema50.last != null &&
      ema21.last! > ema50.last!;
  final trendFilter = FilterCheck(
    enabled: config.filterTrendEnabled,
    passed: trendOk,
    reason: trendOk ? 'EMA(21) above EMA(50) - uptrend' : 'EMA(21) below EMA(50) - no uptrend',
  );

  final supportOk = _isNearSupport(candles.last.close, smc);
  final supportFilter = FilterCheck(
    enabled: config.filterSupportEnabled,
    passed: supportOk,
    reason: supportOk ? 'Price near a support level' : 'Price not near a known support level',
  );

  final smcOk =
      smc.currentTrend == TrendDirection.bullish || smc.currentZone == PriceZone.discount;
  final smcFilter = FilterCheck(
    enabled: config.filterSmcEnabled,
    passed: smcOk,
    reason: smcOk ? 'SMC structure/zone supportive' : 'SMC structure/zone not supportive',
  );

  return StrategyEvaluation(
    rsiValue: rsiNow,
    rsiTriggered: rsiTriggered,
    emaFilter: emaFilter,
    volumeFilter: volumeFilter,
    macdFilter: macdFilter,
    trendFilter: trendFilter,
    supportFilter: supportFilter,
    smcFilter: smcFilter,
    smc: smc,
  );
}

bool _isNearSupport(double price, SmcAnalysis smc, {double tolerancePct = 0.015}) {
  for (final zone in smc.demandZones) {
    if (price >= zone.low * (1 - tolerancePct) && price <= zone.high * (1 + tolerancePct)) {
      return true;
    }
  }
  for (final level in smc.equalLows) {
    if ((price - level.price).abs() <= level.price * tolerancePct) return true;
  }
  return false;
}
