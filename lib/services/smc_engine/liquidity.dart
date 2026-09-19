import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';

/// Groups swing highs (or lows) that sit within [tolerancePct] of each
/// other into "equal highs/lows" — resting liquidity pools.
List<EqualLevel> detectEqualLevels(
  List<SwingPoint> swings,
  SwingType type, {
  double tolerancePct = 0.001,
}) {
  final relevant = swings.where((s) => s.type == type).toList()
    ..sort((a, b) => a.price.compareTo(b.price));

  final levels = <EqualLevel>[];
  var i = 0;
  while (i < relevant.length) {
    final group = [relevant[i]];
    var j = i + 1;
    while (j < relevant.length &&
        (relevant[j].price - group.first.price).abs() <= group.first.price * tolerancePct) {
      group.add(relevant[j]);
      j++;
    }
    if (group.length >= 2) {
      final avgPrice = group.map((s) => s.price).reduce((a, b) => a + b) / group.length;
      levels.add(
        EqualLevel(
          indices: group.map((s) => s.index).toList()..sort(),
          price: avgPrice,
          type: type,
        ),
      );
    }
    i = j;
  }
  return levels;
}

/// A liquidity sweep: a candle wicks beyond a prior swing point (grabbing
/// the resting stop-loss/breakout orders sitting there) but closes back
/// on the other side — a classic SMC reversal tell.
List<LiquiditySweep> detectLiquiditySweeps(List<Candle> candles, List<SwingPoint> swings) {
  final sweeps = <LiquiditySweep>[];

  for (final swing in swings) {
    for (var i = swing.index + 1; i < candles.length; i++) {
      final c = candles[i];
      if (swing.type == SwingType.high) {
        if (c.high > swing.price && c.close < swing.price) {
          sweeps.add(LiquiditySweep(index: i, sweptLevel: swing.price, type: SwingType.high));
          break;
        }
        if (c.close > swing.price) break; // structure broke cleanly, not a sweep
      } else {
        if (c.low < swing.price && c.close > swing.price) {
          sweeps.add(LiquiditySweep(index: i, sweptLevel: swing.price, type: SwingType.low));
          break;
        }
        if (c.close < swing.price) break;
      }
    }
  }
  return sweeps;
}
