import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/data/repositories/drawing_repository.dart';
import 'package:binance_spot_pro/features/chart/chart_controller.dart';
import 'package:binance_spot_pro/features/chart/models/chart_types.dart';
import 'package:binance_spot_pro/features/chart/widgets/chart_canvas.dart';
import 'package:binance_spot_pro/features/chart/widgets/drawing_toolbar.dart';
import 'package:binance_spot_pro/features/chart/widgets/timeframe_selector.dart';

final _drawingRepositoryProvider = Provider<DrawingRepository>((ref) {
  return DrawingRepository(ref.watch(appDatabaseProvider));
});

/// Chart screen for one symbol. Reached from Markets (tap a row) or from
/// the bottom-nav Chart tab (defaults to BTCUSDT so the tab is never
/// empty).
class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({super.key, this.symbol = 'BTCUSDT', this.onMenuPressed});

  final String symbol;
  final VoidCallback? onMenuPressed;

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  ChartController? _controller;

  @override
  Widget build(BuildContext context) {
    _controller ??= ChartController(
      marketDataManager: ref.read(marketDataManagerProvider),
      drawingRepository: ref.read(_drawingRepositoryProvider),
      symbol: widget.symbol,
    );

    return ChangeNotifierProvider<ChartController>.value(
      value: _controller!,
      child: _ChartScreenBody(onMenuPressed: widget.onMenuPressed),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _ChartScreenBody extends StatelessWidget {
  const _ChartScreenBody({this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChartController>();

    if (controller.isFullscreen) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: const ChartCanvas()),
              _buildBottomBar(context, controller),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: onMenuPressed == null
            ? null
            : IconButton(icon: const Icon(Icons.menu), onPressed: onMenuPressed),
        title: Text(controller.symbol),
        actions: [
          PopupMenuButton<ChartStyle>(
            icon: const Icon(Icons.candlestick_chart_outlined),
            tooltip: 'Chart type',
            onSelected: controller.setChartStyle,
            itemBuilder: (context) => [
              for (final style in ChartStyle.values)
                PopupMenuItem(value: style, child: Text(style.label)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Fullscreen',
            onPressed: controller.toggleFullscreen,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          TimeframeSelector(selected: controller.timeframe, onSelected: controller.setTimeframe),
          const SizedBox(height: 8),
          Expanded(
            child: controller.loading && controller.rawCandles.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : controller.errorMessage != null && controller.rawCandles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(controller.errorMessage!, textAlign: TextAlign.center),
                    ),
                  )
                : const ChartCanvas(),
          ),
          _buildBottomBar(context, controller),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ChartController controller) {
    return DrawingToolbar(
      activeTool: controller.activeDrawingTool,
      onToolSelected: controller.selectDrawingTool,
      onClearAll: () => _confirmClearAll(context, controller),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, ChartController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MarketColors.surfaceDarkElevated,
        title: const Text('Clear all drawings?'),
        content: Text('This removes every drawing on ${controller.symbol} ${controller.timeframe.label}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: MarketColors.bearish)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearAllDrawings();
    }
  }
}
