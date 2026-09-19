import 'package:drift/drift.dart';

/// Persists chart drawing objects (trend lines, Fibonacci, rectangles,
/// channels, S/R lines, etc.) per symbol + timeframe so they reappear when
/// the user reopens that chart.
@DataClassName('DrawingRow')
class Drawings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text()();
  TextColumn get timeframe => text()();
  TextColumn get toolType => text()(); // TREND_LINE, HORIZONTAL_LINE, FIB_RETRACEMENT, ...
  TextColumn get pointsJson => text()(); // [{"time":..., "price":...}, ...]
  TextColumn get styleJson => text().withDefault(const Constant('{}'))(); // color, width, etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
