import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/api/binance_rest_client.dart';
import 'package:binance_spot_pro/core/connectivity/connectivity_service.dart';
import 'package:binance_spot_pro/core/database/app_database.dart';
import 'package:binance_spot_pro/core/security/secure_credentials_store.dart';
import 'package:binance_spot_pro/core/websocket/binance_websocket_manager.dart';
import 'package:binance_spot_pro/data/repositories/candle_repository.dart';
import 'package:binance_spot_pro/data/repositories/market_repository.dart';
import 'package:binance_spot_pro/data/repositories/alert_repository.dart';
import 'package:binance_spot_pro/data/repositories/signal_repository.dart';
import 'package:binance_spot_pro/data/repositories/settings_repository.dart';
import 'package:binance_spot_pro/data/repositories/strategy_repository.dart';
import 'package:binance_spot_pro/data/repositories/symbol_repository.dart';
import 'package:binance_spot_pro/data/repositories/portfolio_repository.dart';
import 'package:binance_spot_pro/data/repositories/trade_repository.dart';
import 'package:binance_spot_pro/data/repositories/watchlist_repository.dart';
import 'package:binance_spot_pro/services/ai/ai_analysis_service.dart';
import 'package:binance_spot_pro/services/ai/ai_credentials_store.dart';
import 'package:binance_spot_pro/services/alert_engine/alert_engine.dart';
import 'package:binance_spot_pro/services/market_data/market_data_manager.dart';
import 'package:binance_spot_pro/services/scanner/scanner_service.dart';
import 'package:binance_spot_pro/services/trading_engine/risk_manager.dart';
import 'package:binance_spot_pro/services/trading_engine/trading_engine.dart';

/// Single app-wide [AppDatabase] instance. Every repository/DAO reads
/// through this provider instead of constructing its own database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Tracks device connectivity for the Offline Mode banner and to gate
/// Live Trading. See [ConnectivityService] for exactly what "online"
/// means here.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onlineStream;
});

/// Single app-wide secure storage for Binance credentials.
final secureCredentialsStoreProvider = Provider<SecureCredentialsStore>((ref) {
  return SecureCredentialsStore();
});

/// Single app-wide REST client for all Binance Spot HTTP calls.
final binanceRestClientProvider = Provider<BinanceRestClient>((ref) {
  return BinanceRestClient(credentialsStore: ref.watch(secureCredentialsStoreProvider));
});

/// Single app-wide WebSocket connection manager. All live-data consumers
/// (Home ticker strip, Markets list, Chart, Screener, Alerts engine) share
/// this one socket via subscribe()/unsubscribe() rather than opening their
/// own connections.
final binanceWebSocketManagerProvider = Provider<BinanceWebSocketManager>((ref) {
  final manager = BinanceWebSocketManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepository(ref.watch(binanceRestClientProvider));
});

final candleRepositoryProvider = Provider<CandleRepository>((ref) {
  return CandleRepository(ref.watch(appDatabaseProvider));
});

/// Single app-wide Market Data Manager — the only class allowed to touch
/// [BinanceRestClient]/[BinanceWebSocketManager] for candle data. Every
/// feature that needs OHLCV history or live candle updates goes through
/// this provider.
final marketDataManagerProvider = Provider<MarketDataManager>((ref) {
  final manager = MarketDataManager(
    restClient: ref.watch(binanceRestClientProvider),
    wsManager: ref.watch(binanceWebSocketManagerProvider),
    candleRepository: ref.watch(candleRepositoryProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final strategyRepositoryProvider = Provider<StrategyRepository>((ref) {
  return StrategyRepository(ref.watch(appDatabaseProvider));
});

final signalRepositoryProvider = Provider<SignalRepository>((ref) {
  return SignalRepository(ref.watch(appDatabaseProvider));
});

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepository(ref.watch(appDatabaseProvider));
});

final scannerServiceProvider = Provider<ScannerService>((ref) {
  return ScannerService(
    marketData: ref.watch(marketDataManagerProvider),
    marketRepository: ref.watch(marketRepositoryProvider),
    watchlistRepository: ref.watch(watchlistRepositoryProvider),
  );
});

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

/// Foreground alert checking (manual "check now" / used by pull-to-refresh
/// on the Alerts screen). The Background Monitoring service builds its
/// own separate [AlertEngine] inside its isolate — see
/// core/background/background_monitoring_service.dart — since isolates
/// can't share this provider's instance.
final alertEngineProvider = Provider<AlertEngine>((ref) {
  return AlertEngine(
    marketDataManager: ref.watch(marketDataManagerProvider),
    alertRepository: ref.watch(alertRepositoryProvider),
    strategyRepository: ref.watch(strategyRepositoryProvider),
  );
});

final symbolRepositoryProvider = Provider<SymbolRepository>((ref) {
  return SymbolRepository(ref.watch(appDatabaseProvider));
});

final riskManagerProvider = Provider<RiskManager>((ref) {
  return RiskManager(ref.watch(settingsRepositoryProvider));
});

/// The only provider anything in the app should use to place or cancel a
/// real order. See TradingEngine's doc comment for the full safety gate
/// it enforces before any order reaches Binance.
final tradingEngineProvider = Provider<TradingEngine>((ref) {
  return TradingEngine(
    restClient: ref.watch(binanceRestClientProvider),
    credentialsStore: ref.watch(secureCredentialsStoreProvider),
    symbolRepository: ref.watch(symbolRepositoryProvider),
    riskManager: ref.watch(riskManagerProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepository(ref.watch(appDatabaseProvider));
});

final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return TradeRepository(ref.watch(appDatabaseProvider));
});

/// AI Analysis credentials/service are intentionally separate providers
/// from anything trading-related — see AiAnalysisService's doc comment.
final aiCredentialsStoreProvider = Provider<AiCredentialsStore>((ref) {
  return AiCredentialsStore();
});

final aiAnalysisServiceProvider = Provider<AiAnalysisService>((ref) {
  return AiAnalysisService(credentialsStore: ref.watch(aiCredentialsStoreProvider));
});
