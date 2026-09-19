import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the user's Binance API key/secret using Android Keystore-backed
/// encryption (via `flutter_secure_storage`, `EncryptedSharedPreferences` on
/// Android). Nothing here ever writes credentials to SQLite, plain
/// SharedPreferences, files, or logs.
///
/// Design rules enforced by this class:
///   * The API secret is NEVER returned to any widget for display — only
///     used internally to sign requests.
///   * The API key may be partially shown (masked) for the user to confirm
///     which account is connected, never the full value in a fresh session
///     after save.
///   * Deleting credentials requires an explicit call — never implicit.
class SecureCredentialsStore {
  SecureCredentialsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage();

  static FlutterSecureStorage _defaultStorage() {
    return const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        keyCipherAlgorithm:
            KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
    );
  }

  final FlutterSecureStorage _storage;

  static const _keyApiKey = 'binance_api_key';
  static const _keyApiSecret = 'binance_api_secret';
  static const _keyTradingEnabled = 'live_trading_enabled';
  static const _keyConnectedAt = 'binance_connected_at';

  Future<void> saveCredentials({
    required String apiKey,
    required String apiSecret,
  }) async {
    await _storage.write(key: _keyApiKey, value: apiKey);
    await _storage.write(key: _keyApiSecret, value: apiSecret);
    await _storage.write(
      key: _keyConnectedAt,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<String?> readApiKey() => _storage.read(key: _keyApiKey);

  /// Internal use only (request signing). Do not surface this to any
  /// widget, provider state that gets logged, or crash-reporting payload.
  Future<String?> readApiSecretForSigning() =>
      _storage.read(key: _keyApiSecret);

  Future<bool> hasCredentials() async {
    final key = await _storage.read(key: _keyApiKey);
    final secret = await _storage.read(key: _keyApiSecret);
    return key != null && key.isNotEmpty && secret != null && secret.isNotEmpty;
  }

  /// Returns a display-safe masked form, e.g. `AbCd••••••••wXyz`.
  Future<String?> readMaskedApiKey() async {
    final key = await _storage.read(key: _keyApiKey);
    if (key == null || key.length < 8) return null;
    return '${key.substring(0, 4)}${'•' * 8}${key.substring(key.length - 4)}';
  }

  Future<DateTime?> readConnectedAt() async {
    final raw = await _storage.read(key: _keyConnectedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLiveTradingEnabled(bool enabled) async {
    await _storage.write(key: _keyTradingEnabled, value: enabled.toString());
  }

  Future<bool> isLiveTradingEnabled() async {
    final raw = await _storage.read(key: _keyTradingEnabled);
    return raw == 'true';
  }

  /// Explicit, irreversible removal of all Binance credentials. Callers
  /// (Settings > Binance API > Disconnect) must confirm with the user
  /// before invoking this.
  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyApiKey);
    await _storage.delete(key: _keyApiSecret);
    await _storage.delete(key: _keyConnectedAt);
    await _storage.write(key: _keyTradingEnabled, value: 'false');
  }
}
