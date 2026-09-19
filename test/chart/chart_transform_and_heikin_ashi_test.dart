import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/features/chart/models/chart_transform.dart';
import 'package:binance_spot_pro/services/indicator_engine/calculators/heikin_ashi.dart';

List<Candle> _candles(int n) {
  final start = DateTime.utc(2026, 1, 1);
  return List.generate(n, (i) {
    final close = 100.0 + i;
    return Candle(
      openTime: start.add(Duration(hours: i)),
      open: close - 1,
      high: close + 2,
      low: close - 2,
      close: close,
      volume: 100,
      closeTime: start.add(Duration(hours: i, minutes: 59)),
    );
  });
}

void main() {
  group('toHeikinAshi', () {
    test('HA close is the OHLC average of the source candle', () {
      final source = _candles(5);
      final ha = toHeikinAshi(source);
      for (var i = 0; i < source.length; i++) {
        final c = source[i];
        final expectedClose = (c.open + c.high + c.low + c.close) / 4;
        expect(ha[i].close, closeTo(expectedClose, 1e-9));
      }
    });

    test('HA open of bar N is the average of HA open/close of bar N-1', () {
      final source = _candles(6);
      final ha = toHeikinAshi(source);
      for (var i = 1; i < ha.length; i++) {
        expect(ha[i].open, closeTo((ha[i - 1].open + ha[i - 1].close) / 2, 1e-9));
      }
    });

    test('preserves candle count and chronological order', () {
      final source = _candles(10);
      final ha = toHeikinAshi(source);
      expect(ha.length, source.length);
      for (var i = 0; i < ha.length; i++) {
        expect(ha[i].openTime, source[i].openTime);
      }
    });
  });

  group('ChartTransform', () {
    test('xForIndex and indexForX are inverse operations', () {
      final t = ChartTransform(
        candles: _candles(50),
        firstVisibleIndex: 10,
        visibleCount: 30,
        width: 300,
        priceAreaHeight: 400,
      );
      const testIndex = 25.0;
      final x = t.xForIndex(testIndex);
      final roundTrip = t.indexForX(x);
      expect(roundTrip, closeTo(testIndex, 1e-9));
    });

    test('yForPrice and priceForY are inverse operations', () {
      final t = ChartTransform(
        candles: _candles(50),
        firstVisibleIndex: 0,
        visibleCount: 50,
        width: 300,
        priceAreaHeight: 400,
        manualPriceMin: 90,
        manualPriceMax: 160,
      );
      const testPrice = 123.0;
      final y = t.yForPrice(testPrice);
      final roundTrip = t.priceForY(y);
      expect(roundTrip, closeTo(testPrice, 1e-9));
    });

    test('higher price maps to a smaller y (top of the price area)', () {
      final t = ChartTransform(
        candles: _candles(50),
        firstVisibleIndex: 0,
        visibleCount: 50,
        width: 300,
        priceAreaHeight: 400,
        manualPriceMin: 0,
        manualPriceMax: 100,
      );
      expect(t.yForPrice(90), lessThan(t.yForPrice(10)));
    });
  });
}
