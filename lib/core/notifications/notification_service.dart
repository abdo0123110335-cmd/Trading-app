import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:binance_spot_pro/core/utils/safe_logger.dart';

/// Wraps `flutter_local_notifications` for the whole app. There is
/// exactly one channel ("Alerts & Signals") — Android groups all of this
/// app's alert/signal/monitoring notifications under it so the user can
/// manage them as one category in system settings.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'alerts_signals';
  static const _channelName = 'Alerts & Signals';
  static const _channelDescription =
      'Price/indicator/SMC alerts and BUY setup signals you configured';

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // requested explicitly via requestPermission()
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Requests the Android 13+ POST_NOTIFICATIONS runtime permission (a
  /// no-op, granted-by-default on older Android). Call this from
  /// Settings > Notifications or the first time the user creates an
  /// alert — never silently on app launch, so the permission prompt has
  /// context.
  Future<bool> requestPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidImpl?.requestNotificationsPermission();
    return granted ?? true;
  }

  int _nextId = 1000;

  /// Shows one alert/signal notification. Body is deliberately short and
  /// scannable per the spec (symbol + condition, price, key indicator
  /// reads, score, entry/invalidation/TP if it's a BUY setup) — this
  /// method takes an already-formatted body rather than building it
  /// itself, so the Alert Engine / Signal Engine own the exact wording.
  Future<void> showAlert({required String title, required String body, String? payload}) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _nextId++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      SafeLogger.w('Failed to show notification: $e');
    }
  }
}
