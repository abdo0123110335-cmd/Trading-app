import 'package:flutter/material.dart';

import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/features/chart/models/drawing_tool.dart';

class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({
    super.key,
    required this.activeTool,
    required this.onToolSelected,
    required this.onClearAll,
  });

  final DrawingToolType? activeTool;
  final ValueChanged<DrawingToolType?> onToolSelected;
  final VoidCallback onClearAll;

  static const _icons = <DrawingToolType, IconData>{
    DrawingToolType.trendLine: Icons.show_chart,
    DrawingToolType.horizontalLine: Icons.horizontal_rule,
    DrawingToolType.verticalLine: Icons.height,
    DrawingToolType.ray: Icons.trending_flat,
    DrawingToolType.rectangle: Icons.crop_square,
    DrawingToolType.fibRetracement: Icons.stacked_line_chart,
    DrawingToolType.fibExtension: Icons.timeline,
    DrawingToolType.parallelChannel: Icons.view_week_outlined,
    DrawingToolType.priceRange: Icons.unfold_more,
    DrawingToolType.support: Icons.arrow_upward,
    DrawingToolType.resistance: Icons.arrow_downward,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MarketColors.surfaceDarkElevated,
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                for (final tool in DrawingToolType.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Tooltip(
                      message: tool.label,
                      child: IconButton(
                        isSelected: activeTool == tool,
                        selectedIcon: Icon(_icons[tool], color: Theme.of(context).colorScheme.primary),
                        icon: Icon(_icons[tool], color: MarketColors.neutral),
                        onPressed: () => onToolSelected(activeTool == tool ? null : tool),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear all drawings',
            icon: const Icon(Icons.delete_outline, color: MarketColors.bearish),
            onPressed: onClearAll,
          ),
        ],
      ),
    );
  }
}
