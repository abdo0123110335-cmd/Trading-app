import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:binance_spot_pro/core/api/binance_rest_client.dart';
import 'package:binance_spot_pro/core/database/app_database.dart';
import 'package:binance_spot_pro/core/notifications/notification_service.dart';
import 'package:binance_spot_pro/core/security/secure_credentials_store.dart';
import 'package:binance_spot_pro/core/utils/safe_logger.dart';
import 'package:binance_spot_pro/core/websocket/binance_websocket_manager.dart';
import 'package:binance_spot_pro/data/repositories/alert_repository.dart';
import 'package:binance_spot_pro/data/repositories/candle_repository.dart';
import 'package:binance_spot_pro/data/repositories/strategy_repository.dart';
import 'package:binance_spot_pro/services/alert_engine/alert_engine.dart';
import 'package:binance_spot_pro/services/market_data/market_data_manager.dart';

/// NOTE ON VERSION SENSITIVITY: `flutter_foreground_task`'s TaskHandler
/// callback signatures have changed slightly across major versions. This
/// file targets the API shape current as of `flutter_foreground_task`
/// 8.x (`onStart(DateTime, TaskStarter)`, `onRepeatEvent(DateTime)`,
/// `onDestroy(DateTime)`). If `flutter pub get` resolves a version with a
/// different TaskHandler signature, the compiler error will point
/// exactly at the mismatched override — update the signature to match.

/// The callback function that starts the background isolate. Must stay a
/// top-level (or static) function per the plugin's requirement, and must
/// keep the `vm:entry-point` pragma or Android release builds will strip
/// it during tree-shaking.
@pragma('vm:entry-point')
void monitoringStartCallback() {
  FlutterForegroundTask.setTaskHandler(MonitoringTaskHandler());
}

/// Runs entirely inside the foreground service's background isolate, so
/// it builds its own instances of the database/REST/WebSocket/Alert
/// Engine stack rather than reaching into the main isolate's Riverpod
/// container (isolates don't share memory/objects).
class MonitoringTaskHandler extends TaskHandler {
  AppDatabase? _db;
  AlertEngine? _alertEngine;
  BinanceWebSocketManager? _wsManager;
  Timer? _keepAliveTimer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    SafeLogger.i('Background Monitoring started (starter: ${starter.name})');
    await NotificationService.instance.init();

    final db = AppDatabase();
    final rest = BinanceRestClient(credentialsStore: SecureCredentialsStore());
    final ws = BinanceWebSocketManager();
    final marketData = MarketDataManager(
      restClient: rest,
      wsManager: ws,
      candleRepository: CandleRepository(db),
    );

    _db = db;
    _wsManager = ws;
    _alertEngine = AlertEngine(
      marketDataManager: marketData,
      alertRepository: AlertRepository(db),
      strategyRepository: StrategyRepository(db),
    );

    // Light keep-alive: touches the WebSocket connection state so a drop
    // while the app is backgrounded gets reconnected even between
    // alert-check ticks, without opening a second connection.
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (ws.state == WsConnectionState.disconnected) {
        unawaited(ws.connect());
      }
    });

    await _runCheck();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_runCheck());
  }

  Future<void> _runCheck() async {
    try {
      final fired = await _alertEngine?.checkAllActiveAlerts() ?? 0;
      FlutterForegroundTask.updateService(
        notificationTitle: 'Monitoring ON',
        notificationText: fired > 0
            ? 'Checked alerts — $fired new'
            : 'Watching your alerts and open charts',
      );
    } catch (e) {
      SafeLogger.w('Background alert check failed: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _keepAliveTimer?.cancel();
    await _wsManager?.disconnect();
    _wsManager?.dispose();
    await _db?.close();
    SafeLogger.i('Background Monitoring stopped');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}
}

/// Facade the UI (Settings > Background Monitoring) uses to turn
/// monitoring on/off and check its current state — never talks to
/// `FlutterForegroundTask` directly from anywhere else in the app, so
/// there's one place that owns the service lifecycle.
class BackgroundMonitoringService {
  BackgroundMonitoringService._();
  static final instance = BackgroundMonitoringService._();

  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'background_monitoring',
        channelName: 'Background Monitoring',
        channelDescription:
            'Keeps your alerts and live prices updated while Binance Spot Pro is in the background',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000), // 60s default tick
        autoRunOnBoot: false, // user must explicitly re-enable after reboot
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  /// Requests the two Android permissions Background Monitoring needs
  /// beyond what's declared in the manifest: POST_NOTIFICATIONS (to show
  /// the persistent "Monitoring ON" notification) and an explicit
  /// battery-optimization exemption prompt (Android kills unexempted
  /// background work aggressively on many OEM skins). Both are requested
  /// with context — only when the user turns monitoring on — never on
  /// app launch.
  Future<void> requestRequiredPermissions() async {
    final notifStatus = await FlutterForegroundTask.checkNotificationPermission();
    if (notifStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  Future<void> start() async {
    _ensureInitialized();
    await requestRequiredPermissions();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }
    await FlutterForegroundTask.startService(
      notificationTitle: 'Monitoring ON',
      notificationText: 'Watching your alerts and open charts',
      callback: monitoringStartCallback,
    );
  }

  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
