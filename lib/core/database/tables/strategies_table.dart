import 'package:drift/drift.dart';

@DataClassName('StrategyRow')
class Strategies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get baseType => text().withDefault(const Constant('RSI_EMA'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Key/value settings for a strategy: RSI length/oversold/overbought,
/// which optional filters (EMA/Volume/MACD/Trend/Support/SMC) are ON/OFF,
/// score weights, and minimum BUY score. Stored as flexible key/value
/// rows rather than fixed columns so new filters can be added later
/// without a schema migration for every field.
@DataClassName('StrategySettingRow')
class StrategySettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get strategyId => integer().references(Strategies, #id, onDelete: KeyAction.cascade)();
  TextColumn get settingKey => text()(); // e.g. "rsi_length", "filter_ema_enabled", "min_buy_score"
  TextColumn get settingValue => text()(); // stored as string, parsed by type at read time

  @override
  List<Set<Column>> get uniqueKeys => [
    {strategyId, settingKey},
  ];
}
