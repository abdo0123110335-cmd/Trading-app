import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/features/screener/screener_providers.dart';
import 'package:binance_spot_pro/services/scanner/scan_models.dart';
import 'package:binance_spot_pro/services/scanner/scanner_service.dart';
import 'package:binance_spot_pro/services/signal_engine/signal_engine.dart';

/// Combines the spec's SCREENER (filters + sort over a symbol universe)
/// and MARKET SCANNER (choose a source scope, search for named setups)
/// sections into one screen — they share the same underlying scan
/// pipeline, so splitting them into two screens would mean running the
/// same expensive scan twice for no benefit to the user.
class ScreenerScreen extends ConsumerWidget {
  const ScreenerScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(screenerParamsProvider);
    final scan = ref.watch(screenerScanProvider);
    final watchlistsAsync = ref.watch(_watchlistsForPickerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screener'),
        leading: onMenuPressed == null
            ? null
            : IconButton(icon: const Icon(Icons.menu), onPressed: onMenuPressed),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: watchlistsAsync.when(
              data: (watchlists) => _SourceRow(params: params, watchlists: watchlists),
              loading: () => const SizedBox(height: 32),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
          _TagFilterRow(params: params),
          const SizedBox(height: 4),
          _SortAndScanRow(),
          const Divider(height: 1),
          Expanded(
            child: scan.when(
              data: (results) {
                if (results.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No symbols match the current filters. Tap Scan to run again.'),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ScanRow(result: results[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _watchlistsForPickerProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(watchlistRepositoryProvider).getWatchlists();
});

class _SourceRow extends ConsumerWidget {
  const _SourceRow({required this.params, required this.watchlists});
  final ScreenerParams params;
  final List<dynamic> watchlists; // WatchlistRow, kept dynamic to avoid a Drift import here

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<ScanSource>(
            segments: const [
              ButtonSegment(value: ScanSource.allSpot, label: Text('All Spot'), icon: Icon(Icons.public, size: 16)),
              ButtonSegment(value: ScanSource.favorites, label: Text('Favorites'), icon: Icon(Icons.star, size: 16)),
              ButtonSegment(value: ScanSource.watchlist, label: Text('Watchlist'), icon: Icon(Icons.list, size: 16)),
            ],
            selected: {params.source},
            onSelectionChanged: (s) {
              final source = s.first;
              int? watchlistId = params.watchlistId;
              if (source == ScanSource.watchlist && watchlistId == null && watchlists.isNotEmpty) {
                watchlistId = watchlists.first.id as int;
              }
              ref.read(screenerParamsProvider.notifier).state =
                  params.copyWith(source: source, watchlistId: watchlistId);
            },
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ),
      ],
    );
  }
}

class _TagFilterRow extends ConsumerWidget {
  const _TagFilterRow({required this.params});
  final ScreenerParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final tag in ScanSetupTag.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(tag.label, style: const TextStyle(fontSize: 12)),
                selected: params.activeTags.contains(tag),
                visualDensity: VisualDensity.compact,
                onSelected: (selected) {
                  final next = Set<ScanSetupTag>.from(params.activeTags);
                  if (selected) {
                    next.add(tag);
                  } else {
                    next.remove(tag);
                  }
                  ref.read(screenerParamsProvider.notifier).state = params.copyWith(activeTags: next);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SortAndScanRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(screenerParamsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          DropdownButton<ScreenerSort>(
            value: params.sortBy,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: ScreenerSort.score, child: Text('Sort: Score')),
              DropdownMenuItem(value: ScreenerSort.volume, child: Text('Sort: Rel. Volume')),
              DropdownMenuItem(value: ScreenerSort.change, child: Text('Sort: 24h Change')),
              DropdownMenuItem(value: ScreenerSort.rsi, child: Text('Sort: RSI')),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(screenerParamsProvider.notifier).state = params.copyWith(sortBy: v);
              }
            },
          ),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.radar, size: 18),
            label: const Text('Scan'),
            onPressed: () => ref.invalidate(screenerScanProvider),
          ),
        ],
      ),
    );
  }
}

class _ScanRow extends StatelessWidget {
  const _ScanRow({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final signal = result.signal;
    Color typeColor;
    String typeLabel;
    switch (signal.type) {
      case SignalType.buy:
        typeColor = MarketColors.bullish;
        typeLabel = 'BUY';
      case SignalType.exit:
        typeColor = MarketColors.bearish;
        typeLabel = 'EXIT';
      case SignalType.hold:
        typeColor = MarketColors.neutral;
        typeLabel = 'HOLD';
    }

    return ListTile(
      title: Row(
        children: [
          Text(result.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      subtitle: Wrap(
        spacing: 4,
        children: [
          for (final tag in result.tags)
            Chip(
              label: Text(tag.label, style: const TextStyle(fontSize: 9)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: MarketColors.surfaceDark,
              side: const BorderSide(color: MarketColors.borderDark),
            ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'RSI ${result.rsi?.toStringAsFixed(1) ?? '—'}',
            style: const TextStyle(fontSize: 11, color: MarketColors.neutral),
          ),
          Text('${signal.score}/100', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
