/// Centralized Binance Spot endpoint constants.
///
/// Only SPOT endpoints are defined here on purpose — this app never talks to
/// Futures, Margin or Options hosts. Keeping every URL in one place makes it
/// trivial to audit exactly which Binance surfaces this app can reach.
class BinanceEndpoints {
  BinanceEndpoints._();

  /// Public + signed REST base for Binance Spot.
  static const String restBase = 'https://api.binance.com';

  /// Public market-data WebSocket base (no auth required, no API key ever
  /// sent over this connection).
  static const String wsBase = 'wss://stream.binance.com:9443';

  /// Combined-stream endpoint, lets one socket carry many subscriptions
  /// instead of opening one connection per symbol/stream.
  static const String wsCombinedStreamPath = '/stream';

  // ---- Public market data (no signature required) ----
  static const String ping = '/api/v3/ping';
  static const String serverTime = '/api/v3/time';
  static const String exchangeInfo = '/api/v3/exchangeInfo';
  static const String ticker24hr = '/api/v3/ticker/24hr';
  static const String tickerPrice = '/api/v3/ticker/price';
  static const String klines = '/api/v3/klines';
  static const String depth = '/api/v3/depth';
  static const String trades = '/api/v3/trades';
  static const String avgPrice = '/api/v3/avgPrice';

  // ---- Signed / account endpoints (require API key + secret signature) ----
  static const String account = '/api/v3/account';
  static const String order = '/api/v3/order';
  static const String orderTest = '/api/v3/order/test';
  static const String openOrders = '/api/v3/openOrders';
  static const String allOrders = '/api/v3/allOrders';
  static const String myTrades = '/api/v3/myTrades';
  static const String apiKeyPermission = '/sapi/v1/account/apiRestrictions';
}
