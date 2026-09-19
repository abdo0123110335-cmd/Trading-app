import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/moving_averages.dart';

void main() {
  group('sma', () {
    test('computes correct rolling average with warm-up nulls', () {
      final result = sma([1, 2, 3, 4, 5], 3);
      expect(result[0], isNull);
      expect(result[1], isNull);
      expect(result[2], closeTo(2.0, 1e-9)); // avg(1,2,3)
      expect(result[3], closeTo(3.0, 1e-9)); // avg(2,3,4)
      expect(result[4], closeTo(4.0, 1e-9)); // avg(3,4,5)
    });
  });

  group('ema', () {
    test('seeds with SMA then applies exponential smoothing', () {
      final result = ema([1, 2, 3, 4, 5], 3);
      expect(result[1], isNull);
      expect(result[2], closeTo(2.0, 1e-9)); // seed = avg(1,2,3)
      expect(result[3], closeTo(3.0, 1e-9)); // (4-2)*0.5+2
      expect(result[4], closeTo(4.0, 1e-9)); // (5-3)*0.5+3
    });
  });

  group('wma', () {
    test('weights most recent value most heavily', () {
      final result = wma([1, 2, 3], 3);
      // weights 1,2,3 over values 1,2,3 => (1*1+2*2+3*3)/6 = 14/6
      expect(result[2], closeTo(14 / 6, 1e-9));
    });
  });

  group('EmaIncremental', () {
    test('matches batch ema after seeding from the same history', () {
      final values = [1.0, 2, 3, 4, 5, 6, 7, 8];
      final batch = ema(values, 3);
      final inc = EmaIncremental(length: 3);
      inc.seedFromValues(values);
      expect(inc.value, closeTo(batch.last!, 1e-9));
    });
  });

  group('SmaIncremental', () {
    test('matches batch sma using a ring buffer', () {
      final inc = SmaIncremental(length: 3);
      for (final v in [1.0, 2, 3, 4, 5]) {
        inc.update(v);
      }
      expect(inc.value, closeTo(4.0, 1e-9)); // avg(3,4,5)
    });
  });
}
