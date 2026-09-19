import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';

/// Detects order blocks: the last down-candle before a strong up-move
/// (bullish order block) or the last up-candle before a strong down-move
/// (bearish order block). "Strong move" = the impulse candle's body is at
/// least [impulseFactor] times the average body size of the preceding
/// [lookback] candles — a simple, explainable stand-in for "displacement".
List<OrderBlock> detectOrderBlocks(
  List<Candle> candles, {
  int lookback = 10,
  double impulseFactor = 1.8,
}) {
  final blocks = <OrderBlock>[];
  if (candles.length < lookback + 2) return blocks;

  for (var i = lookback; i < candles.length; i++) {
    final impulse = candles[i];
    final impulseBody = (impulse.close - impulse.open).abs();

    double avgBody = 0;
    for (var j = i - lookback; j < i; j++) {
      avgBody += (candles[j].close - candles[j].open).abs();
    }
    avgBody /= lookback;
    if (avgBody == 0 || impulseBody < avgBody * impulseFactor) continue;

    final isBullishImpulse = impulse.close > impulse.open;
    final priorIndex = i - 1;
    if (priorIndex < 0) continue;
    final prior = candles[priorIndex];

    if (isBullishImpulse && prior.close < prior.open) {
      blocks.add(
        OrderBlock(
          startIndex: priorIndex,
          high: prior.high,
          low: prior.low,
          type: OrderBlockType.bullish,
        ),
      );
    } else if (!isBullishImpulse && prior.close > prior.open) {
      blocks.add(
        OrderBlock(
          startIndex: priorIndex,
          high: prior.high,
          low: prior.low,
          type: OrderBlockType.bearish,
        ),
      );
    }
  }

  return _markMitigated(blocks, candles);
}

/// An order block is "mitigated" once price has traded back through its
/// range after formation — traders generally stop trusting a mitigated
/// block as a reaction zone.
List<OrderBlock> _markMitigated(List<OrderBlock> blocks, List<Candle> candles) {
  return blocks.map((b) {
    for (var i = b.startIndex + 2; i < candles.length; i++) {
      final c = candles[i];
      if (c.low <= b.high && c.high >= b.low) {
        return b.copyWith(mitigated: true);
      }
    }
    return b;
  }).toList();
}
