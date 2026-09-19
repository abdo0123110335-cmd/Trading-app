import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

class StrategyRepository {
  StrategyRepository(this._db);
  final AppDatabase _db;

  Future<StrategyConfig> getDefaultStrategy() async {
    final row = await (_db.select(
      _db.strategies,
    )..where((t) => t.isDefault.equals(true))).getSingleOrNull();

    if (row == null) {
      // Should never happen (seeded on first launch), but fail safe with
      // in-memory defaults rather than crashing the Strategies screen.
      return const StrategyConfig(strategyId: -1, name: 'Default RSI + EMA');
    }

    final settingsRows = await (_db.select(
      _db.strategySettings,
    )..where((t) => t.strategyId.equals(row.id))).get();

    final map = {for (final s in settingsRows) s.settingKey: s.settingValue};
    return StrategyConfig.fromSettingsMap(row.id, row.name, map);
  }

  Future<List<StrategyRow>> getAllStrategies() {
    return _db.select(_db.strategies).get();
  }

  Future<void> saveStrategy(StrategyConfig config) async {
    for (final entry in config.toSettingsMap().entries) {
      await _db
          .into(_db.strategySettings)
          .insertOnConflictUpdate(
            StrategySettingsCompanion.insert(
              strategyId: config.strategyId,
              settingKey: entry.key,
              settingValue: entry.value,
            ),
          );
    }
  }
}
