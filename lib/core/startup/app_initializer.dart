import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';
import '../../database/app_database.dart';
import '../../shared/widgets/nexo_widgets.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../services/notifications/notification_providers.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/privacy/presentation/screens/unlock_screen.dart';
import '../../features/privacy/presentation/providers/privacy_providers.dart';

class AppInitializer extends ConsumerStatefulWidget {
  const AppInitializer({super.key});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  bool _ready = false;
  bool _locked = false;
  bool _unlocked = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.customSelect('SELECT 1').get();
      await _reconcileBirthdayNotifications(db);
      final privacy = ref.read(privacyServiceProvider);
      _locked = await privacy.hasPin();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _reconcileBirthdayNotifications(AppDatabase db) async {
    final notif = ref.read(notificationServiceProvider);
    final repo = SettingsRepositoryImpl(db);
    final globalOn = await repo.getBool('birthday_notifications', defaultValue: false);
    if (!globalOn) return;
    final advance = await repo.getInt('birthday_advance_days', defaultValue: 0);
    final sound = await repo.getBool('birthday_sound', defaultValue: true);
    final dates = await db.select(db.contactDates).get();
    final contacts = await db.select(db.contacts).get();
    final nameMap = {for (final c in contacts) c.id: c.displayName ?? 'Contacto'};
    for (final d in dates) {
      if (d.type != 'birthday') continue;
      final indivEnabled = await repo.getBool('birthday_indiv_enabled_${d.id}', defaultValue: true);
      if (indivEnabled == false) continue;
      final indivAdvance = await repo.getInt('birthday_indiv_advance_${d.id}', defaultValue: -1);
      final effAdvance = indivAdvance >= 0 ? indivAdvance : advance;
      final name = nameMap[d.contactId] ?? 'Contacto';
      await notif.scheduleBirthdayNotifications(
        dateId: d.id,
        contactName: name,
        month: d.date.month,
        day: d.date.day,
        advanceDays: effAdvance,
        sound: sound,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: NexoErrorState(
          message: 'No se pudo iniciar NEXO: $_error',
          onRetry: () {
            setState(() {
              _error = null;
              _ready = false;
            });
            _init();
          },
        ),
      );
    }
    if (!_ready) {
      return const Scaffold(body: NexoLoading());
    }
    if (_locked && !_unlocked) {
      return UnlockScreen(onUnlocked: () {
        setState(() => _unlocked = true);
      });
    }
    return const HomeScreen();
  }
}

