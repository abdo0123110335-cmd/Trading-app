import 'package:drift/drift.dart';

/// One row per Binance Spot trading pair (from exchangeInfo), refreshed
/// periodically. Non-SPOT / non-TRADING pairs are filtered out before
/// insert so the rest of the app never has to think about Futures/Margin.
@DataClassName('SymbolRow')
class Symbols extends Table {
  TextColumn get symbol => text()(); // e.g. BTCUSDT
  TextColumn get baseAsset => text()();
  TextColumn get quoteAsset => text()();
  TextColumn get status => text()(); // TRADING, BREAK, etc.
  IntColumn get baseAssetPrecision => integer().withDefault(const Constant(8))();
  IntColumn get quoteAssetPrecision => integer().withDefault(const Constant(8))();
  RealColumn get minQty => real().withDefault(const Constant(0))();
  RealColumn get maxQty => real().withDefault(const Constant(0))();
  RealColumn get stepSize => real().withDefault(const Constant(0))();
  RealColumn get minNotional => real().withDefault(const Constant(0))();
  RealColumn get tickSize => real().withDefault(const Constant(0))();
  BoolColumn get isSpotTradingAllowed => boolean().withDefault(const Constant(true))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol};
}
