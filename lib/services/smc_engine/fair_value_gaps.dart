import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';

/// Detects 3-candle Fair Value Gaps: candle[i-1] and candle[i+1] leave a
/// price gap that candle[i] (the impulse candle) jumped over.
///   * Bullish FVG: candle[i-1].high < candle[i+1].low
///   * Bearish FVG: candle[i-1].low  > candle[i+1].high
List<FairValueGap> detectFairValueGaps(List<Candle> candles) {
  final gaps = <FairValueGap>[];
  for (var i = 1; i < candles.length - 1; i++) {
    final left = candles[i - 1];
    final right = candles[i + 1];

    if (left.high < right.low) {
      gaps.add(
        FairValueGap(index: i, top: right.low, bottom: left.high, type: FvgType.bullish),
      );
    } else if (left.low > right.high) {
      gaps.add(
        FairValueGap(index: i, top: left.low, bottom: right.high, type: FvgType.bearish),
      );
    }
  }
  return _markFilled(gaps, candles);
}

/// A gap is "filled" once price has traded back through the full gap
/// range after it formed.
List<FairValueGap> _markFilled(List<FairValueGap> gaps, List<Candle> candles) {
  return gaps.map((g) {
    for (var i = g.index + 2; i < candles.length; i++) {
      final c = candles[i];
      if (c.low <= g.bottom && c.high >= g.top) {
        return g.copyWith(filled: true);
      }
    }
    return g;
  }).toList();
}
