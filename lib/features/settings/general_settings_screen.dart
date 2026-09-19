import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/core/notifications/notification_service.dart';

class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('General')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Theme'),
            subtitle: Text('Dark (default and only theme in this build)'),
            trailing: Icon(Icons.dark_mode_outlined),
          ),
          const ListTile(
            title: Text('Language'),
            subtitle: Text('English'),
            trailing: Icon(Icons.language_outlined),
          ),
          const ListTile(
            title: Text('Currency'),
            subtitle: Text('USDT'),
            trailing: Icon(Icons.attach_money),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notification Permission'),
            subtitle: const Text('Required for Alerts and Background Monitoring notifications'),
            trailing: FilledButton(
              onPressed: () async {
                final granted = await NotificationService.instance.requestPermission();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(granted ? 'Notifications enabled' : 'Permission denied')),
                  );
                }
              },
              child: const Text('Request'),
            ),
          ),
        ],
      ),
    );
  }
}
