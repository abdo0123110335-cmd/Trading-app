import 'package:binance_spot_pro/data/models/candle.dart';
import 'package:binance_spot_pro/data/models/ticker_24hr.dart';

/// Fast, process-local cache sitting between the database and every
/// screen/service that needs market data "right now" — the
/// `Memory Cache` box in the architecture diagram:
///
/// `Binance → Market Data Manager → Memory Cache → Local Database →
/// Indicators → Strategies → Signals → Alerts → UI`
///
/// Reads never touch Binance or SQLite when the data is already warm
/// here; only [MarketDataManager] writes to it, after a REST fetch or a
/// WebSocket tick.
class MarketDataMemoryCache {
  final Map<String, Ticker24hr> _tickers = {};
  final Map<String, List<Candle>> _candles = {}; // key: "SYMBOL:TIMEFRAME"

  static String candleKey(String symbol, String timeframe) =>
      '${symbol.toUpperCase()}:$timeframe';

  // ---- Tickers ----
  Ticker24hr? getTicker(String symbol) => _tickers[symbol.toUpperCase()];

  void putTicker(Ticker24hr ticker) {
    _tickers[ticker.symbol.toUpperCase()] = ticker;
  }

  List<Ticker24hr> get allTickers => List.unmodifiable(_tickers.values);

  // ---- Candles ----
  List<Candle> getCandles(String symbol, String timeframe) {
    return List.unmodifiable(_candles[candleKey(symbol, timeframe)] ?? const []);
  }

  /// Replaces the whole cached series (used after a fresh REST history
  /// load).
  void putCandles(String symbol, String timeframe, List<Candle> candles) {
    _candles[candleKey(symbol, timeframe)] = List.of(candles);
  }

  /// Applies a single live update from the WebSocket kline stream:
  /// replaces the in-progress last candle, or appends a new one once the
  /// previous candle closes. O(1) — never re-fetches or re-sorts the
  /// whole series.
  void applyLiveCandle(String symbol, String timeframe, Candle incoming) {
    final key = candleKey(symbol, timeframe);
    final series = _candles.putIfAbsent(key, () => []);
    if (series.isNotEmpty && series.last.openTime == incoming.openTime) {
      series[series.length - 1] = incoming;
    } else if (series.isEmpty || incoming.openTime.isAfter(series.last.openTime)) {
      series.add(incoming);
      // Cap in-memory history so a long-running background session
      // doesn't grow unbounded for symbols under active monitoring.
      const maxCandlesPerSeries = 1500;
      if (series.length > maxCandlesPerSeries) {
        series.removeRange(0, series.length - maxCandlesPerSeries);
      }
    }
  }

  void clear() {
    _tickers.clear();
    _candles.clear();
  }
}
