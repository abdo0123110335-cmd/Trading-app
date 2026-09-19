import 'package:flutter/material.dart';

import 'package:binance_spot_pro/features/chart/models/chart_types.dart';

class TimeframeSelector extends StatelessWidget {
  const TimeframeSelector({super.key, required this.selected, required this.onSelected});

  final ChartTimeframe selected;
  final ValueChanged<ChartTimeframe> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: ChartTimeframe.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final tf = ChartTimeframe.all[i];
          final isSelected = tf.binanceInterval == selected.binanceInterval;
          return ChoiceChip(
            label: Text(tf.label),
            selected: isSelected,
            onSelected: (_) => onSelected(tf),
            labelStyle: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : null,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
