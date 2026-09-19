import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/features/chart/chart_screen.dart';

final _watchlistsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(watchlistRepositoryProvider).getWatchlists();
});

class WatchlistsScreen extends ConsumerWidget {
  const WatchlistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlistsAsync = ref.watch(_watchlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createWatchlist(context, ref),
          ),
        ],
      ),
      body: watchlistsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return const Center(child: Text('No watchlists yet. Tap + to create one.'));
          }
          return ListView.separated(
            itemCount: lists.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final w = lists[i];
              return ListTile(
                leading: const Icon(Icons.list_alt),
                title: Text(w.name),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'rename') _renameWatchlist(context, ref, w.id, w.name);
                    if (action == 'delete') _deleteWatchlist(context, ref, w.id, w.name);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WatchlistDetailScreen(watchlistId: w.id, name: w.name),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }

  Future<void> _createWatchlist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MarketColors.surfaceDarkElevated,
        title: const Text('New watchlist'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Swing, Scalping, SMC')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(watchlistRepositoryProvider).createWatchlist(name);
      ref.invalidate(_watchlistsProvider);
    }
  }

  Future<void> _renameWatchlist(BuildContext context, WidgetRef ref, int id, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MarketColors.surfaceDarkElevated,
        title: const Text('Rename watchlist'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(watchlistRepositoryProvider).renameWatchlist(id, name);
      ref.invalidate(_watchlistsProvider);
    }
  }

  Future<void> _deleteWatchlist(BuildContext context, WidgetRef ref, int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MarketColors.surfaceDarkElevated,
        title: const Text('Delete watchlist?'),
        content: Text('This removes "$name" and its symbols.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: MarketColors.bearish)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(watchlistRepositoryProvider).deleteWatchlist(id);
      ref.invalidate(_watchlistsProvider);
    }
  }
}

final _watchlistSymbolsProvider = FutureProvider.autoDispose.family<List<String>, int>((ref, id) {
  return ref.watch(watchlistRepositoryProvider).getSymbols(id);
});

class WatchlistDetailScreen extends ConsumerWidget {
  const WatchlistDetailScreen({super.key, required this.watchlistId, required this.name});
  final int watchlistId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbolsAsync = ref.watch(_watchlistSymbolsProvider(watchlistId));

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: symbolsAsync.when(
        data: (symbols) {
          if (symbols.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No symbols yet. Add coins from the Markets tab.'),
              ),
            );
          }
          return ListView.separated(
            itemCount: symbols.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final symbol = symbols[i];
              return ListTile(
                title: Text(symbol),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    await ref.read(watchlistRepositoryProvider).removeSymbol(watchlistId, symbol);
                    ref.invalidate(_watchlistSymbolsProvider(watchlistId));
                  },
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChartScreen(symbol: symbol)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }
}
