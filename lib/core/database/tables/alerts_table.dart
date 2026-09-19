import 'package:drift/drift.dart';

@DataClassName('AlertRow')
class Alerts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text()();
  TextColumn get type => text()(); // PRICE, RSI, EMA_CROSS, MACD_CROSS, VOLUME_SPIKE,
                                    // BREAKOUT, SUPPORT_BREAK, RESISTANCE_BREAK, BOS,
                                    // CHOCH, FVG, SMC_SIGNAL, BUY_SIGNAL, SCORE_THRESHOLD
  TextColumn get conditionJson => text()(); // {"operator":"<","value":30} etc.
  TextColumn get timeframe => text().withDefault(const Constant('1h'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isRepeating => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastTriggeredAt => dateTime().nullable()();
}

@DataClassName('AlertHistoryRow')
class AlertHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get alertId => integer().references(Alerts, #id, onDelete: KeyAction.cascade)();
  TextColumn get symbol => text()();
  TextColumn get message => text()();
  RealColumn get priceAtTrigger => real()();
  DateTimeColumn get triggeredAt => dateTime().withDefault(currentDateAndTime)();
}
