import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/scanner/scan_models.dart';
import 'package:binance_spot_pro/services/scanner/setup_detector.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';
import 'package:binance_spot_pro/services/strategy_engine/rsi_ema_strategy.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

Candle _bar(double close, {double? volume, int minute = 0}) {
  final base = DateTime.utc(2026, 1, 1);
  return Candle(
    openTime: base.add(Duration(hours: minute)),
    open: close - 0.5,
    high: close + 1,
    low: close - 1,
    close: close,
    volume: volume ?? 1000,
    closeTime: base.add(Duration(hours: minute, minutes: 59)),
  );
}

void main() {
  group('detectSetupTags', () {
    test('flags a breakout when the close clears the prior 20-bar high', () {
      final candles = <Candle>[
        for (var i = 0; i < 79; i++) _bar(100 + (i % 5), minute: i), // choppy, capped ~104
        _bar(120, minute: 79), // clean breakout above the recent range
      ];
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      final signal = generateSignal('BTCUSDT', '1h', candles, config);
      final tags = detectSetupTags(candles, evaluation, signal);
      expect(tags.contains(ScanSetupTag.breakout), isTrue);
    });

    test('flags a volume spike when volume is well above its 20-bar average', () {
      final candles = <Candle>[
        for (var i = 0; i < 79; i++) _bar(100, volume: 1000, minute: i),
        _bar(100, volume: 5000, minute: 79), // 5x average
      ];
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      final signal = generateSignal('BTCUSDT', '1h', candles, config);
      final tags = detectSetupTags(candles, evaluation, signal);
      expect(tags.contains(ScanSetupTag.volumeSpike), isTrue);
    });

    test('does not flag a volume spike on uniform volume', () {
      final candles = <Candle>[for (var i = 0; i < 80; i++) _bar(100, volume: 1000, minute: i)];
      const config = StrategyConfig(strategyId: 1, name: 'test');
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      final signal = generateSignal('BTCUSDT', '1h', candles, config);
      final tags = detectSetupTags(candles, evaluation, signal);
      expect(tags.contains(ScanSetupTag.volumeSpike), isFalse);
    });

    test('oversold tag matches the strategy evaluation RSI trigger', () {
      final candles = <Candle>[
        for (var i = 0; i < 70; i++) _bar(100 + i * 0.3, minute: i),
        for (var i = 70; i < 80; i++) _bar(100 + 70 * 0.3 - (i - 69) * 2.0, minute: i),
      ];
      const config = StrategyConfig(strategyId: 1, name: 'test', rsiLength: 6, rsiOversold: 30);
      final evaluation = evaluateRsiEmaStrategy(candles, config);
      final signal = generateSignal('BTCUSDT', '1h', candles, config);
      final tags = detectSetupTags(candles, evaluation, signal);
      expect(tags.contains(ScanSetupTag.oversold), evaluation.rsiTriggered);
    });
  });
}
