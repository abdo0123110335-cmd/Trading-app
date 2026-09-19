import 'package:drift/drift.dart';

/// Stores the user's saved indicator instances per chart (which indicators
/// are on a symbol+timeframe chart, and their settings as JSON — e.g. RSI
/// length/source/overbought/oversold). The indicator math itself lives in
/// the indicator_engine service, not in the database layer.
@DataClassName('IndicatorRow')
class Indicators extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text()();
  TextColumn get timeframe => text()();
  TextColumn get type => text()(); // RSI, EMA, MACD, ...
  TextColumn get settingsJson => text()(); // {"length":14,"source":"close",...}
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
