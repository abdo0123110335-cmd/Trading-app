import 'package:drift/drift.dart';

/// A single signal produced by the on-device Signal Engine. Spot-only, so
/// `signalType` is restricted at the service layer to BUY / HOLD / EXIT —
/// there is deliberately no SHORT/SELL-to-open concept anywhere in this
/// table.
@DataClassName('SignalRow')
class Signals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text()();
  TextColumn get timeframe => text()();
  TextColumn get signalType => text()(); // BUY, HOLD, EXIT
  RealColumn get price => real()();
  IntColumn get score => integer()(); // 0-100
  TextColumn get reasonsJson => text()(); // ["RSI oversold","EMA bullish cross",...]
  RealColumn get entryZoneLow => real().nullable()();
  RealColumn get entryZoneHigh => real().nullable()();
  RealColumn get invalidation => real().nullable()();
  RealColumn get tp1 => real().nullable()();
  RealColumn get tp2 => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
