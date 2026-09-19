import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/atr.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/bollinger_bands.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/macd.dart';

void main() {
  group('macd', () {
    test('histogram equals macd minus signal wherever both are non-null', () {
      final prices = List<double>.generate(60, (i) => 100 + i * 0.5 + (i % 5));
      final result = macd(prices, fastLength: 6, slowLength: 13, signalLength: 4);
      for (var i = 0; i < prices.length; i++) {
        final m = result.macd[i];
        final s = result.signal[i];
        final h = result.histogram[i];
        if (m != null && s != null) {
          expect(h, isNotNull);
          expect(h!, closeTo(m - s, 1e-9));
        }
      }
    });
  });

  group('bollingerBands', () {
    test('upper band is always >= middle >= lower band', () {
      final prices = [10.0, 12, 9, 15, 11, 13, 8, 16, 10, 14, 12, 11, 13, 15, 9, 10, 11, 12, 13, 14];
      final result = bollingerBands(prices, length: 5, stdDevMultiplier: 2);
      for (var i = 0; i < prices.length; i++) {
        final u = result.upper[i];
        final m = result.middle[i];
        final l = result.lower[i];
        if (u != null && m != null && l != null) {
          expect(u, greaterThanOrEqualTo(m));
          expect(m, greaterThanOrEqualTo(l));
        }
      }
    });

    test('bands collapse to the price when volatility is zero', () {
      final flat = List<double>.filled(10, 100.0);
      final result = bollingerBands(flat, length: 5, stdDevMultiplier: 2);
      expect(result.upper[9], closeTo(100, 1e-9));
      expect(result.lower[9], closeTo(100, 1e-9));
    });
  });

  group('atrFromOhlc', () {
    test('is zero for a perfectly flat, no-range series', () {
      final flat = List<double>.filled(20, 50.0);
      final result = atrFromOhlc(flat, flat, flat, length: 14);
      expect(result[13], closeTo(0, 1e-9));
    });

    test('increases when true range widens', () {
      final highs = List<double>.generate(20, (i) => 50 + i * 2.0);
      final lows = List<double>.generate(20, (i) => 48 - i * 0.5);
      final closes = List<double>.generate(20, (i) => 49 + i);
      final result = atrFromOhlc(highs, lows, closes, length: 14);
      expect(result[19], greaterThan(result[13]!));
    });
  });
}
