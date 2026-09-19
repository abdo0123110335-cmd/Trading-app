import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';

class WatchlistRepository {
  WatchlistRepository(this._db);
  final AppDatabase _db;

  Future<List<WatchlistRow>> getWatchlists() {
    return (_db.select(
      _db.watchlists,
    )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();
  }

  Future<int> createWatchlist(String name) {
    return _db.into(_db.watchlists).insert(WatchlistsCompanion.insert(name: name));
  }

  Future<void> renameWatchlist(int id, String name) async {
    await (_db.update(
      _db.watchlists,
    )..where((t) => t.id.equals(id))).write(WatchlistsCompanion(name: Value(name)));
  }

  Future<void> deleteWatchlist(int id) async {
    await (_db.delete(_db.watchlists)..where((t) => t.id.equals(id))).go();
  }

  Future<List<String>> getSymbols(int watchlistId) async {
    final rows = await (_db.select(_db.watchlistSymbols)
          ..where((t) => t.watchlistId.equals(watchlistId))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    return rows.map((r) => r.symbol).toList();
  }

  Future<bool> containsSymbol(int watchlistId, String symbol) async {
    final row = await (_db.select(_db.watchlistSymbols)..where(
          (t) => t.watchlistId.equals(watchlistId) & t.symbol.equals(symbol.toUpperCase()),
        ))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> addSymbol(int watchlistId, String symbol) async {
    await _db
        .into(_db.watchlistSymbols)
        .insertOnConflictUpdate(
          WatchlistSymbolsCompanion.insert(
            watchlistId: watchlistId,
            symbol: symbol.toUpperCase(),
          ),
        );
  }

  Future<void> removeSymbol(int watchlistId, String symbol) async {
    await (_db.delete(_db.watchlistSymbols)..where(
          (t) => t.watchlistId.equals(watchlistId) & t.symbol.equals(symbol.toUpperCase()),
        ))
        .go();
  }

  /// Finds (or creates) the built-in "Favorites" watchlist seeded on first
  /// launch — used by the Markets screen's star toggle.
  Future<int> getOrCreateFavoritesId() async {
    final existing = await (_db.select(
      _db.watchlists,
    )..where((t) => t.name.equals('Favorites'))).getSingleOrNull();
    if (existing != null) return existing.id;
    return createWatchlist('Favorites');
  }
}
