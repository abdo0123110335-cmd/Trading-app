import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/providers/core_providers.dart';
import 'package:binance_spot_pro/core/theme/app_theme.dart';

final _aiConfigStateProvider = FutureProvider.autoDispose((ref) async {
  final store = ref.watch(aiCredentialsStoreProvider);
  return (
    hasConfig: await store.hasConfig(),
    maskedKey: await store.readMaskedApiKey(),
    baseUrl: await store.readBaseUrl(),
    model: await store.readModel(),
  );
});

class AiProviderSettingsScreen extends ConsumerWidget {
  const AiProviderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(_aiConfigStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Provider')),
      body: stateAsync.when(
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: MarketColors.neutral, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Works with any provider exposing an OpenAI-compatible '
                        '/chat/completions endpoint. AI Analysis is read-only — it never '
                        'places trades, and this key is stored completely separately from '
                        'your Binance credentials.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.hasConfig)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: MarketColors.bullish),
                  title: Text(state.model ?? ''),
                  subtitle: Text('${state.baseUrl}\n${state.maskedKey}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await ref.read(aiCredentialsStoreProvider).clear();
                      ref.invalidate(_aiConfigStateProvider);
                    },
                  ),
                ),
              )
            else
              _ConfigForm(onSaved: () => ref.invalidate(_aiConfigStateProvider)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  final _baseUrlController = TextEditingController(text: 'https://api.openai.com/v1');
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController(text: 'gpt-4o-mini');
  bool _obscure = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _baseUrlController,
          decoration: const InputDecoration(labelText: 'Base URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _modelController,
          decoration: const InputDecoration(labelText: 'Model'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            labelText: 'API Key',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          obscureText: _obscure,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    if (baseUrl.isEmpty || apiKey.isEmpty || model.isEmpty) return;

    setState(() => _saving = true);
    await ref.read(aiCredentialsStoreProvider).save(baseUrl: baseUrl, apiKey: apiKey, model: model);
    _apiKeyController.clear();
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }
}
