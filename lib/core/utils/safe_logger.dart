import 'package:logger/logger.dart';

/// A logging facade that every part of the app MUST use instead of `print`
/// or a raw `Logger` instance.
///
/// It guarantees that anything matching an API-key / secret / signature
/// shape is redacted before it ever reaches the console or a log file.
/// This is a hard security requirement of the project: API keys and
/// secrets must never appear in logs.
class SafeLogger {
  SafeLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 3,
      colors: false,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  // Binance HMAC-SHA256 signatures are 64 hex chars. API keys are typically
  // 64 alphanumeric chars. We redact both liberally — false positives just
  // mean we redact something harmless, which is the safe direction to err.
  static final RegExp _signatureLike = RegExp(r'\b[0-9a-fA-F]{40,}\b');
  static final RegExp _apiKeyLike = RegExp(r'\b[A-Za-z0-9]{48,}\b');
  static final RegExp _queryParamSecret = RegExp(
    r'(signature|X-MBX-APIKEY|apiKey|secret)=[^&\s"]+',
    caseSensitive: false,
  );

  static String redact(String input) {
    var out = input;
    out = out.replaceAll(_queryParamSecret, r'$1=[REDACTED]');
    out = out.replaceAll(_signatureLike, '[REDACTED]');
    out = out.replaceAll(_apiKeyLike, '[REDACTED]');
    return out;
  }

  static void d(String message) => _logger.d(redact(message));
  static void i(String message) => _logger.i(redact(message));
  static void w(String message) => _logger.w(redact(message));

  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(
      redact(message),
      error: error == null ? null : redact(error.toString()),
      stackTrace: stackTrace,
    );
  }
}
