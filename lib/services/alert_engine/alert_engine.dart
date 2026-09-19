import 'dart:convert';

import 'package:binance_spot_pro/core/database/app_database.dart';
import 'package:binance_spot_pro/core/notifications/notification_service.dart';
import 'package:binance_spot_pro/core/utils/safe_logger.dart';
import 'package:binance_spot_pro/data/repositories/alert_repository.dart';
import 'package:binance_spot_pro/data/repositories/strategy_repository.dart';
import 'package:binance_spot_pro/services/alert_engine/alert_evaluator.dart';
import 'package:binance_spot_pro/services/alert_engine/alert_models.dart';
import 'package:binance_spot_pro/services/market_data/market_data_manager.dart';
import 'package:binance_spot_pro/services/strategy_engine/strategy_config.dart';

/// Checks every active alert once, fires a local notification and
/// records history for each one that triggers. Used both by a manual
/// "check now" action and by the Background Monitoring foreground
/// service's periodic tick (Settings > Background Monitoring).
///
/// A repeating alert that just fired won't fire again for
/// [minRefireGap] even though it stays active — otherwise a condition
/// that stays true for many consecutive checks (e.g. "RSI < 30" while
/// RSI sits at 25 for an hour) would spam a notification every tick.
class AlertEngine {
  AlertEngine({
    required MarketDataManager marketDataManager,
    required AlertRepository alertRepository,
    required StrategyRepository strategyRepository,
    NotificationService? notificationService,
    this.minRefireGap = const Duration(minutes: 15),
  }) : _marketData = marketDataManager,
       _alertRepo = alertRepository,
       _strategyRepo = strategyRepository,
       _notifications = notificationService ?? NotificationService.instance;

  final MarketDataManager _marketData;
  final AlertRepository _alertRepo;
  final StrategyRepository _strategyRepo;
  final NotificationService _notifications;
  final Duration minRefireGap;

  /// Runs one full pass over all active alerts. Returns how many fired,
  /// for callers (e.g. the monitoring notification's status text) that
  /// want a quick summary.
  Future<int> checkAllActiveAlerts() async {
    final alerts = await _alertRepo.getActiveAlerts();
    if (alerts.isEmpty) return 0;

    final config = await _strategyRepo.getDefaultStrategy();
    var firedCount = 0;

    for (final alert in alerts) {
      try {
        final fired = await _checkOne(alert, config);
        if (fired) firedCount++;
      } catch (e) {
        // One bad alert (e.g. a delisted symbol) must never stop the
        // rest of the batch from being checked.
        SafeLogger.w('Alert ${alert.id} (${alert.symbol}) check failed: $e');
      }
    }
    return firedCount;
  }

  Future<bool> _checkOne(AlertRow alert, StrategyConfig config) async {
    if (alert.lastTriggeredAt != null &&
        DateTime.now().difference(alert.lastTriggeredAt!) < minRefireGap) {
      return false;
    }

    final candlesResult = await _marketData.fetchCandlesSnapshot(
      alert.symbol,
      alert.timeframe,
      limit: 200,
    );

    return candlesResult.when(
      ok: (candles) async {
        final type = AlertType.values.firstWhere((t) => t.name == alert.type);
        final condition = AlertCondition.fromJson(
          jsonDecode(alert.conditionJson) as Map<String, dynamic>,
        );
        final result = evaluateAlert(type, condition, candles, config);
        if (result == null) return false;

        await _fire(alert, type, result);
        return true;
      },
      err: (_) => false,
    );
  }

  Future<void> _fire(AlertRow alert, AlertType type, AlertTriggerResult result) async {
    await _alertRepo.recordHistory(
      alertId: alert.id,
      symbol: alert.symbol,
      message: result.message,
      price: result.price,
    );
    await _alertRepo.markTriggered(alert.id, repeating: alert.isRepeating);
    await _notifications.showAlert(
      title: '${alert.symbol} ${type.label}',
      body: result.message,
      payload: alert.symbol,
    );
  }
}
