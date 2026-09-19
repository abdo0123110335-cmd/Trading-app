import 'dart:async';

import 'package:binance_spot_pro/core/api/binance_rest_client.dart';
import 'package:binance_spot_pro/core/utils/result.dart';
import 'package:binance_spot_pro/core/utils/safe_logger.dart';
import 'package:binance_spot_pro/core/websocket/binance_websocket_manager.dart';
import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/data/repositories/candle_repository.dart';
import 'package:binance_spot_pro/services/market_data/memory_cache.dart';

/// The single source of truth for market data used by every feature
/// (Home, Markets, Chart, Screener, Signals, Alerts). Implements the
/// architecture from the spec:
///
/// `Binance → Market Data Manager → Memory Cache → Local Database →
/// Indicators → Strategies → Signals → Alerts → UI`
///
/// Screens never call [BinanceRestClient] or [BinanceWebSocketManager]
/// directly for candle data — they ask this manager, which:
///   1. Serves instantly from [MarketDataMemoryCache] if warm.
///   2. Otherwise loads from [CandleRepository] (SQLite) for an instant
///      "last known" render while it fetches fresh REST history.
///   3. Subscribes the shared WebSocket to the symbol/timeframe kline
///      stream and keeps the cache (and DB) current tick-by-tick.
class MarketDataManager {
  MarketDataManager({
    required BinanceRestClient restClient,
    required BinanceWebSocketManager wsManager,
    required CandleRepository candleRepository,
    MarketDataMemoryCache? cache,
  }) : _rest = restClient,
       _ws = wsManager,
       _candleRepo = candleRepository,
       _cache = cache ?? MarketDataMemoryCache();

  final BinanceRestClient _rest;
  final BinanceWebSocketManager _ws;
  final CandleRepository _candleRepo;
  final MarketDataMemoryCache _cache;

  final Map<String, StreamController<List<Candle>>> _candleControllers = {};
  final Map<String, int> _subscriberCounts = {};
  StreamSubscription<dynamic>? _wsSub;

  void _ensureWsListener() {
    _wsSub ??= _ws.messages.listen(_onWsMessage);
  }

  void _onWsMessage(dynamic message) {
    if (message is! Map<String, dynamic>) return;
    final data = message['data'] as Map<String, dynamic>?;
    if (data == null) return;
    if (data['e'] != 'kline') return;

    final symbol = data['s'] as String?;
    final k = data['k'] as Map<String, dynamic>?;
    if (symbol == null || k == null) return;
    final interval = k['i'] as String?;
    if (interval == null) return;

    final candle = Candle.fromWsKline(k);
    _cache.applyLiveCandle(symbol, interval, candle);

    if (candle.isClosed) {
      // Persist closed candles only — never write an in-progress candle
      // as final history.
      unawaited(_candleRepo.upsertCandles(symbol, interval, [candle]));
    }

    final key = MarketDataMemoryCache.candleKey(symbol, interval);
    _candleControllers[key]?.add(_cache.getCandles(symbol, interval));
  }

  /// Returns a live-updating stream of the candle series for
  /// symbol+timeframe. First emission is instant (DB cache if any),
  /// followed by a fresh REST history load, followed by live WS ticks.
  /// Multiple widgets can subscribe to the same symbol/timeframe without
  /// triggering duplicate REST calls or WS subscriptions — reference
  /// counted via [dispose].
  Stream<List<Candle>> watchCandles(
    String symbol,
    String timeframe, {
    int historyLimit = 500,
  }) {
    final key = MarketDataMemoryCache.candleKey(symbol, timeframe);
    final controller = _candleControllers.putIfAbsent(
      key,
      () => StreamController<List<Candle>>.broadcast(
        onCancel: () => _onUnsubscribe(symbol, timeframe),
      ),
    );
    _subscriberCounts[key] = (_subscriberCounts[key] ?? 0) + 1;

    if (_subscriberCounts[key] == 1) {
      _startWatching(symbol, timeframe, historyLimit, controller);
    } else {
      // Already warm — emit the current cache state immediately for the
      // new subscriber.
      final cached = _cache.getCandles(symbol, timeframe);
      if (cached.isNotEmpty) {
        scheduleMicrotask(() => controller.add(cached));
      }
    }

    return controller.stream;
  }

  Future<void> _startWatching(
    String symbol,
    String timeframe,
    int historyLimit,
    StreamController<List<Candle>> controller,
  ) async {
    _ensureWsListener();

    // 1. Instant paint from local DB, if we have any history already.
    final dbCandles = await _candleRepo.getCandles(symbol, timeframe, limit: historyLimit);
    if (dbCandles.isNotEmpty) {
      _cache.putCandles(symbol, timeframe, dbCandles);
      controller.add(dbCandles);
    }

    // 2. Fresh REST history — authoritative, replaces the DB-only view.
    final result = await _rest.getKlines(
      symbol: symbol,
      interval: timeframe,
      limit: historyLimit,
    );
    result.when(
      ok: (raw) {
        final candles = raw
            .whereType<List<dynamic>>()
            .map(Candle.fromRestArray)
            .toList();
        _cache.putCandles(symbol, timeframe, candles);
        controller.add(candles);
        unawaited(_candleRepo.upsertCandles(symbol, timeframe, candles));
      },
      err: (e) {
        SafeLogger.w('REST kline history failed for $symbol/$timeframe: ${e.userMessage}');
        // Keep whatever we already emitted from the DB — offline-friendly.
      },
    );

    // 3. Live ticks from here on.
    final streamName = '${symbol.toLowerCase()}@kline_$timeframe';
    await _ws.subscribe([streamName]);
    await _ws.connect();
  }

  void _onUnsubscribe(String symbol, String timeframe) {
    final key = MarketDataMemoryCache.candleKey(symbol, timeframe);
    final remaining = (_subscriberCounts[key] ?? 1) - 1;
    if (remaining <= 0) {
      _subscriberCounts.remove(key);
      _candleControllers.remove(key);
      final streamName = '${symbol.toLowerCase()}@kline_$timeframe';
      unawaited(_ws.unsubscribe([streamName]));
    } else {
      _subscriberCounts[key] = remaining;
    }
  }

  /// One-shot fetch (no live subscription) — used by the Screener/Scanner
  /// which needs a snapshot across many symbols rather than a live feed
  /// for each one.
  Future<Result<List<Candle>>> fetchCandlesSnapshot(
    String symbol,
    String timeframe, {
    int limit = 200,
  }) async {
    final cached = _cache.getCandles(symbol, timeframe);
    if (cached.length >= limit) {
      return Result.ok(cached.sublist(cached.length - limit));
    }
    final result = await _rest.getKlines(symbol: symbol, interval: timeframe, limit: limit);
    return result.when(
      ok: (raw) {
        final candles = raw.whereType<List<dynamic>>().map(Candle.fromRestArray).toList();
        _cache.putCandles(symbol, timeframe, candles);
        unawaited(_candleRepo.upsertCandles(symbol, timeframe, candles));
        return Result.ok(candles);
      },
      err: (e) => Result.err(e),
    );
  }

  MarketDataMemoryCache get cache => _cache;

  void dispose() {
    _wsSub?.cancel();
    for (final c in _candleControllers.values) {
      c.close();
    }
    _candleControllers.clear();
    _subscriberCounts.clear();
  }
}
