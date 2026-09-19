import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:binance_spot_pro/core/api/api_exceptions.dart';
import 'package:binance_spot_pro/core/api/binance_endpoints.dart';
import 'package:binance_spot_pro/core/security/binance_request_signer.dart';
import 'package:binance_spot_pro/core/security/secure_credentials_store.dart';
import 'package:binance_spot_pro/core/utils/result.dart';
import 'package:binance_spot_pro/core/utils/safe_logger.dart';

/// Single, shared REST client for all Binance Spot HTTP calls.
///
/// Every screen/repository goes through this class rather than creating its
/// own Dio instance — that keeps timeout/retry/rate-limit/error handling
/// consistent and auditable in one place, and is the only class (besides
/// [BinanceRequestSigner]) that ever reads the API secret.
class BinanceRestClient {
  BinanceRestClient({Dio? dio, SecureCredentialsStore? credentialsStore})
    : _dio = dio ?? _buildDio(),
      _credentialsStore = credentialsStore ?? SecureCredentialsStore();

  final Dio _dio;
  final SecureCredentialsStore _credentialsStore;

  /// Tracks Binance's used-weight header so we can back off proactively
  /// instead of just reacting to 429/418 responses.
  int _lastUsedWeight = 0;
  DateTime? _bannedUntil;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: BinanceEndpoints.restBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    return dio;
  }

  // ---------------------------------------------------------------------
  // Public market data (no API key required)
  // ---------------------------------------------------------------------

  Future<Result<List<dynamic>>> getExchangeInfo() {
    return _getList(BinanceEndpoints.exchangeInfo, resultKey: 'symbols');
  }

  Future<Result<List<dynamic>>> getTicker24hr({String? symbol}) {
    return _getList(
      BinanceEndpoints.ticker24hr,
      query: symbol == null ? null : {'symbol': symbol},
      wrapSingleAsList: true,
    );
  }

  Future<Result<List<dynamic>>> getKlines({
    required String symbol,
    required String interval,
    int limit = 500,
    int? startTime,
    int? endTime,
  }) {
    return _getList(
      BinanceEndpoints.klines,
      query: {
        'symbol': symbol,
        'interval': interval,
        'limit': limit,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
    );
  }

  Future<Result<Map<String, dynamic>>> getOrderBook({
    required String symbol,
    int limit = 100,
  }) {
    return _getMap(
      BinanceEndpoints.depth,
      query: {'symbol': symbol, 'limit': limit},
    );
  }

  // ---------------------------------------------------------------------
  // Signed account/order endpoints (require stored API key + secret)
  // ---------------------------------------------------------------------

  Future<Result<Map<String, dynamic>>> getAccount() {
    return _getMap(BinanceEndpoints.account, signed: true);
  }

  Future<Result<List<dynamic>>> getOpenOrders({String? symbol}) {
    return _getList(
      BinanceEndpoints.openOrders,
      query: symbol == null ? null : {'symbol': symbol},
      signed: true,
    );
  }

  Future<Result<List<dynamic>>> getMyTrades({
    required String symbol,
    int limit = 500,
  }) {
    return _getList(
      BinanceEndpoints.myTrades,
      query: {'symbol': symbol, 'limit': limit},
      signed: true,
    );
  }

  /// Checks whether the connected API key has trading permission enabled.
  /// Used by Settings > Binance Connection to show "Trading Disabled" vs a
  /// clear warning when trading IS enabled on the key.
  Future<Result<Map<String, dynamic>>> getApiKeyPermissions() {
    return _getMap(BinanceEndpoints.apiKeyPermission, signed: true);
  }

  /// Places a real Spot order. Callers MUST have already gated this behind
  /// the Live Trading toggle and a user confirmation dialog — this client
  /// does not itself decide whether trading is allowed; that policy lives
  /// in the trading_engine service so it can be unit tested in isolation.
  Future<Result<Map<String, dynamic>>> placeOrder({
    required String symbol,
    required String side, // BUY | SELL
    required String type, // MARKET | LIMIT
    required String quantity,
    String? price,
    String? timeInForce,
    bool test = false,
  }) {
    final query = <String, dynamic>{
      'symbol': symbol,
      'side': side,
      'type': type,
      'quantity': quantity,
      if (price != null) 'price': price,
      if (timeInForce != null) 'timeInForce': timeInForce,
    };
    final path = test ? BinanceEndpoints.orderTest : BinanceEndpoints.order;
    return _post(path, query: query, signed: true);
  }

  Future<Result<Map<String, dynamic>>> cancelOrder({
    required String symbol,
    required int orderId,
  }) {
    return _delete(
      BinanceEndpoints.order,
      query: {'symbol': symbol, 'orderId': orderId},
      signed: true,
    );
  }

  // ---------------------------------------------------------------------
  // Internal request plumbing
  // ---------------------------------------------------------------------

  Future<Result<List<dynamic>>> _getList(
    String path, {
    Map<String, dynamic>? query,
    bool signed = false,
    String? resultKey,
    bool wrapSingleAsList = false,
  }) async {
    final result = await _request('GET', path, query: query, signed: signed);
    return result.when(
      ok: (data) {
        if (resultKey != null && data is Map<String, dynamic>) {
          return Result.ok((data[resultKey] as List<dynamic>?) ?? const []);
        }
        if (data is List) return Result.ok(data);
        if (wrapSingleAsList && data is Map<String, dynamic>) {
          return Result.ok([data]);
        }
        return const Result.ok([]);
      },
      err: (e) => Result.err(e),
    );
  }

  Future<Result<Map<String, dynamic>>> _getMap(
    String path, {
    Map<String, dynamic>? query,
    bool signed = false,
  }) async {
    final result = await _request('GET', path, query: query, signed: signed);
    return result.when(
      ok: (data) => Result.ok(data as Map<String, dynamic>? ?? {}),
      err: (e) => Result.err(e),
    );
  }

  Future<Result<Map<String, dynamic>>> _post(
    String path, {
    Map<String, dynamic>? query,
    bool signed = false,
  }) async {
    final result = await _request('POST', path, query: query, signed: signed);
    return result.when(
      ok: (data) => Result.ok(data as Map<String, dynamic>? ?? {}),
      err: (e) => Result.err(e),
    );
  }

  Future<Result<Map<String, dynamic>>> _delete(
    String path, {
    Map<String, dynamic>? query,
    bool signed = false,
  }) async {
    final result = await _request(
      'DELETE',
      path,
      query: query,
      signed: signed,
    );
    return result.when(
      ok: (data) => Result.ok(data as Map<String, dynamic>? ?? {}),
      err: (e) => Result.err(e),
    );
  }

  Future<Result<dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    bool signed = false,
    int attempt = 0,
  }) async {
    if (_bannedUntil != null && DateTime.now().isBefore(_bannedUntil!)) {
      final secs = _bannedUntil!.difference(DateTime.now()).inSeconds;
      return Result.err(RateLimitException(retryAfterSeconds: secs));
    }

    try {
      final options = Options(method: method, headers: <String, dynamic>{});
      final params = Map<String, dynamic>.from(query ?? {});

      if (signed) {
        final apiKey = await _credentialsStore.readApiKey();
        final apiSecret = await _credentialsStore.readApiSecretForSigning();
        if (apiKey == null || apiSecret == null) {
          return const Result.err(InvalidApiKeyException());
        }
        params['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        params['recvWindow'] = 5000;
        final queryString = Uri(
          queryParameters: params.map((k, v) => MapEntry(k, '$v')),
        ).query;
        final signature = BinanceRequestSigner.sign(
          queryString: queryString,
          apiSecret: apiSecret,
        );
        params['signature'] = signature;
        (options.headers as Map<String, dynamic>)['X-MBX-APIKEY'] = apiKey;
      }

      final response = await _dio.request<dynamic>(
        path,
        queryParameters: params,
        options: options,
      );

      final weightHeader = response.headers.value('x-mbx-used-weight-1m');
      if (weightHeader != null) {
        _lastUsedWeight = int.tryParse(weightHeader) ?? _lastUsedWeight;
      }

      return Result.ok(response.data);
    } on DioException catch (e) {
      return _handleDioError(e, method, path, query, signed, attempt);
    } catch (e) {
      SafeLogger.e('Unexpected REST error on $path', error: e);
      return Result.err(UnknownApiException(debugInfo: e.toString()));
    }
  }

  Future<Result<dynamic>> _handleDioError(
    DioException e,
    String method,
    String path,
    Map<String, dynamic>? query,
    bool signed,
    int attempt,
  ) async {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    int? code;
    String? msg;
    if (body is Map<String, dynamic>) {
      code = body['code'] as int?;
      msg = body['msg'] as String?;
    }

    if (status == 429 || status == 418) {
      final retryAfter = e.response?.headers.value('retry-after');
      final seconds = int.tryParse(retryAfter ?? '') ?? 5;
      _bannedUntil = DateTime.now().add(Duration(seconds: seconds));
      SafeLogger.w('Binance rate limit on $path, backing off ${seconds}s');
      return Result.err(RateLimitException(retryAfterSeconds: seconds));
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        return _request(
          method,
          path,
          query: query,
          signed: signed,
          attempt: attempt + 1,
        );
      }
      return Result.err(TimeoutExceptionApp(debugInfo: e.message));
    }

    if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        return _request(
          method,
          path,
          query: query,
          signed: signed,
          attempt: attempt + 1,
        );
      }
      return Result.err(NetworkException(debugInfo: e.message));
    }

    if (status == 400 || status == 401 || status == 403) {
      SafeLogger.w('Binance API error $status on $path: code=$code');
      return Result.err(
        mapBinanceErrorCode(code, msg, debugInfo: 'HTTP $status on $path'),
      );
    }

    SafeLogger.e('Unhandled Dio error on $path', error: e);
    return Result.err(UnknownApiException(debugInfo: e.message));
  }

  int get lastUsedWeight => _lastUsedWeight;
}
