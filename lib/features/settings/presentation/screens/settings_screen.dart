import 'package:flutter/material.dart';
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
      _AppearanceRow(
        tokens: tokens,
        mode: NexoThemeMode.light,
        current: _themeMode,
        label: 'Claro',
        subtitle: 'Fondo claro y superficies blancas',
        onTap: _setThemeMode,
      ),
      Divider(height: 1, indent: 16, endIndent: 16, color: tokens.border),
      _AppearanceRow(
        tokens: tokens,
        mode: NexoThemeMode.dark,
        current: _themeMode,
        label: 'Oscuro',
        subtitle: 'Fondo azul noche y superficies navy',
        onTap: _setThemeMode,
      ),
      Divider(height: 1, indent: 16, endIndent: 16, color: tokens.border),
      _AppearanceRow(
        tokens: tokens,
        mode: NexoThemeMode.system,
        current: _themeMode,
        label: 'Automático',
        subtitle: 'Sigue el tema del sistema Android',
        onTap: _setThemeMode,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.tokens(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        centerTitle: false,
        toolbarHeight: 68,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 17),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(Icons.tune_rounded, color: tokens.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personaliza NEXO',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tu experiencia, tus datos y la seguridad de tu agenda.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          _SettingsSectionHeading(
            title: 'Apariencia',
            subtitle: 'Adapta NEXO a tu forma de usarlo',
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: 10),
          _settingsPanel(
            tokens,
            child: Column(children: _appearancePreferences()),
          ),
          const SizedBox(height: 20),

          _SettingsSectionHeading(
            title: 'Notificaciones',
            subtitle: 'No te pierdas fechas importantes',
            icon: Icons.notifications_none_rounded,
          ),
          const SizedBox(height: 10),
          _settingsPanel(
            tokens,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text('Cumpleaños'),
                  subtitle: const Text('Avisos locales de cumpleaños'),
                  secondary: Icon(Icons.cake_outlined, color: tokens.accent),
                  value: _birthdayNotifications,
                  onChanged: _setGlobal,
                ),
                Divider(height: 1, color: tokens.border),
                ..._birthdayPreferences(),
                if (_permissionMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: NexoColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _permissionMessage!,
                            style: TextStyle(color: NexoColors.error, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _openAppSettingsAndRefresh,
                          child: const Text('Ajustes'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SettingsSectionHeading(
            title: 'Tus datos',
            subtitle: 'Importación, exportación y copias',
            icon: Icons.folder_open_outlined,
          ),
          const SizedBox(height: 10),
          _settingsPanel(
            tokens,
            child: Column(
              children: [
                _SettingsActionTile(
                  icon: Icons.import_export_rounded,
                  title: 'Importar y exportar',
                  subtitle: 'Mover tus contactos y archivos',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImportExportScreen()),
                  ),
                ),
                Divider(height: 1, indent: 58, color: tokens.border),
                _SettingsActionTile(
                  icon: Icons.backup_outlined,
                  title: 'Copias de seguridad',
                  subtitle: 'Crear o restaurar una copia',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SettingsSectionHeading(
            title: 'Seguridad',
            subtitle: 'Protege tu información personal',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 10),
          _settingsPanel(
            tokens,
            child: _SettingsActionTile(
              icon: Icons.lock_outline_rounded,
              title: 'Privacidad y seguridad',
              subtitle: 'Bloqueo y opciones de protección',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _SettingsSectionHeading(
            title: 'Ayuda y acerca de',
            subtitle: 'Información sobre NEXO',
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 10),
          _settingsPanel(
            tokens,
            child: Column(
              children: [
                Divider(height: 1, indent: 58, color: tokens.border),
                const ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  leading: Icon(Icons.hub_outlined),
                  title: Text('NEXO'),
                  subtitle: Text('Agenda personal · v1.2.0'),
                  trailing: Icon(Icons.verified_outlined, size: 19),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'NEXO · Tu espacio de contactos',
              style: theme.textTheme.labelSmall?.copyWith(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsPanel(
    NexoDesignTokens tokens, {
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
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

class _SettingsSectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SettingsSectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 19, color: theme.colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 21),
      onTap: onTap,
    );
  }
}
