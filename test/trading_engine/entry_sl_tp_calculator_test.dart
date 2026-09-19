import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/services/trading_engine/entry_sl_tp_calculator.dart';

void main() {
  group('calculateEntrySlTp', () {
    test('computes risk % and position size correctly for a long setup', () {
      final result = calculateEntrySlTp(
        const EntrySlTpInput(
          entry: 100000,
          stopLoss: 98000,
          accountRiskUsdt: 50,
          tp1Multiplier: 1.5,
          tp2Multiplier: 3.0,
        ),
      );
      expect(result.riskPercent, closeTo(2.0, 1e-9));
      expect(result.positionSize, closeTo(0.025, 1e-9));
      expect(result.isLong, isTrue);
    });

    test('TP1/TP2 are above entry for a long setup, scaled by the multipliers', () {
      final result = calculateEntrySlTp(
        const EntrySlTpInput(
          entry: 100000,
          stopLoss: 98000,
          accountRiskUsdt: 50,
          tp1Multiplier: 1.5,
          tp2Multiplier: 3.0,
        ),
      );
      expect(result.tp1, closeTo(103000, 1e-6));
      expect(result.tp2, closeTo(106000, 1e-6));
      expect(result.tp2, greaterThan(result.tp1));
    });

    test('riskAmount always echoes the input account risk', () {
      final result = calculateEntrySlTp(
        const EntrySlTpInput(entry: 50, stopLoss: 45, accountRiskUsdt: 20),
      );
      expect(result.riskAmount, 20);
    });

    test('handles a zero-risk (entry == stopLoss) input without throwing or dividing by zero', () {
      final result = calculateEntrySlTp(
        const EntrySlTpInput(entry: 100, stopLoss: 100, accountRiskUsdt: 10),
      );
      expect(result.positionSize, 0);
      expect(result.riskPercent, 0);
    });
  });
}
