import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';
import 'package:binance_spot_pro/services/alert_engine/alert_models.dart';

class AlertRepository {
  AlertRepository(this._db);
  final AppDatabase _db;

  Future<List<AlertRow>> getAllAlerts() {
    return (_db.select(
      _db.alerts,
    )..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])).get();
  }

  Future<List<AlertRow>> getActiveAlerts() {
    return (_db.select(_db.alerts)..where((t) => t.isActive.equals(true))).get();
  }

  Future<int> createAlert({
    required String symbol,
    required AlertType type,
    required AlertCondition condition,
    String timeframe = '1h',
    bool isRepeating = false,
  }) {
    return _db.into(_db.alerts).insert(
      AlertsCompanion.insert(
        symbol: symbol.toUpperCase(),
        type: type.name,
        conditionJson: jsonEncode(condition.toJson()),
        timeframe: Value(timeframe),
        isRepeating: Value(isRepeating),
      ),
    );
  }

  Future<void> setActive(int id, bool active) async {
    await (_db.update(
      _db.alerts,
    )..where((t) => t.id.equals(id))).write(AlertsCompanion(isActive: Value(active)));
  }

  Future<void> deleteAlert(int id) async {
    await (_db.delete(_db.alerts)..where((t) => t.id.equals(id))).go();
  }

  Future<void> markTriggered(int id, {required bool repeating}) async {
    await (_db.update(_db.alerts)..where((t) => t.id.equals(id))).write(
      AlertsCompanion(
        lastTriggeredAt: Value(DateTime.now()),
        // A one-shot alert deactivates itself once fired; a repeating
        // alert stays active so it can fire again later.
        isActive: Value(repeating),
      ),
    );
  }

  Future<void> recordHistory({
    required int alertId,
    required String symbol,
    required String message,
    required double price,
  }) async {
    await _db.into(_db.alertHistory).insert(
      AlertHistoryCompanion.insert(
        alertId: alertId,
        symbol: symbol.toUpperCase(),
        message: message,
        priceAtTrigger: price,
      ),
    );
  }

  Future<List<AlertHistoryRow>> getHistory({int limit = 100}) {
    final query = _db.select(_db.alertHistory)
      ..orderBy([(t) => OrderingTerm(expression: t.triggeredAt, mode: OrderingMode.desc)])
      ..limit(limit);
    return query.get();
  }
}
