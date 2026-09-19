import 'package:drift/drift.dart';

import 'package:binance_spot_pro/core/database/app_database.dart';
import 'package:binance_spot_pro/features/chart/models/drawing_tool.dart';

class DrawingRepository {
  DrawingRepository(this._db);
  final AppDatabase _db;

  Future<List<DrawingObject>> getDrawings(String symbol, String timeframe) async {
    final rows = await (_db.select(_db.drawings)
          ..where((t) => t.symbol.equals(symbol.toUpperCase()) & t.timeframe.equals(timeframe)))
        .get();
    return rows
        .map(
          (r) => DrawingObject(
            id: r.id,
            symbol: r.symbol,
            timeframe: r.timeframe,
            toolType: DrawingToolType.values.firstWhere((t) => t.name == r.toolType),
            points: DrawingObject.pointsFromJson(r.pointsJson),
            style: DrawingObject.styleFromJson(r.styleJson),
          ),
        )
        .toList();
  }

  Future<int> saveDrawing(DrawingObject drawing) async {
    final companion = DrawingsCompanion.insert(
      symbol: drawing.symbol.toUpperCase(),
      timeframe: drawing.timeframe,
      toolType: drawing.toolType.name,
      pointsJson: drawing.pointsJson,
      styleJson: Value(drawing.styleJson),
      updatedAt: Value(DateTime.now()),
    );
    if (drawing.id == null) {
      return _db.into(_db.drawings).insert(companion);
    }
    await (_db.update(_db.drawings)..where((t) => t.id.equals(drawing.id!))).write(companion);
    return drawing.id!;
  }

  Future<void> deleteDrawing(int id) async {
    await (_db.delete(_db.drawings)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAllForChart(String symbol, String timeframe) async {
    await (_db.delete(_db.drawings)
          ..where((t) => t.symbol.equals(symbol.toUpperCase()) & t.timeframe.equals(timeframe)))
        .go();
  }
}
