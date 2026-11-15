import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/theme_provider.dart';
import 'core/startup/app_initializer.dart';
import 'core/theme/nexo_theme.dart';
import 'services/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const ProviderScope(child: NexoApp()));
}

class NexoApp extends ConsumerWidget {
  const NexoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(nexoThemeModeProvider);
    final brightness = MediaQuery.of(context).platformBrightness;
    final resolvedMode = resolveThemeMode(themeMode, brightness);

    return MaterialApp(
      title: 'NEXO',
      debugShowCheckedModeBanner: false,
      theme: NexoTheme.light(),
      darkTheme: NexoTheme.dark(),
      themeMode: resolvedMode,
      home: const AppInitializer(),
    );
  }
}