import 'package:binance_spot_pro/core/api/binance_rest_client.dart';
import 'package:binance_spot_pro/core/utils/result.dart';
import 'package:binance_spot_pro/data/models/ticker_24hr.dart';

/// Phase 1 slice of the market data repository: raw ticker + symbol list
/// straight from Binance REST. Phase 2 adds the Memory Cache + SQLite
/// layer and indicator pipeline described in the architecture diagram
/// (Binance → Market Data Manager → Memory Cache → Local DB → Indicators…).
class MarketRepository {
  MarketRepository(this._client);

  final BinanceRestClient _client;

  Future<Result<List<Ticker24hr>>> getTickers24hr({String? symbol}) async {
    final result = await _client.getTicker24hr(symbol: symbol);
    return result.when(
      ok: (list) => Result.ok(
        list
            .whereType<Map<String, dynamic>>()
            .map(Ticker24hr.fromJson)
            .toList(),
      ),
      err: (e) => Result.err(e),
    );
  }

  /// Returns only Spot pairs that are actively trading and quoted in
  /// USDT — the default, most useful slice for Markets/Screener browsing.
  /// (Full multi-quote support arrives with the Markets screen filters in
  /// a later phase.)
  Future<Result<List<Map<String, dynamic>>>> getTradableUsdtSymbols() async {
    final result = await _client.getExchangeInfo();
    return result.when(
      ok: (symbols) => Result.ok(
        symbols
            .whereType<Map<String, dynamic>>()
            .where(
              (s) =>
                  s['status'] == 'TRADING' &&
                  s['quoteAsset'] == 'USDT' &&
                  s['isSpotTradingAllowed'] == true,
            )
            .toList(),
      ),
      err: (e) => Result.err(e),
    );
  }
}
