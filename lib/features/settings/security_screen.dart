import 'package:flutter/material.dart';

import 'package:binance_spot_pro/core/theme/app_theme.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  static const _items = [
    (
      Icons.enhanced_encryption_outlined,
      'Android Keystore',
      'Your Binance and AI provider API keys are encrypted using Android Keystore-backed '
          'secure storage. They are never stored as plain text.',
    ),
    (
      Icons.storage_outlined,
      'No Secrets in the Database',
      'API keys and secrets never touch the SQLite database — only non-sensitive '
          'preferences do.',
    ),
    (
      Icons.visibility_off_outlined,
      'No Secrets in Logs',
      'App logs automatically redact anything that looks like an API key, secret, or '
          'request signature.',
    ),
    (
      Icons.code_off_outlined,
      'No Secrets in Source Code',
      'There are no API keys embedded anywhere in this app\'s code or build artifacts.',
    ),
    (
      Icons.cloud_off_outlined,
      'Nothing Sent to a Server',
      'This app has no backend. Your credentials are used only to sign requests sent '
          'directly to Binance from your device.',
    ),
    (
      Icons.toggle_off_outlined,
      'Trading OFF by Default',
      'Live Spot Trading must be explicitly turned on, with a confirmation dialog, before '
          'any real order can be placed.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (icon, title, description) = _items[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: MarketColors.bullish),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(description, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
