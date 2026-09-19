import 'package:drift/drift.dart';

/// Closed/settled trade history — either synced from Binance `myTrades`
/// (when the user's API key is connected) or entered manually for a
/// paper/manual-tracked position.
@DataClassName('TradeRow')
class Trades extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text()();
  TextColumn get side => text()(); // BUY, SELL (Spot only — no SHORT)
  RealColumn get entryPrice => real()();
  RealColumn get exitPrice => real().nullable()();
  RealColumn get quantity => real()();
  RealColumn get fee => real().withDefault(const Constant(0))();
  TextColumn get feeAsset => text().withDefault(const Constant('USDT'))();
  RealColumn get pnl => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('OPEN'))(); // OPEN, CLOSED
  BoolColumn get isFromBinance => boolean().withDefault(const Constant(false))();
  IntColumn get binanceOrderId => integer().nullable()();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
}

/// Local record of orders placed through the app's Live Spot Trading
/// feature (mirrors Binance order lifecycle: NEW, FILLED, CANCELED, etc.).
@DataClassName('OrderRow')
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get binanceOrderId => integer().nullable()();
  TextColumn get symbol => text()();
  TextColumn get side => text()(); // BUY, SELL
  TextColumn get type => text()(); // MARKET, LIMIT
  RealColumn get quantity => real()();
  RealColumn get price => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('NEW'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Manual portfolio holdings, used when the user has NOT connected a
/// Binance API key (or wants to track coins outside their Binance
/// account). When an API key IS connected, live balances come straight
/// from Binance and are not duplicated into this table.
@DataClassName('PortfolioRow')
class Portfolio extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get asset => text()();
  RealColumn get quantity => real()();
  RealColumn get avgBuyPrice => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {asset},
  ];
}
