import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';

class SymbolFilters {
  const SymbolFilters({
    required this.symbol,
    required this.minQty,
    required this.maxQty,
    required this.stepSize,
    required this.minNotional,
    required this.tickSize,
    required this.basePrecision,
    required this.quotePrecision,
  });

  final String symbol;
  final double minQty;
  final double maxQty;
  final double stepSize;
  final double minNotional;
  final double tickSize;
  final int basePrecision;
  final int quotePrecision;
}

class SymbolRepository {
  SymbolRepository(this._db);
  final AppDatabase _db;

  /// Parses one exchangeInfo symbol entry's `filters` array into the flat
  /// fields the DB and order validator use. Binance nests these as
  /// `{filterType: "LOT_SIZE", minQty, maxQty, stepSize}`,
  /// `{filterType: "PRICE_FILTER", tickSize}`,
  /// `{filterType: "MIN_NOTIONAL" | "NOTIONAL", minNotional}`.
  SymbolFilters parseFilters(Map<String, dynamic> exchangeInfoSymbol) {
    final symbol = exchangeInfoSymbol['symbol'] as String;
    final filters = (exchangeInfoSymbol['filters'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    double minQty = 0, maxQty = 0, stepSize = 0, minNotional = 0, tickSize = 0;
    for (final f in filters) {
      switch (f['filterType']) {
        case 'LOT_SIZE':
          minQty = double.tryParse('${f['minQty']}') ?? 0;
          maxQty = double.tryParse('${f['maxQty']}') ?? 0;
          stepSize = double.tryParse('${f['stepSize']}') ?? 0;
        case 'PRICE_FILTER':
          tickSize = double.tryParse('${f['tickSize']}') ?? 0;
        case 'MIN_NOTIONAL':
        case 'NOTIONAL':
          minNotional = double.tryParse('${f['minNotional']}') ??
              double.tryParse('${f['minNotional'] ?? f['notional']}') ??
              0;
      }
    }

    return SymbolFilters(
      symbol: symbol,
      minQty: minQty,
      maxQty: maxQty,
      stepSize: stepSize,
      minNotional: minNotional,
      tickSize: tickSize,
      basePrecision: exchangeInfoSymbol['baseAssetPrecision'] as int? ?? 8,
      quotePrecision: exchangeInfoSymbol['quoteAssetPrecision'] as int? ?? 8,
    );
  }

  Future<void> syncFromExchangeInfo(List<Map<String, dynamic>> symbols) async {
    final rows = <SymbolsCompanion>[];
    for (final s in symbols) {
      final f = parseFilters(s);
      rows.add(
        SymbolsCompanion.insert(
          symbol: f.symbol,
          baseAsset: s['baseAsset'] as String? ?? '',
          quoteAsset: s['quoteAsset'] as String? ?? '',
          status: s['status'] as String? ?? 'TRADING',
          baseAssetPrecision: Value(f.basePrecision),
          quoteAssetPrecision: Value(f.quotePrecision),
          minQty: Value(f.minQty),
          maxQty: Value(f.maxQty),
          stepSize: Value(f.stepSize),
          minNotional: Value(f.minNotional),
          tickSize: Value(f.tickSize),
          isSpotTradingAllowed: Value(s['isSpotTradingAllowed'] as bool? ?? true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.symbols, rows);
    });
  }

  Future<SymbolFilters?> getFilters(String symbol) async {
    final row = await (_db.select(
      _db.symbols,
    )..where((t) => t.symbol.equals(symbol.toUpperCase()))).getSingleOrNull();
    if (row == null) return null;
    return SymbolFilters(
      symbol: row.symbol,
      minQty: row.minQty,
      maxQty: row.maxQty,
      stepSize: row.stepSize,
      minNotional: row.minNotional,
      tickSize: row.tickSize,
      basePrecision: row.baseAssetPrecision,
      quotePrecision: row.quoteAssetPrecision,
    );
  }
}
