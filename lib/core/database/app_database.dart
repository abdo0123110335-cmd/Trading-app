import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:binance_spot_pro/core/database/tables/alerts_table.dart';
import 'package:binance_spot_pro/core/database/tables/candles_table.dart';
import 'package:binance_spot_pro/core/database/tables/drawings_table.dart';
import 'package:binance_spot_pro/core/database/tables/indicators_table.dart';
import 'package:binance_spot_pro/core/database/tables/settings_table.dart';
import 'package:binance_spot_pro/core/database/tables/signals_table.dart';
import 'package:binance_spot_pro/core/database/tables/strategies_table.dart';
import 'package:binance_spot_pro/core/database/tables/symbols_table.dart';
import 'package:binance_spot_pro/core/database/tables/trading_tables.dart';
import 'package:binance_spot_pro/core/database/tables/watchlists_table.dart';

part 'app_database.g.dart';

/// The single local SQLite database for the entire app (via Drift).
///
/// Everything the spec calls for lives here: symbols, candles,
/// watchlists(+symbols), indicators, signals, alerts(+history), drawings,
/// strategies(+settings), trades, orders, portfolio, settings.
///
/// No table in this database ever stores a Binance API secret — see
/// core/security/secure_credentials_store.dart for that.
@DriftDatabase(
  tables: [
    Symbols,
    Candles,
    Watchlists,
    WatchlistSymbols,
    Indicators,
    Signals,
    Alerts,
    AlertHistory,
    Drawings,
    Strategies,
    StrategySettings,
    Trades,
    Orders,
    Portfolio,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Exposed for tests that want an in-memory database instead of a file
  /// on disk.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedDefaultWatchlistAndStrategy(this);
    },
  );
}

Future<void> _seedDefaultWatchlistAndStrategy(AppDatabase db) async {
  // Default "Favorites" watchlist so Home/Markets have somewhere to star
  // coins into immediately.
  await db
      .into(db.watchlists)
      .insert(WatchlistsCompanion.insert(name: 'Favorites', sortOrder: const Value(0)));

  // Default RSI+EMA strategy per spec: RSI length 6, oversold 30,
  // overbought 70, minimum BUY score 75, all optional filters OFF until
  // the user turns them on.
  final strategyId = await db
      .into(db.strategies)
      .insert(
        StrategiesCompanion.insert(
          name: 'Default RSI + EMA',
          baseType: const Value('RSI_EMA'),
          isDefault: const Value(true),
        ),
      );

  final defaults = <String, String>{
    'rsi_length': '6',
    'rsi_oversold': '30',
    'rsi_overbought': '70',
    'filter_ema_enabled': 'false',
    'filter_volume_enabled': 'false',
    'filter_macd_enabled': 'false',
    'filter_trend_enabled': 'false',
    'filter_support_enabled': 'false',
    'filter_smc_enabled': 'false',
    'min_buy_score': '75',
    'weight_rsi': '20',
    'weight_ema': '15',
    'weight_macd': '15',
    'weight_volume': '15',
    'weight_trend': '10',
    'weight_smc': '15',
    'weight_support': '10',
  };

  for (final entry in defaults.entries) {
    await db
        .into(db.strategySettings)
        .insert(
          StrategySettingsCompanion.insert(
            strategyId: strategyId,
            settingKey: entry.key,
            settingValue: entry.value,
          ),
        );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'binance_spot_pro.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
