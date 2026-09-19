import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';

class PortfolioRepository {
  PortfolioRepository(this._db);
  final AppDatabase _db;

  Future<List<PortfolioRow>> getHoldings() {
    return _db.select(_db.portfolio).get();
  }

  Future<void> upsertHolding({
    required String asset,
    required double quantity,
    double avgBuyPrice = 0,
  }) async {
    await _db.into(_db.portfolio).insertOnConflictUpdate(
      PortfolioCompanion.insert(
        asset: asset.toUpperCase(),
        quantity: quantity,
        avgBuyPrice: Value(avgBuyPrice),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteHolding(String asset) async {
    await (_db.delete(_db.portfolio)..where((t) => t.asset.equals(asset.toUpperCase()))).go();
  }
}
