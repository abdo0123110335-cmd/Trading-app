import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/background/background_monitoring_service.dart';
import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/data/repositories/settings_repository.dart';
import 'package:binance_spot_pro/services/alert_engine/alert_models.dart';

final _alertsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(alertRepositoryProvider).getAllAlerts();
});

final _monitoringEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  return settings.getBool(SettingsKeys.backgroundMonitoringEnabled);
});

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(_alertsProvider);
    final monitoringAsync = ref.watch(_monitoringEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Alert history',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlertHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateAlertDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          monitoringAsync.when(
            data: (enabled) => _MonitoringBanner(enabled: enabled),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: alertsAsync.when(
              data: (alerts) {
                if (alerts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No alerts yet. Tap + to create one.'),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final alert = alerts[i];
                    final type = AlertType.values.firstWhere((t) => t.name == alert.type);
                    return ListTile(
                      title: Text('${alert.symbol} \u00b7 ${type.label}'),
                      subtitle: Text(
                        '${alert.timeframe}'
                        '${alert.isRepeating ? ' \u00b7 repeating' : ' \u00b7 one-shot'}'
                        '${alert.lastTriggeredAt != null ? ' \u00b7 last fired ${_timeAgo(alert.lastTriggeredAt!)}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: alert.isActive,
                            onChanged: (v) async {
                              await ref.read(alertRepositoryProvider).setActive(alert.id, v);
                              ref.invalidate(_alertsProvider);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              await ref.read(alertRepositoryProvider).deleteAlert(alert.id);
                              ref.invalidate(_alertsProvider);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _showCreateAlertDialog(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MarketColors.surfaceDarkElevated,
      builder: (context) => _CreateAlertSheet(
        onCreated: () => ref.invalidate(_alertsProvider),
      ),
    );
  }
}

class _MonitoringBanner extends ConsumerWidget {
  const _MonitoringBanner({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: MarketColors.surfaceDarkElevated,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            color: enabled ? MarketColors.bullish : MarketColors.neutral,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              enabled ? 'Background Monitoring: ON' : 'Background Monitoring: OFF',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) => _toggle(context, ref, v),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enable) async {
    final settings = ref.read(settingsRepositoryProvider);
    if (enable) {
      await BackgroundMonitoringService.instance.start();
    } else {
      await BackgroundMonitoringService.instance.stop();
    }
    await settings.setBool(SettingsKeys.backgroundMonitoringEnabled, enable);
    ref.invalidate(_monitoringEnabledProvider);
  }
}

class _CreateAlertSheet extends ConsumerStatefulWidget {
  const _CreateAlertSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends ConsumerState<_CreateAlertSheet> {
  final _symbolController = TextEditingController(text: 'BTCUSDT');
  final _valueController = TextEditingController();
  AlertType _type = AlertType.price;
  ComparisonOperator _operator = ComparisonOperator.greaterThan;
  bool _repeating = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New Alert', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _symbolController,
            decoration: const InputDecoration(labelText: 'Symbol (e.g. BTCUSDT)'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AlertType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Alert type'),
            items: [
              for (final t in AlertType.values) DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          if (_type.needsThreshold) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                DropdownButton<ComparisonOperator>(
                  value: _operator,
                  items: [
                    for (final op in ComparisonOperator.values)
                      DropdownMenuItem(value: op, child: Text(op.symbol)),
                  ],
                  onChanged: (v) => setState(() => _operator = v ?? _operator),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Value'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repeating'),
            subtitle: const Text('Stay active after firing, instead of one-shot'),
            value: _repeating,
            onChanged: (v) => setState(() => _repeating = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            child: const Text('Create Alert'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final symbol = _symbolController.text.trim().toUpperCase();
    if (symbol.isEmpty) return;

    final condition = _type.needsThreshold
        ? AlertCondition(operator: _operator, value: double.tryParse(_valueController.text))
        : const AlertCondition();

    await ref
        .read(alertRepositoryProvider)
        .createAlert(symbol: symbol, type: _type, condition: condition, isRepeating: _repeating);
    widget.onCreated();
    if (mounted) Navigator.of(context).pop();
  }
}

class AlertHistoryScreen extends ConsumerWidget {
  const AlertHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_alertHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alert History')),
      body: historyAsync.when(
        data: (history) {
          if (history.isEmpty) {
            return const Center(child: Text('No alerts have fired yet.'));
          }
          return ListView.separated(
            itemCount: history.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final h = history[i];
              return ListTile(
                title: Text('${h.symbol} \u2014 ${h.message}'),
                subtitle: Text('${h.priceAtTrigger} \u00b7 ${h.triggeredAt}'),
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

final _alertHistoryProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(alertRepositoryProvider).getHistory();
});
