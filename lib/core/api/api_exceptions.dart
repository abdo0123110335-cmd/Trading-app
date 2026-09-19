/// Base type for every error this app can raise while talking to Binance.
///
/// UI code should only ever show [userMessage] to a normal user — never the
/// raw exception, never a stack trace. Developers can still read [debugInfo]
/// in logs (which is guaranteed not to contain API secrets — see
/// core/utils/safe_logger.dart).
sealed class AppException implements Exception {
  const AppException(this.userMessage, {this.debugInfo});

  final String userMessage;
  final String? debugInfo;

  @override
  String toString() => 'AppException: $userMessage';
}

class NetworkException extends AppException {
  const NetworkException({String? debugInfo})
    : super('Network error. Check your internet connection.', debugInfo: debugInfo);
}

class TimeoutExceptionApp extends AppException {
  const TimeoutExceptionApp({String? debugInfo})
    : super('The request took too long. Please try again.', debugInfo: debugInfo);
}

class RateLimitException extends AppException {
  const RateLimitException({this.retryAfterSeconds, String? debugInfo})
    : super(
        'Binance rate limit reached. Slowing down automatically.',
        debugInfo: debugInfo,
      );

  final int? retryAfterSeconds;
}

class InvalidSymbolException extends AppException {
  const InvalidSymbolException(String symbol)
    : super('Symbol "$symbol" is not a valid Binance Spot pair.');
}

class InvalidApiKeyException extends AppException {
  const InvalidApiKeyException({String? debugInfo})
    : super(
        'Invalid API key or signature. Check your Binance API credentials.',
        debugInfo: debugInfo,
      );
}

class InsufficientBalanceException extends AppException {
  const InsufficientBalanceException()
    : super('Insufficient balance to place this order.');
}

class InvalidQuantityException extends AppException {
  const InvalidQuantityException([String? detail])
    : super(detail ?? 'Invalid order quantity for this symbol.');
}

class InvalidPriceException extends AppException {
  const InvalidPriceException([String? detail])
    : super(detail ?? 'Invalid order price for this symbol.');
}

class WebSocketDisconnectedException extends AppException {
  const WebSocketDisconnectedException()
    : super('Live market connection dropped. Reconnecting…');
}

class TradingDisabledException extends AppException {
  const TradingDisabledException()
    : super('Live trading is disabled. Enable it in Settings to place real orders.');
}

class UnknownApiException extends AppException {
  const UnknownApiException({String? debugInfo})
    : super('Something went wrong talking to Binance.', debugInfo: debugInfo);
}

/// Maps a raw Binance error payload (`{"code": -1121, "msg": "..."}`) to a
/// typed [AppException]. Binance error codes reference:
/// https://developers.binance.com/docs/binance-spot-api-docs/errors
AppException mapBinanceErrorCode(int? code, String? msg, {String? debugInfo}) {
  switch (code) {
    case -1003:
      return RateLimitException(debugInfo: debugInfo);
    case -1121:
      return const InvalidSymbolException('(unknown)');
    case -1022:
    case -2014:
    case -2015:
      return InvalidApiKeyException(debugInfo: debugInfo);
    case -2010:
      return const InsufficientBalanceException();
    case -1013:
    case -1111:
      return InvalidQuantityException(msg);
    default:
      return UnknownApiException(debugInfo: debugInfo ?? msg);
  }
}
