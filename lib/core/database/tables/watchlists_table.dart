import 'package:drift/drift.dart';

@DataClassName('WatchlistRow')
class Watchlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('WatchlistSymbolRow')
class WatchlistSymbols extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get watchlistId => integer().references(Watchlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get symbol => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {watchlistId, symbol},
  ];
}
