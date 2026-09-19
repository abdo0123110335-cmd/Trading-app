import 'package:drift/drift.dart';

/// Generic key/value store for non-sensitive user preferences (theme,
/// language, currency, chart defaults, scanner interval, etc.).
///
/// This table MUST NEVER be used for API keys/secrets — those live only
/// in [SecureCredentialsStore] (Android Keystore-backed), never in SQLite.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get settingKey => text()();
  TextColumn get settingValue => text()();

  @override
  Set<Column> get primaryKey => {settingKey};
}
