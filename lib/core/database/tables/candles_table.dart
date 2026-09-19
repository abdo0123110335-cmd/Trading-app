import 'package:drift/drift.dart';

/// Local OHLCV cache. Populated from REST klines on first load and kept
/// current from WebSocket kline events afterward, so charts/indicators/SMC
/// never need to re-fetch the full history from Binance on every screen
/// open.
@DataClassName('CandleRow')
class Candles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text()();
  TextColumn get timeframe => text()(); // 1m,3m,5m,15m,30m,1h,2h,4h,6h,12h,1D,1W,1M
  DateTimeColumn get openTime => dateTime()();
  RealColumn get open => real()();
  RealColumn get high => real()();
  RealColumn get low => real()();
  RealColumn get close => real()();
  RealColumn get volume => real()();
  DateTimeColumn get closeTime => dateTime()();
  BoolColumn get isClosed => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {symbol, timeframe, openTime},
  ];
}
