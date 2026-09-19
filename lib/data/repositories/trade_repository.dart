import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';

class TradeRepository {
  TradeRepository(this._db);
  final AppDatabase _db;

  Future<List<TradeRow>> getTrades({int limit = 200}) {
    final query = _db.select(_db.trades)
      ..orderBy([(t) => OrderingTerm(expression: t.openedAt, mode: OrderingMode.desc)])
      ..limit(limit);
    return query.get();
  }

  Future<void> upsertFromBinanceTrade(Map<String, dynamic> raw, String symbol) async {
    final orderId = raw['orderId'] as int?;
    final existing = orderId == null
        ? null
        : await (_db.select(
            _db.trades,
          )..where((t) => t.binanceOrderId.equals(orderId))).getSingleOrNull();

    final price = double.tryParse('${raw['price']}') ?? 0;
    final qty = double.tryParse('${raw['qty']}') ?? 0;
    final commission = double.tryParse('${raw['commission']}') ?? 0;
    final isBuyer = raw['isBuyer'] as bool? ?? true;
    final time = raw['time'] as int?;

    final companion = TradesCompanion.insert(
      symbol: symbol,
      side: isBuyer ? 'BUY' : 'SELL',
      entryPrice: price,
      quantity: qty,
      fee: Value(commission),
      feeAsset: Value(raw['commissionAsset'] as String? ?? 'USDT'),
      status: const Value('CLOSED'),
      isFromBinance: const Value(true),
      binanceOrderId: Value(orderId),
      openedAt: Value(time == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(time)),
      closedAt: Value(time == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(time)),
    );

    if (existing == null) {
      await _db.into(_db.trades).insert(companion);
    } else {
      await (_db.update(_db.trades)..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  Future<double> totalPnl() async {
    final trades = await getTrades();
    var total = 0.0;
    for (final t in trades) {
      if (t.pnl != null) total += t.pnl!;
    }
    return total;
  }
}
