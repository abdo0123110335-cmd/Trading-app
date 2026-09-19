import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_engine.dart';
import 'package:binance_spot_pro/services/indicator_engine/indicator_settings.dart';

List<Candle> _syntheticCandles(int n) {
  final start = DateTime.utc(2026, 1, 1);
  return List.generate(n, (i) {
    final close = 100 + i * 0.7 + (i % 4);
    return Candle(
      openTime: start.add(Duration(hours: i)),
      open: close - 0.5,
      high: close + 1,
      low: close - 1,
      close: close,
      volume: 1000 + (i % 10) * 50,
      closeTime: start.add(Duration(hours: i, minutes: 59)),
    );
  });
}

void main() {
  final candles = _syntheticCandles(120);

  test('RSI dispatch returns a value series bounded 0-100', () {
    final r = computeIndicator(
      IndicatorType.rsi,
      candles,
      IndicatorSettings.defaultsFor(IndicatorType.rsi),
    );
    final last = r.latest('value');
    expect(last, isNotNull);
    expect(last, inInclusiveRange(0, 100));
  });

  test('MACD dispatch returns macd/signal/histogram series', () {
    final r = computeIndicator(
      IndicatorType.macd,
      candles,
      IndicatorSettings.defaultsFor(IndicatorType.macd),
    );
    expect(r.latest('macd'), isNotNull);
    expect(r.latest('signal'), isNotNull);
    expect(r.latest('histogram'), isNotNull);
  });

  test('Bollinger Bands dispatch keeps upper >= middle >= lower', () {
    final r = computeIndicator(
      IndicatorType.bollingerBands,
      candles,
      IndicatorSettings.defaultsFor(IndicatorType.bollingerBands),
    );
    final u = r.latest('upper')!;
    final m = r.latest('middle')!;
    final l = r.latest('lower')!;
    expect(u, greaterThanOrEqualTo(m));
    expect(m, greaterThanOrEqualTo(l));
  });

  test('Parabolic SAR dispatch returns a trend flag of +1 or -1', () {
    final r = computeIndicator(
      IndicatorType.parabolicSar,
      candles,
      IndicatorSettings.defaultsFor(IndicatorType.parabolicSar),
    );
    final trend = r.latest('trend');
    expect(trend, anyOf(1.0, -1.0));
  });

  test('empty candle list returns an empty result without throwing', () {
    final r = computeIndicator(
      IndicatorType.ema,
      const [],
      IndicatorSettings.defaultsFor(IndicatorType.ema),
    );
    expect(r.series, isEmpty);
  });
}
