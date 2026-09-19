import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';
import 'package:binance_spot_pro/features/ai/ai_provider_settings_screen.dart';
import 'package:binance_spot_pro/services/ai/ai_context_builder.dart';
import 'package:binance_spot_pro/services/signal_engine/multi_timeframe_analyzer.dart';

class AiAnalysisScreen extends ConsumerStatefulWidget {
  const AiAnalysisScreen({super.key});

  @override
  ConsumerState<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends ConsumerState<AiAnalysisScreen> {
  final _symbolController = TextEditingController(text: 'BTCUSDT');
  bool _loading = false;
  String? _result;
  String? _error;
  AiAnalysisContext? _lastContext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'AI Provider settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiProviderSettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: MarketColors.neutral, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sends only real, already-computed indicator/SMC data to your '
                      'configured AI provider. It never invents data, and it never places '
                      'trades — AI Analysis is fully separate from Live Spot Trading.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _symbolController,
                  decoration: const InputDecoration(labelText: 'Symbol'),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _loading ? null : _analyze,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Analyze ${_symbolController.text.trim().toUpperCase()}'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_error!, style: const TextStyle(color: MarketColors.bearish)),
              ),
            ),
          if (_result != null) ...[
            Card(
              child: Padding(padding: const EdgeInsets.all(16), child: Text(_result!)),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Data sent to the AI', style: TextStyle(fontSize: 13)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _lastContext?.toPromptText() ?? '',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _analyze() async {
    final symbol = _symbolController.text.trim().toUpperCase();
    if (symbol.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    final hasAiConfig = await ref.read(aiCredentialsStoreProvider).hasConfig();
    if (!hasAiConfig) {
      setState(() {
        _loading = false;
        _error = 'No AI provider configured yet. Tap the settings icon above to add one.';
      });
      return;
    }

    final marketData = ref.read(marketDataManagerProvider);
    final strategyRepo = ref.read(strategyRepositoryProvider);
    final config = await strategyRepo.getDefaultStrategy();

    final mainResult = await marketData.fetchCandlesSnapshot(symbol, '1h', limit: 200);

    await mainResult.when(
      ok: (candles) async {
        if (candles.length < 60) {
          setState(() {
            _loading = false;
            _error = 'Not enough $symbol history loaded yet to analyze. Try again shortly.';
          });
          return;
        }

        final mtf = <String, TrendReading>{};
        for (final interval in multiTimeframeIntervals) {
          final r = await marketData.fetchCandlesSnapshot(symbol, interval, limit: 100);
          r.when(ok: (c) => mtf[interval] = classifyTimeframeTrend(c), err: (_) {});
        }

        final context = buildAiContext(
          symbol: symbol,
          candles: candles,
          config: config,
          multiTimeframe: mtf,
        );
        _lastContext = context;

        final aiResult = await ref.read(aiAnalysisServiceProvider).analyze(context);
        aiResult.when(
          ok: (text) => setState(() {
            _loading = false;
            _result = text;
          }),
          err: (e) => setState(() {
            _loading = false;
            _error = e.userMessage;
          }),
        );
      },
      err: (e) async {
        setState(() {
          _loading = false;
          _error = e.userMessage;
        });
      },
    );
  }

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }
}
