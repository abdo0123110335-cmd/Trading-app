import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';
import 'package:binance_spot_pro/data/models/candle.dart';

/// Persists OHLCV history to SQLite (via Drift) so the app has real data
/// to show immediately on next launch / when offline, instead of an empty
/// chart while waiting on a fresh REST call.
class CandleRepository {
  CandleRepository(this._db);
  final AppDatabase _db;

  Future<void> upsertCandles(
    String symbol,
    String timeframe,
    List<Candle> candles,
  ) async {
    if (candles.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.candles,
        candles.map(
          (c) => CandlesCompanion.insert(
            symbol: symbol.toUpperCase(),
            timeframe: timeframe,
            openTime: c.openTime,
            open: c.open,
            high: c.high,
            low: c.low,
            close: c.close,
            volume: c.volume,
            closeTime: c.closeTime,
            isClosed: Value(c.isClosed),
          ),
        ),
      );
    });
  }

  Future<List<Candle>> getCandles(
    String symbol,
    String timeframe, {
    int limit = 500,
  }) async {
    final query = _db.select(_db.candles)
      ..where((t) => t.symbol.equals(symbol.toUpperCase()) & t.timeframe.equals(timeframe))
      ..orderBy([(t) => OrderingTerm(expression: t.openTime, mode: OrderingMode.desc)])
      ..limit(limit);
    final rows = await query.get();
    return rows.reversed
        .map(
          (r) => Candle(
            openTime: r.openTime,
            open: r.open,
            high: r.high,
            low: r.low,
            close: r.close,
            volume: r.volume,
            closeTime: r.closeTime,
            isClosed: r.isClosed,
          ),
        )
        .toList();
  }

  /// Deletes candle history older than [before] for storage housekeeping
  /// (used by Settings > Data Management > Clear Cache).
  Future<void> deleteOlderThan(DateTime before) async {
    await (_db.delete(_db.candles)..where((t) => t.openTime.isSmallerThanValue(before))).go();
  }

  Future<void> deleteAll() async {
    await _db.delete(_db.candles).go();
  }
}
