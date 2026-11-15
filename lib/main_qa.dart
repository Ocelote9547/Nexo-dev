import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/startup/app_initializer.dart';
import 'core/theme/nexo_theme.dart';
import 'services/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const ProviderScope(child: NexoApp()));
}

class NexoApp extends StatelessWidget {
  const NexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXO QA',
      debugShowCheckedModeBanner: false,
      theme: NexoTheme.dark(),
      home: const AppInitializer(),
    );
  }
}