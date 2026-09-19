import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';

class SignalRepository {
  SignalRepository(this._db);
  final AppDatabase _db;

  Future<void> saveSignal(SignalResult signal) async {
    await _db.into(_db.signals).insert(
      SignalsCompanion.insert(
        symbol: signal.symbol,
        timeframe: signal.timeframe,
        signalType: signal.type.name.toUpperCase(),
        price: signal.price,
        score: signal.score,
        reasonsJson: jsonEncode(signal.reasons),
        entryZoneLow: Value(signal.entryLow),
        entryZoneHigh: Value(signal.entryHigh),
        invalidation: Value(signal.invalidation),
        tp1: Value(signal.tp1),
        tp2: Value(signal.tp2),
        createdAt: Value(signal.timestamp),
      ),
    );
  }

  Future<List<SignalRow>> getRecentSignals({int limit = 50}) {
    final query = _db.select(_db.signals)
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
      ..limit(limit);
    return query.get();
  }

  Future<void> deleteOlderThan(DateTime before) async {
    await (_db.delete(_db.signals)..where((t) => t.createdAt.isSmallerThanValue(before))).go();
  }
}
