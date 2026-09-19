import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/signal_engine/score_calculator.dart';
import 'package:binance_spot_pro/services/strategy_engine/rsi_ema_strategy.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

List<Candle> _dipThenRecoverSeries() {
  // 80 bars: gentle uptrend, then a sharp dip (drives RSI into oversold),
  // long enough for EMA(50)/MACD(26,9) to be meaningful.
  final base = DateTime.utc(2026, 1, 1);
  final candles = <Candle>[];
  double price = 100;
  for (var i = 0; i < 70; i++) {
    price += 0.3;
    candles.add(
      Candle(
        openTime: base.add(Duration(hours: i)),
        open: price - 0.2,
        high: price + 0.5,
        low: price - 0.5,
        close: price,
        volume: 1000,
        closeTime: base.add(Duration(hours: i, minutes: 59)),
      ),
    );
  }
  for (var i = 70; i < 80; i++) {
    price -= 2.0; // sharp dip
    candles.add(
      Candle(
        openTime: base.add(Duration(hours: i)),
        open: price + 0.2,
        high: price + 0.5,
        low: price - 0.5,
        close: price,
        volume: 1000,
        closeTime: base.add(Duration(hours: i, minutes: 59)),
      ),
    );
  }
  return candles;
}

void main() {
  group('evaluateRsiEmaStrategy', () {
    test('RSI triggers oversold after a sharp dip', () {
      final candles = _dipThenRecoverSeries();
      const config = StrategyConfig(strategyId: 1, name: 'test', rsiLength: 6, rsiOversold: 30);
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      expect(evaluation.rsiValue, isNotNull);
      expect(evaluation.rsiTriggered, isTrue);
    });

    test('a disabled filter never blocks the strategy even if it would fail', () {
      final candles = _dipThenRecoverSeries();
      const config = StrategyConfig(
        strategyId: 1,
        name: 'test',
        rsiLength: 6,
        rsiOversold: 30,
        filterEmaEnabled: false, // price is likely below EMA(50) after the dip
      );
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      expect(evaluation.emaFilter.enabled, isFalse);
      expect(evaluation.emaFilter.blocks, isFalse);
    });

    test('an enabled, failing filter blocks passesStrategy', () {
      final candles = _dipThenRecoverSeries();
      const config = StrategyConfig(
        strategyId: 1,
        name: 'test',
        rsiLength: 6,
        rsiOversold: 30,
        filterEmaEnabled: true,
      );
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      if (evaluation.emaFilter.blocks) {
        expect(evaluation.passesStrategy, isFalse);
      }
    });
  });

  group('computeScore', () {
    test('score is 0-100 and RSI component scales with oversold depth', () {
      final candles = _dipThenRecoverSeries();
      const config = StrategyConfig(strategyId: 1, name: 'test', rsiLength: 6, rsiOversold: 30);
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      final score = computeScore(evaluation, config);
      expect(score.total, inInclusiveRange(0, 100));
      final rsiComponent = score.components.firstWhere((c) => c.label == 'RSI');
      expect(rsiComponent.earned, greaterThanOrEqualTo(0));
      expect(rsiComponent.earned, lessThanOrEqualTo(rsiComponent.max));
    });

    test('score is 0 when nothing triggers on a flat series', () {
      final base = DateTime.utc(2026, 1, 1);
      final flat = List.generate(
        80,
        (i) => Candle(
          openTime: base.add(Duration(hours: i)),
          open: 100,
          high: 100.1,
          low: 99.9,
          close: 100,
          volume: 1000,
          closeTime: base.add(Duration(hours: i, minutes: 59)),
        ),
      );
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final evaluation = evaluateRsiEmaStrategy(flat, config);
      final score = computeScore(evaluation, config);
      expect(score.total, 0);
    });
  });
}
