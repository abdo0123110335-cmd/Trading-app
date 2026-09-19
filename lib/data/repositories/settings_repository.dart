import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';

/// Generic key/value preferences backed by the `settings` table.
///
/// This is strictly for non-sensitive preferences — API keys/secrets
/// never pass through here, per the project's security rules (they live
/// only in [SecureCredentialsStore]/Android Keystore).
class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<String?> getString(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.settingKey.equals(key))).getSingleOrNull();
    return row?.settingValue;
  }

  Future<void> setString(String key, String value) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(SettingsCompanion.insert(settingKey: key, settingValue: value));
  }

  Future<bool> getBool(String key, {bool fallback = false}) async {
    final raw = await getString(key);
    if (raw == null) return fallback;
    return raw == 'true';
  }

  Future<void> setBool(String key, bool value) => setString(key, value.toString());

  Future<int> getInt(String key, {required int fallback}) async {
    final raw = await getString(key);
    return int.tryParse(raw ?? '') ?? fallback;
  }

  Future<void> setInt(String key, int value) => setString(key, '$value');
}

/// Setting keys used across the app, centralized so nothing typos a key
/// string in one screen and silently reads a different one elsewhere.
class SettingsKeys {
  SettingsKeys._();
  static const backgroundMonitoringEnabled = 'background_monitoring_enabled';
  static const monitoringIntervalMinutes = 'monitoring_interval_minutes';
  static const scannerOnMonitoringEnabled = 'scanner_on_monitoring_enabled';
}
