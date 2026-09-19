import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

List<Candle> _series({required int bars, required double Function(int i) priceAt}) {
  final base = DateTime.utc(2026, 1, 1);
  return List.generate(bars, (i) {
    final p = priceAt(i);
    return Candle(
      openTime: base.add(Duration(hours: i)),
      open: p - 0.2,
      high: p + 0.5,
      low: p - 0.5,
      close: p,
      volume: 1000,
      closeTime: base.add(Duration(hours: i, minutes: 59)),
    );
  });
}

void main() {
  group('generateSignal', () {
    test('never returns BUY when the score is below minBuyScore, even if RSI triggers', () {
      // Sharp dip → RSI oversold, but require an impossibly high min score.
      final candles = _series(
        bars: 80,
        priceAt: (i) => i < 70 ? 100 + i * 0.3 : 100 + 70 * 0.3 - (i - 69) * 2.0,
      );
      const config = StrategyConfig(strategyId: 1, name: 'test', minBuyScore: 999);
      final signal = generateSignal('BTCUSDT', '1h', candles, config);
      expect(signal.type, isNot(SignalType.buy));
    });

    test('BUY signals always include entry zone, invalidation and TP1/TP2', () {
      final candles = _series(
        bars: 80,
        priceAt: (i) => i < 70 ? 100 + i * 0.3 : 100 + 70 * 0.3 - (i - 69) * 2.0,
      );
      const config = StrategyConfig(strategyId: 1, name: 'test', minBuyScore: 1);
      final signal = generateSignal('BTCUSDT', '1h', candles, config);
      if (signal.type == SignalType.buy) {
        expect(signal.entryLow, isNotNull);
        expect(signal.entryHigh, isNotNull);
        expect(signal.invalidation, isNotNull);
        expect(signal.tp1, isNotNull);
        expect(signal.tp2, isNotNull);
        expect(signal.tp2!, greaterThan(signal.tp1!));
        expect(signal.invalidation!, lessThan(signal.price));
      }
    });

    test('a flat, uneventful series settles into HOLD', () {
      final candles = _series(bars: 80, priceAt: (i) => 100);
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final signal = generateSignal('BTCUSDT', '1h', candles, config);
      expect(signal.type, SignalType.hold);
    });

    test('never produces a signal type other than buy/hold/exit (no short)', () {
      final candles = _series(bars: 80, priceAt: (i) => 100 + i * 0.1);
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final signal = generateSignal('BTCUSDT', '1h', candles, config);
      expect(SignalType.values, contains(signal.type));
      expect(signal.type == SignalType.buy || signal.type == SignalType.hold || signal.type == SignalType.exit, isTrue);
    });
  });
}
