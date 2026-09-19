import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:binance_spot_pro/app.dart';
import 'package:binance_spot_pro/core/notifications/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Required once at process start so the foreground service's background
  // isolate (Background Monitoring, Settings) can exchange messages with
  // the UI isolate. Safe to call even if the user never enables
  // monitoring — it's a no-op until a service is actually started.
  FlutterForegroundTask.initCommunicationPort();
  NotificationService.instance.init();
  runApp(const ProviderScope(child: BinanceSpotProApp()));
}
