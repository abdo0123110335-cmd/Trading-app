import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/services/ai/ai_context_builder.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

List<Candle> _series(int n) {
  final base = DateTime.utc(2026, 1, 1);
  return List.generate(n, (i) {
    final close = 100 + i * 0.5 + (i % 5);
    return Candle(
      openTime: base.add(Duration(hours: i)),
      open: close - 0.3,
      high: close + 1,
      low: close - 1,
      close: close,
      volume: 1000 + (i % 10) * 20,
      closeTime: base.add(Duration(hours: i, minutes: 59)),
    );
  });
}

void main() {
  group('buildAiContext', () {
    test('reports insufficient data instead of fabricating indicators for a short series', () {
      final context = buildAiContext(
        symbol: 'BTCUSDT',
        candles: _series(10),
        config: const StrategyConfig(strategyId: 1, name: 'test'),
      );
      expect(context.sections.any((s) => s.contains('insufficient')), isTrue);
      expect(context.sections.any((s) => s.startsWith('RSI')), isFalse);
    });

    test('includes real RSI/EMA/Score values for a long-enough series', () {
      final context = buildAiContext(
        symbol: 'ETHUSDT',
        candles: _series(120),
        config: const StrategyConfig(strategyId: 1, name: 'test'),
      );
      expect(context.sections.any((s) => s.startsWith('Price:')), isTrue);
      expect(context.sections.any((s) => s.startsWith('RSI(')), isTrue);
      expect(context.sections.any((s) => s.startsWith('Strategy Score')), isTrue);
      expect(context.sections.any((s) => s.startsWith('SMC current trend')), isTrue);
    });

    test('toPromptText includes the symbol and every section line', () {
      final context = buildAiContext(
        symbol: 'SOLUSDT',
        candles: _series(120),
        config: const StrategyConfig(strategyId: 1, name: 'test'),
      );
      final text = context.toPromptText();
      expect(text, contains('SOLUSDT'));
      for (final section in context.sections) {
        expect(text, contains(section));
      }
    });
  });
}
