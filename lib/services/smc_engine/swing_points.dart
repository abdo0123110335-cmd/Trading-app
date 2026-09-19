import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';

/// Detects swing highs/lows using the standard fractal method: a bar is a
/// swing high if its high is the highest of the `strength` bars on each
/// side of it (and symmetrically for swing lows). This is the same method
/// TradingView's "Pivot High/Low" and most SMC indicators use.
List<SwingPoint> detectSwingPoints(List<Candle> candles, {int strength = 2}) {
  final points = <SwingPoint>[];
  final n = candles.length;

  for (var i = strength; i < n - strength; i++) {
    final high = candles[i].high;
    final low = candles[i].low;

    var isSwingHigh = true;
    var isSwingLow = true;
    for (var j = i - strength; j <= i + strength; j++) {
      if (j == i) continue;
      if (candles[j].high >= high) isSwingHigh = false;
      if (candles[j].low <= low) isSwingLow = false;
    }

    if (isSwingHigh) {
      points.add(SwingPoint(index: i, price: high, type: SwingType.high));
    }
    if (isSwingLow) {
      points.add(SwingPoint(index: i, price: low, type: SwingType.low));
    }
  }

  points.sort((a, b) => a.index.compareTo(b.index));
  return points;
}
