import 'package:flutter/material.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nexo_theme.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/design/nexo_design_system.dart';
import '../../../backup/presentation/screens/backup_screen.dart';
import '../../../import_export/presentation/screens/import_export_screen.dart';
import '../../../../services/notifications/notification_providers.dart';
import 'package:permission_handler/permission_handler.dart' show PermissionStatus;
import '../providers/settings_providers.dart';
import '../../../privacy/presentation/screens/privacy_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _birthdayNotifications = false;
  int _advanceDays = 0;
  int _hour = 9;
  bool _sound = true;
  bool _loaded = false;
  String? _permissionMessage;
  bool _permissionChecked = false;
  NexoThemeMode _themeMode = NexoThemeMode.system;

  static const _advanceOptions = <int>[0, 1, 2, 3, 7];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
    // Al volver de los ajustes de Android, comprobar de nuevo el permiso
    // y actualizar el estado coherente.
    if (_birthdayNotifications && !_permissionChecked) {
      _permissionChecked = true;
      _refreshPermissionState();
    }
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final on = await repo.getBool('birthday_notifications', defaultValue: false);
    final advance = await repo.getInt('birthday_advance_days', defaultValue: 0);
    final hour = await repo.getInt('birthday_notification_hour', defaultValue: 9);
    final sound = await repo.getBool('birthday_sound', defaultValue: true);
    final themeMode = ref.read(nexoThemeModeProvider);
    if (mounted) {
      setState(() {
        _birthdayNotifications = on;
        _advanceDays = advance;
        _hour = hour;
        _sound = sound;
        _themeMode = themeMode;
      });
      _permissionChecked = false;
    }
  }

  Future<void> _refreshPermissionState() async {
    final granted = await ref.read(notificationServiceProvider).hasPermission();
    if (mounted && _birthdayNotifications && !granted) {
      setState(() => _permissionMessage =
          'Permiso de notificaciones no concedido. Los avisos no se mostrarán.');
    } else if (mounted) {
      setState(() => _permissionMessage = null);
    }
  }

  Future<void> _setGlobal(bool v) async {
    final repo = ref.read(settingsRepositoryProvider);
    final notif = ref.read(notificationServiceProvider);

    if (v) {
      // Al activar: solicitar permiso antes de habilitar.
      final status = await notif.requestPermission();
      if (status != PermissionStatus.granted) {
        // Revertir el interruptor a apagado.
        setState(() => _birthdayNotifications = false);
        await repo.setBool('birthday_notifications', false);
        if (status == PermissionStatus.permanentlyDenied) {
          await _showPermanentlyDeniedDialog();
        } else if (mounted) {
          setState(() => _permissionMessage =
              'Permiso de notificaciones denegado. No se podrán mostrar avisos.');
        }
        return;
      }
      // Concedido: limpiar mensaje previo.
      if (mounted) setState(() => _permissionMessage = null);
    } else {
      await _cancelAll();
    }

    setState(() => _birthdayNotifications = v);
    await repo.setBool('birthday_notifications', v);
    if (mounted) {
      _reconcileAll();
    }
  }

  Future<void> _showPermanentlyDeniedDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permiso denegado permanentemente'),
        content: const Text(
          'NEXO no puede mostrar notificaciones hasta que concedas el permiso '
          'en los ajustes de Android.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _openAppSettingsAndRefresh();
    }
  }

  Future<void> _openAppSettingsAndRefresh() async {
    await ref.read(notificationServiceProvider).openAppSettings();
    if (!mounted) return;
    await _refreshPermissionState();
    // Si tras volver el permiso quedó concedido, reprogramar.
    final granted = await ref.read(notificationServiceProvider).hasPermission();
    if (granted && _birthdayNotifications) {
      await _reconcileAll();
    }
  }

  Future<void> _setAdvance(int v) async {
    setState(() => _advanceDays = v);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setInt('birthday_advance_days', v);
    if (_birthdayNotifications) {
      await _reconcileAll();
    }
  }

  Future<void> _setHour(int v) async {
    setState(() => _hour = v);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setInt('birthday_notification_hour', v);
    if (_birthdayNotifications) {
      await _reconcileAll();
    }
  }

  Future<void> _setSound(bool v) async {
    setState(() => _sound = v);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setBool('birthday_sound', v);
    if (_birthdayNotifications) {
      await _reconcileAll();
    }
  }

  Future<void> _setThemeMode(NexoThemeMode mode) async {
    setState(() => _themeMode = mode);
    await ref.read(nexoThemeModeProvider.notifier).setMode(mode);
  }

  Future<void> _cancelAll() async {
    final repo = ref.read(settingsRepositoryProvider);
    final all = await repo.getAll();
    final dateIds = <String>{};
    for (final entry in all.entries) {
      if (entry.key.startsWith('birthday_indiv_enabled_')) {
        dateIds.add(entry.key.substring('birthday_indiv_enabled_'.length));
      }
    }
    final notif = ref.read(notificationServiceProvider);
    for (final id in dateIds) {
      await notif.cancelBirthdayNotifications(id);
    }
  }

  Future<void> _reconcileAll() async {
    if (!_birthdayNotifications) {
      return;
    }
    final granted = await ref.read(notificationServiceProvider).hasPermission();
    if (!granted) {
      if (mounted) {
        setState(() => _permissionMessage =
            'Permiso de notificaciones no concedido. Los avisos no se mostrarán.');
      }
      return;
    }
    final notif = ref.read(notificationServiceProvider);
    // Cancel everything and reprogram from current contacts.
    await _cancelAll();
    final repo = ref.read(settingsRepositoryProvider);
    final advance = await repo.getInt('birthday_advance_days', defaultValue: 0);
    final sound = await repo.getBool('birthday_sound', defaultValue: true);
    final db = ref.read(appDatabaseProvider);
    final dates = await db.select(db.contactDates).get();
    final contacts = await db.select(db.contacts).get();
    final nameMap = {for (final c in contacts) c.id: c.displayName ?? 'Contacto'};
    for (final d in dates) {
      if (d.type != 'birthday') continue;
      final indivEnabled = await repo.getBool(
        'birthday_indiv_enabled_${d.id}',
        defaultValue: true,
      );
      if (indivEnabled == false) continue;
      final indivAdvance = await repo.getInt(
        'birthday_indiv_advance_${d.id}',
        defaultValue: -1,
      );
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

  Future<void> _pickHour() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: 0),
    );
    if (picked != null) {
      await _setHour(picked.hour);
    }
  }

  List<Widget> _birthdayPreferences() {
    return [
      const SizedBox(height: NexoSpacing.md),
      ListTile(
        title: const Text('Antelación'),
        subtitle: Text(
          _advanceDays == 0
              ? 'El mismo día'
              : '$_advanceDays días antes',
        ),
        trailing: DropdownButton<int>(
          value: _advanceDays,
          items: _advanceOptions
              .map((a) => DropdownMenuItem<int>(
                    value: a,
                    child: Text(a == 0 ? 'Mismo día' : '$a días antes'),
                  ))
              .toList(),
          onChanged: (v) => v != null ? _setAdvance(v) : null,
        ),
      ),
      const SizedBox(height: NexoSpacing.md),
      ListTile(
        title: const Text('Hora del aviso'),
        subtitle: Text('${_hour.toString().padLeft(2, '0')}:00'),
        trailing: const Icon(Icons.access_time),
        onTap: _pickHour,
      ),
      const SizedBox(height: NexoSpacing.md),
      SwitchListTile(
        title: const Text('Sonido'),
        subtitle: const Text('Reproducir sonido en los avisos'),
        value: _sound,
        onChanged: _setSound,
      ),
    ];
  }

  List<Widget> _appearancePreferences() {
    final tokens = ref.tokens(context);
    return [
      const SizedBox(height: NexoSpacing.md),
      Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: NexoSpacing.md),
      Card(
        child: Column(
          children: [
            _AppearanceRow(
              tokens: tokens,
              mode: NexoThemeMode.light,
              current: _themeMode,
              label: 'Claro',
              subtitle: 'Fondo claro y superficies blancas',
              onTap: _setThemeMode,
            ),
            _AppearanceRow(
              tokens: tokens,
              mode: NexoThemeMode.dark,
              current: _themeMode,
              label: 'Oscuro',
              subtitle: 'Fondo azul noche y superficies navy',
              onTap: _setThemeMode,
            ),
            _AppearanceRow(
              tokens: tokens,
              mode: NexoThemeMode.system,
              current: _themeMode,
              label: 'Automático',
              subtitle: 'Sigue el tema del sistema Android',
              onTap: _setThemeMode,
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(NexoSpacing.lg),
        children: [
          Text('Preferencias', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: NexoSpacing.md),
          ..._appearancePreferences(),
          const SizedBox(height: NexoSpacing.md),
          Card(
            child: ListTile(
              leading: const Icon(Icons.waving_hand_outlined),
              title: const Text('Ver bienvenida de NEXO'),
              subtitle: const Text(
                'Previsualiza los cinco pasos del asistente sin modificar tus contactos.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(
                    onCompleted: () async {
                      if (mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: NexoSpacing.xl),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Notificaciones de cumpleaños'),
                  subtitle: const Text(
                    'Avisos locales de cumpleaños (activado por defecto)',
                  ),
                  value: _birthdayNotifications,
                  onChanged: _setGlobal,
                ),
                ..._birthdayPreferences(),
                // ignore: curly_braces_in_flow_control_structures
                if (_permissionMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(NexoSpacing.md),
                    child: Text(
                      _permissionMessage!,
                      style: TextStyle(color: NexoColors.error),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: NexoSpacing.xl),
          Text('Datos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: NexoSpacing.md),
          Card(
            child: ListTile(
              title: const Text('Importar y exportar'),
              trailing: const Icon(Icons.import_export),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ImportExportScreen())),
            ),
          ),
          const SizedBox(height: NexoSpacing.xl),
          Card(
            child: ListTile(
              title: const Text('Copias de seguridad'),
              trailing: const Icon(Icons.backup),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const BackupScreen())),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Privacidad y seguridad'),
              trailing: const Icon(Icons.lock),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
            ),
          ),
          Text('Acerca de', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: NexoSpacing.md),
          Card(
            child: ListTile(
              title: const Text('NEXO'),
              subtitle: const Text('Gestor personal de contactos · v1.0'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de selección de modo de tema en Ajustes.
class _AppearanceRow extends StatelessWidget {
  final NexoDesignTokens tokens;
  final NexoThemeMode mode;
  final NexoThemeMode current;
  final String label;
  final String subtitle;
  final ValueChanged<NexoThemeMode> onTap;
  const _AppearanceRow({
    required this.tokens,
    required this.mode,
    required this.current,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == mode;
    return InkWell(
      onTap: () => onTap(mode),
      borderRadius: BorderRadius.circular(NexoDesignRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NexoSpacing.md,
          vertical: NexoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accent.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          border: isSelected
              ? Border.all(color: tokens.accent, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _iconForMode(mode),
              color: isSelected ? tokens.accent : tokens.textSecondary,
              size: 20,
            ),
            const SizedBox(width: NexoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? tokens.accent : tokens.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: NexoSpacing.xs),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: NexoDesignColors.accent,
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForMode(NexoThemeMode mode) {
    switch (mode) {
      case NexoThemeMode.light:
        return Icons.brightness_7;
      case NexoThemeMode.dark:
        return Icons.brightness_4;
      case NexoThemeMode.system:
        return Icons.device_unknown;
    }
  }
}