import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/core/database/app_database.dart';
import 'package:binance_spot_pro/data/repositories/settings_repository.dart';
import 'package:binance_spot_pro/services/trading_engine/risk_manager.dart';

void main() {
  late AppDatabase db;
  late RiskManager riskManager;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    riskManager = RiskManager(SettingsRepository(db));
  });

  tearDown(() => db.close());

  group('RiskManager', () {
    test('getConfig returns sensible defaults when nothing has been saved', () async {
      final config = await riskManager.getConfig();
      expect(config.maxTradeAmountUsdt, 100);
      expect(config.emergencyStopActive, isFalse);
    });

    test('saveConfig persists values that getConfig then returns', () async {
      const config = RiskConfig(
        maxTradeAmountUsdt: 250,
        maxPositionSizeUsdt: 1000,
        maxOpenOrders: 3,
        maxDailyRiskUsdt: 75,
      );
      await riskManager.saveConfig(config);
      final loaded = await riskManager.getConfig();
      expect(loaded.maxTradeAmountUsdt, 250);
      expect(loaded.maxOpenOrders, 3);
    });

    test('checkOrder blocks when Emergency Stop is active', () async {
      await riskManager.setEmergencyStop(true);
      final failure = await riskManager.checkOrder(
        orderNotionalUsdt: 10,
        currentPositionNotionalUsdt: 0,
        currentOpenOrders: 0,
      );
      expect(failure, isNotNull);
      expect(failure!.reason, contains('Emergency Stop'));
    });

    test('checkOrder blocks an order above maxTradeAmountUsdt', () async {
      await riskManager.saveConfig(const RiskConfig(maxTradeAmountUsdt: 50));
      final failure = await riskManager.checkOrder(
        orderNotionalUsdt: 100,
        currentPositionNotionalUsdt: 0,
        currentOpenOrders: 0,
      );
      expect(failure, isNotNull);
    });

    test('checkOrder allows a well-within-limits order', () async {
      await riskManager.saveConfig(
        const RiskConfig(
          maxTradeAmountUsdt: 500,
          maxPositionSizeUsdt: 1000,
          maxOpenOrders: 5,
          maxDailyRiskUsdt: 500,
        ),
      );
      final failure = await riskManager.checkOrder(
        orderNotionalUsdt: 20,
        currentPositionNotionalUsdt: 0,
        currentOpenOrders: 1,
      );
      expect(failure, isNull);
    });

    test('checkOrder blocks when currentOpenOrders is already at the max', () async {
      await riskManager.saveConfig(const RiskConfig(maxOpenOrders: 2));
      final failure = await riskManager.checkOrder(
        orderNotionalUsdt: 10,
        currentPositionNotionalUsdt: 0,
        currentOpenOrders: 2,
      );
      expect(failure, isNotNull);
    });
  });
}
