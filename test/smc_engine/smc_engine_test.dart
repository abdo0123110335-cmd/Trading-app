import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/smc_engine/fair_value_gaps.dart';
import 'package:binance_spot_pro/services/smc_engine/market_structure.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_engine.dart';
import 'package:binance_spot_pro/services/smc_engine/smc_models.dart';
import 'package:binance_spot_pro/services/smc_engine/swing_points.dart';

Candle _c({required double open, required double high, required double low, required double close, int minute = 0}) {
  final base = DateTime.utc(2026, 1, 1);
  return Candle(
    openTime: base.add(Duration(minutes: minute)),
    open: open,
    high: high,
    low: low,
    close: close,
    volume: 1000,
    closeTime: base.add(Duration(minutes: minute + 1)),
  );
}

void main() {
  group('detectSwingPoints', () {
    test('finds an obvious swing high at the peak of a V-shaped series', () {
      // Prices rise then fall: index 4 is the clear peak.
      final highs = [10.0, 12, 14, 16, 20, 16, 14, 12, 10];
      final candles = List.generate(
        highs.length,
        (i) => _c(open: highs[i] - 1, high: highs[i], low: highs[i] - 2, close: highs[i] - 0.5, minute: i),
      );
      final swings = detectSwingPoints(candles, strength: 2);
      final swingHighIndices = swings.where((s) => s.type == SwingType.high).map((s) => s.index);
      expect(swingHighIndices, contains(4));
    });

    test('finds an obvious swing low at the bottom of an inverted-V series', () {
      final lows = [20.0, 16, 12, 8, 4, 8, 12, 16, 20];
      final candles = List.generate(
        lows.length,
        (i) => _c(open: lows[i] + 1, high: lows[i] + 2, low: lows[i], close: lows[i] + 0.5, minute: i),
      );
      final swings = detectSwingPoints(candles, strength: 2);
      final swingLowIndices = swings.where((s) => s.type == SwingType.low).map((s) => s.index);
      expect(swingLowIndices, contains(4));
    });
  });

  group('classifyStructure', () {
    test('labels a rising sequence of swing highs as higher highs', () {
      final swings = [
        const SwingPoint(index: 0, price: 100, type: SwingType.high),
        const SwingPoint(index: 5, price: 110, type: SwingType.high),
        const SwingPoint(index: 10, price: 120, type: SwingType.high),
      ];
      final structure = classifyStructure(swings);
      expect(structure.every((s) => s.label == StructureLabel.higherHigh), isTrue);
    });
  });

  group('detectFairValueGaps', () {
    test('detects a bullish FVG when candle[i-1].high < candle[i+1].low', () {
      final candles = [
        _c(open: 100, high: 101, low: 99, close: 100, minute: 0),
        _c(open: 101, high: 110, low: 101, close: 109, minute: 1), // impulse up
        _c(open: 109, high: 112, low: 105, close: 111, minute: 2), // low(105) > high(101) of bar 0
      ];
      final gaps = detectFairValueGaps(candles);
      expect(gaps, isNotEmpty);
      expect(gaps.first.type, FvgType.bullish);
      expect(gaps.first.bottom, 101); // candle[0].high
      expect(gaps.first.top, 105); // candle[2].low
    });

    test('detects a bearish FVG when candle[i-1].low > candle[i+1].high', () {
      final candles = [
        _c(open: 100, high: 101, low: 99, close: 100, minute: 0),
        _c(open: 99, high: 99, low: 90, close: 91, minute: 1), // impulse down
        _c(open: 91, high: 95, low: 88, close: 90, minute: 2), // high(95) < low(99) of bar 0
      ];
      final gaps = detectFairValueGaps(candles);
      expect(gaps, isNotEmpty);
      expect(gaps.first.type, FvgType.bearish);
    });

    test('marks a gap as filled once price trades back through it', () {
      final candles = [
        _c(open: 100, high: 101, low: 99, close: 100, minute: 0),
        _c(open: 101, high: 110, low: 101, close: 109, minute: 1),
        _c(open: 109, high: 112, low: 105, close: 111, minute: 2),
        _c(open: 111, high: 111, low: 100, close: 102, minute: 3), // trades back through the gap
      ];
      final gaps = detectFairValueGaps(candles);
      expect(gaps.first.filled, isTrue);
    });
  });

  group('analyzeSmc', () {
    test('returns an empty, non-throwing analysis for a too-short series', () {
      final candles = [_c(open: 1, high: 2, low: 0, close: 1)];
      final result = analyzeSmc(candles);
      expect(result.swingPoints, isEmpty);
      expect(result.currentTrend, isNull);
    });

    test('runs end-to-end without throwing on a longer synthetic series', () {
      final candles = List.generate(150, (i) {
        final base = 100 + (i % 20) * 1.5 - (i % 7);
        return _c(open: base, high: base + 3, low: base - 3, close: base + 1, minute: i);
      });
      expect(() => analyzeSmc(candles), returnsNormally);
    });
  });
}
