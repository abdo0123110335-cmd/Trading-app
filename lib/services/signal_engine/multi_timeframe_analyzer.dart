import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';

enum TrendReading { bullish, neutral, bearish }

/// The five timeframes the spec's Multi-Timeframe Analysis section calls
/// for, in Binance kline interval format.
const multiTimeframeIntervals = ['5m', '15m', '1h', '4h', '1d'];

/// Classifies one timeframe's trend from EMA(21) vs EMA(50): short-term
/// average clearly above the long-term average = bullish, clearly below =
/// bearish, otherwise neutral (the two are close together / chopping).
TrendReading classifyTimeframeTrend(List<Candle> candles, {double neutralBandPct = 0.002}) {
  if (candles.length < 55) return TrendReading.neutral;
  final closes = candles.closes();
  final ema21 = ema(closes, 21).last;
  final ema50 = ema(closes, 50).last;
  if (ema21 == null || ema50 == null || ema50 == 0) return TrendReading.neutral;

  final diffPct = (ema21 - ema50) / ema50;
  if (diffPct > neutralBandPct) return TrendReading.bullish;
  if (diffPct < -neutralBandPct) return TrendReading.bearish;
  return TrendReading.neutral;
}

/// Runs [classifyTimeframeTrend] across a pre-fetched map of
/// timeframe → candles (the caller is responsible for fetching each
/// timeframe via the Market Data Manager — this function is pure).
Map<String, TrendReading> analyzeMultiTimeframe(Map<String, List<Candle>> candlesByTimeframe) {
  return {
    for (final entry in candlesByTimeframe.entries)
      entry.key: classifyTimeframeTrend(entry.value),
  };
}
