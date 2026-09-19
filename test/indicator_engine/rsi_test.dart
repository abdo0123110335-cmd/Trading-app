import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/rsi.dart';

void main() {
  group('rsi', () {
    test('stays within [0, 100] for a realistic price walk', () {
      final prices = [
        44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08,
        45.89, 46.03, 45.61, 46.28, 46.28, 46.00, 46.03, 46.41, 46.22, 45.64,
      ];
      final result = rsi(prices, 14);
      for (final v in result) {
        if (v != null) {
          expect(v, inInclusiveRange(0, 100));
        }
      }
      expect(result[14], isNotNull);
    });

    test('returns 100 when there are only gains in the window', () {
      final prices = List<double>.generate(10, (i) => 10.0 + i);
      final result = rsi(prices, 6);
      expect(result[6], closeTo(100, 1e-9));
    });

    test('incremental RSI matches batch RSI after seeding', () {
      final prices = [
        44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08,
        45.89, 46.03, 45.61, 46.28, 46.28,
      ];
      final batch = rsi(prices, 6);
      final inc = RsiIncremental(length: 6);
      inc.seedFromValues(prices);
      expect(inc.value, closeTo(batch.last!, 1e-6));
    });
  });
}
