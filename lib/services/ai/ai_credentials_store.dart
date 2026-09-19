import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the user's AI provider configuration (base URL, model, API key)
/// using the same Android Keystore-backed secure storage as Binance
/// credentials — but in its own namespace, and deliberately never mixed
/// with [SecureCredentialsStore]. AI Analysis and Live Trading must stay
/// fully separate systems: the AI Analysis feature never has access to
/// place orders, and the trading engine never sends data to the AI
/// provider.
class AiCredentialsStore {
  AiCredentialsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyBaseUrl = 'ai_provider_base_url';
  static const _keyApiKey = 'ai_provider_api_key';
  static const _keyModel = 'ai_provider_model';

  Future<void> save({required String baseUrl, required String apiKey, required String model}) async {
    await _storage.write(key: _keyBaseUrl, value: baseUrl);
    await _storage.write(key: _keyApiKey, value: apiKey);
    await _storage.write(key: _keyModel, value: model);
  }

  Future<bool> hasConfig() async {
    final key = await _storage.read(key: _keyApiKey);
    final url = await _storage.read(key: _keyBaseUrl);
    return key != null && key.isNotEmpty && url != null && url.isNotEmpty;
  }

  Future<String?> readBaseUrl() => _storage.read(key: _keyBaseUrl);
  Future<String?> readModel() => _storage.read(key: _keyModel);
  Future<String?> readApiKeyForRequest() => _storage.read(key: _keyApiKey);

  Future<String?> readMaskedApiKey() async {
    final key = await _storage.read(key: _keyApiKey);
    if (key == null || key.length < 8) return null;
    return '${key.substring(0, 4)}${'•' * 8}${key.substring(key.length - 4)}';
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyBaseUrl);
    await _storage.delete(key: _keyApiKey);
    await _storage.delete(key: _keyModel);
  }
}
