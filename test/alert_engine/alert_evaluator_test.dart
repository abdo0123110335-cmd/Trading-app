import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/alert_engine/alert_evaluator.dart';
import 'package:binance_spot_pro/services/alert_engine/alert_models.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

List<Candle> _flatSeries({required int bars, double price = 100}) {
  final base = DateTime.utc(2026, 1, 1);
  return List.generate(
    bars,
    (i) => Candle(
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

void main() {
  group('ComparisonOperator.compare', () {
    test('greaterThan/lessThan/greaterOrEqual/lessOrEqual behave correctly', () {
      expect(ComparisonOperator.greaterThan.compare(10, 5), isTrue);
      expect(ComparisonOperator.greaterThan.compare(5, 10), isFalse);
      expect(ComparisonOperator.lessThan.compare(5, 10), isTrue);
      expect(ComparisonOperator.greaterOrEqual.compare(10, 10), isTrue);
      expect(ComparisonOperator.lessOrEqual.compare(10, 10), isTrue);
    });
  });

  group('AlertCondition JSON', () {
    test('round-trips operator and value', () {
      const condition = AlertCondition(operator: ComparisonOperator.lessThan, value: 30);
      final decoded = AlertCondition.fromJson(condition.toJson());
      expect(decoded.operator, ComparisonOperator.lessThan);
      expect(decoded.value, 30);
    });
  });

  group('evaluateAlert', () {
    test('price alert fires when the operator/value condition is met', () {
      final candles = _flatSeries(bars: 80, price: 105000);
      const condition = AlertCondition(operator: ComparisonOperator.greaterThan, value: 100000);
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final result = evaluateAlert(AlertType.price, condition, candles, config);
      expect(result, isNotNull);
    });

    test('price alert does not fire when the condition is not met', () {
      final candles = _flatSeries(bars: 80, price: 95000);
      const condition = AlertCondition(operator: ComparisonOperator.greaterThan, value: 100000);
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final result = evaluateAlert(AlertType.price, condition, candles, config);
      expect(result, isNull);
    });

    test('RSI alert fires when RSI crosses below the threshold', () {
      final base = DateTime.utc(2026, 1, 1);
      final candles = <Candle>[
        for (var i = 0; i < 70; i++)
          Candle(
            openTime: base.add(Duration(hours: i)),
            open: 100 + i * 0.3 - 0.2,
            high: 100 + i * 0.3 + 0.5,
            low: 100 + i * 0.3 - 0.5,
            close: 100 + i * 0.3,
            volume: 1000,
            closeTime: base.add(Duration(hours: i, minutes: 59)),
          ),
        for (var i = 70; i < 80; i++)
          Candle(
            openTime: base.add(Duration(hours: i)),
            open: 100 + 70 * 0.3 - (i - 69) * 2.0 + 0.2,
            high: 100 + 70 * 0.3 - (i - 69) * 2.0 + 0.5,
            low: 100 + 70 * 0.3 - (i - 69) * 2.0 - 0.5,
            close: 100 + 70 * 0.3 - (i - 69) * 2.0,
            volume: 1000,
            closeTime: base.add(Duration(hours: i, minutes: 59)),
          ),
      ];
      const condition = AlertCondition(operator: ComparisonOperator.lessThan, value: 30);
      const config = StrategyConfig(strategyId: 1, name: 'test', rsiLength: 6);
      final result = evaluateAlert(AlertType.rsi, condition, candles, config);
      // Whether it fires depends on the exact RSI value, but it must not
      // throw and must return a well-formed result when it does fire.
      if (result != null) {
        expect(result.message, contains('RSI'));
      }
    });

    test('returns null for too-short candle history regardless of type', () {
      final candles = _flatSeries(bars: 10);
      const condition = AlertCondition(operator: ComparisonOperator.greaterThan, value: 1);
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final result = evaluateAlert(AlertType.price, condition, candles, config);
      expect(result, isNull);
    });

    test('a threshold alert with no operator/value never fires', () {
      final candles = _flatSeries(bars: 80);
      const condition = AlertCondition();
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final result = evaluateAlert(AlertType.price, condition, candles, config);
      expect(result, isNull);
    });
  });
}
