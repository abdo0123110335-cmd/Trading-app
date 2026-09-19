import 'package:dio/dio.dart';

import 'package:binance_spot_pro/core/api/api_exceptions.dart';
import 'package:binance_spot_pro/core/utils/result.dart';
import 'package:binance_spot_pro/core/utils/safe_logger.dart';
import 'package:binance_spot_pro/services/ai/ai_context_builder.dart';
import 'package:binance_spot_pro/services/ai/ai_credentials_store.dart';

/// Sends the already-built [AiAnalysisContext] to the user's configured
/// AI provider and returns its text analysis.
///
/// Deliberately targets the OpenAI-compatible `/chat/completions` shape,
/// since that's the common denominator across most hosted and
/// self-hosted providers — the user supplies base URL, API key and
/// model, and any provider that speaks this format works without app
/// changes.
///
/// This class has zero access to the Trading Engine or order placement —
/// AI Analysis is read-only and advisory. It never executes trades.
class AiAnalysisService {
  AiAnalysisService({required AiCredentialsStore credentialsStore, Dio? dio})
    : _credentials = credentialsStore,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );

  final AiCredentialsStore _credentials;
  final Dio _dio;

  static const _systemPrompt =
      'You are a market analysis assistant for a Binance Spot trading app. '
      'You are given real, already-computed market data for one symbol — '
      'price, indicators, SMC structure, and a strategy score. Analyze only '
      'the data provided. Do not invent prices, indicator values, or events '
      'that are not in the data. Do not give financial advice framed as a '
      'certainty; describe what the data shows and the balance of bullish vs '
      'bearish signals. Keep the analysis concise (under 200 words).';

  Future<Result<String>> analyze(AiAnalysisContext context) async {
    final hasConfig = await _credentials.hasConfig();
    if (!hasConfig) {
      return Result.err(UnknownApiException(debugInfo: 'AI provider not configured'));
    }

    final baseUrl = await _credentials.readBaseUrl();
    final apiKey = await _credentials.readApiKeyForRequest();
    final model = await _credentials.readModel();

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${baseUrl!.replaceAll(RegExp(r'/$'), '')}/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
        data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': context.toPromptText()},
          ],
          'temperature': 0.3,
        },
      );

      final choices = response.data?['choices'] as List<dynamic>?;
      final content = choices?.isNotEmpty == true
          ? (choices!.first as Map<String, dynamic>)['message']?['content'] as String?
          : null;

      if (content == null || content.isEmpty) {
        return Result.err(UnknownApiException(debugInfo: 'Empty AI response'));
      }
      return Result.ok(content);
    } on DioException catch (e) {
      SafeLogger.w('AI Analysis request failed: ${e.message}');
      return Result.err(NetworkException(debugInfo: e.message));
    } catch (e) {
      SafeLogger.e('Unexpected AI Analysis error', error: e);
      return Result.err(UnknownApiException(debugInfo: e.toString()));
    }
  }
}
