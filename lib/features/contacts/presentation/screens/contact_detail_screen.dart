import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/nexo_theme.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../shared/widgets/nexo_widgets.dart';
import '../providers/contact_providers.dart';
import 'contact_form_screen.dart';
import '../../../quick_actions/presentation/providers/quick_actions_providers.dart';
import '../../../tags/presentation/providers/tag_providers.dart';
import '../../../collections/presentation/providers/collection_providers.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../../services/notifications/notification_service.dart';
import 'package:permission_handler/permission_handler.dart' show PermissionStatus;
import '../../../../services/notifications/notification_providers.dart';
import '../../../settings/data/repositories/settings_repository_impl.dart';
import '../../../contacts/domain/entities/contact.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  final String contactId;
  const ContactDetailScreen({super.key, required this.contactId});

  @override
  ConsumerState<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  bool _favoriteBusy = false;

  Future<void> _toggleFavorite(bool value) async {
    if (_favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    try {
      await ref.read(contactRepositoryProvider).toggleFavorite(widget.contactId, value);
      ref.invalidate(contactWithRelationsProvider(widget.contactId));
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contactWithRelationsProvider(widget.contactId));
    final tagsAsync = ref.watch(FutureProvider((ref) async {
      final repo = ref.read(tagRepositoryProvider);
      final ids = await repo.getTagIdsForContact(widget.contactId);
      final tags = <Map<String, dynamic>>[];
      for (final id in ids) {
        final t = await repo.getTagById(id);
        if (t != null) tags.add(t);
      }
      return tags;
    }));
    final collectionsAsync = ref.watch(FutureProvider((ref) async {
      final repo = ref.read(collectionRepositoryProvider);
      final ids = await repo.getCollectionIdsForContact(widget.contactId);
      final cols = <Map<String, dynamic>>[];
      for (final id in ids) {
        final c = await repo.getCollectionById(id);
        if (c != null) cols.add(c);
      }
      return cols;
    }));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ContactFormScreen(contactId: widget.contactId)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final displayName = async.value?.contact.displayName ?? 'este contacto';
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar contacto'),
                  content: Text('Se eliminara "$displayName" de NEXO.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                  ],
                ),
              );
              if (confirm == true) {
                final birthdayDateIds = <String>[];
                final current = async.value;
                if (current != null) {
                  for (final d in current.dates) {
                    if (d.type == 'birthday') birthdayDateIds.add(d.id);
                  }
                }
                await ref.read(contactRepositoryProvider).deleteContact(widget.contactId);
                try {
                  final notif = ref.read(notificationServiceProvider);
                  for (final id in birthdayDateIds) {
                    await notif.cancelBirthdayNotifications(id);
                  }
                } catch (_) {}
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: async.when(
        data: (cwr) {
          if (cwr == null) {
            return const NexoErrorState(message: 'Contacto no encontrado');
          }
          final c = cwr.contact;
          final birthdayDates = cwr.dates.where((d) => d.type == 'birthday').toList();
          final qa = ref.read(quickActionsServiceProvider);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.isFavorite ? NexoColors.favorite : Theme.of(context).colorScheme.primary.withValues(alpha: 0.45), width: 2),
                      ),
                      child: NexoAvatar(displayName: c.displayName, photoPath: c.photoPath, size: 88),
                    ),
                    const SizedBox(height: 10),
                    Text(c.displayName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                    if (c.nickname != null && c.nickname!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(c.nickname!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: NexoSpacing.md),
              Center(
                child: IconButton(
                  icon: Icon(c.isFavorite ? Icons.star : Icons.star_border, color: NexoColors.favorite),
                  onPressed: _favoriteBusy ? null : () => _toggleFavorite(!c.isFavorite),
                  tooltip: c.isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
                ),
              ),
              const SizedBox(height: NexoSpacing.lg),
              _Section(title: 'Teléfonos', children: cwr.phones.map((p) => _ActionLine(
                icon: Icons.phone,
                text: p.valueRaw,
                subtitle: p.label,
                actions: [
                  _Action(icon: Icons.call, tooltip: 'Llamar', onTap: () => qa.call(p.valueRaw)),
                  _Action(icon: Icons.sms, tooltip: 'SMS', onTap: () => qa.sendSms(p.valueRaw)),
                  _Action(icon: Icons.copy, tooltip: 'Copiar', onTap: () => Clipboard.setData(ClipboardData(text: p.valueRaw))),
                ],
              )).toList()),
              _Section(title: 'Correos', children: cwr.emails.map((e) => _ActionLine(
                icon: Icons.email,
                text: e.value,
                subtitle: e.label,
                actions: [
                  _Action(icon: Icons.mail_outline, tooltip: 'Email', onTap: () => qa.sendEmail(e.value)),
                  _Action(icon: Icons.copy, tooltip: 'Copiar', onTap: () => Clipboard.setData(ClipboardData(text: e.value))),
                ],
              )).toList()),
              _Section(title: 'Direcciones', children: cwr.addresses.map((a) {
                final text = [a.street, a.city, a.country].where((e) => e != null && e.isNotEmpty).join(', ');
                return _ActionLine(
                  icon: Icons.location_on,
                  text: text,
                  subtitle: a.label,
                  actions: [
                    if (text.isNotEmpty) _Action(icon: Icons.map, tooltip: 'Mapa', onTap: () => qa.openMap(text)),
                    _Action(icon: Icons.copy, tooltip: 'Copiar', onTap: () => Clipboard.setData(ClipboardData(text: text))),
                  ],
                );
              }).toList()),
              _Section(title: 'Organizaciones', children: cwr.organizations.map((o) => _InfoLine(icon: Icons.business, text: o.company ?? '', subtitle: o.title)).toList()),
              _Section(title: 'Redes sociales', children: cwr.socialLinks.map((s) => _ActionLine(
                icon: Icons.link,
                text: s.value,
                subtitle: s.type,
                actions: [
                  if (s.url != null && s.url!.isNotEmpty) _Action(icon: Icons.open_in_new, tooltip: 'Abrir', onTap: () => qa.openUrl(s.url!)),
                  _Action(icon: Icons.copy, tooltip: 'Copiar', onTap: () => Clipboard.setData(ClipboardData(text: s.value))),
                ],
              )).toList()),
              _Section(title: 'Fechas', children: cwr.dates.map((d) => _InfoLine(icon: Icons.cake, text: d.label ?? d.type, subtitle: d.displayDate)).toList()),
              if (birthdayDates.isNotEmpty)
                _BirthdayNotificationsSection(
                  contactId: c.id,
                  contactName: c.displayName,
                  dates: birthdayDates,
                ),
              if (birthdayDates.isEmpty)
                _Section(
                  title: 'Cumpleaños',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cake, color: NexoColors.accent),
                      title: const Text('Añadir cumpleaños'),
                      subtitle: const Text('Registra la fecha de nacimiento para recibir recordatorios.'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ContactFormScreen(contactId: widget.contactId)),
                      ),
                    ),
                  ],
                ),
              _Section(title: 'Notas', children: cwr.notes.map((n) => _InfoLine(icon: Icons.note, text: n.content)).toList()),
              _Section(title: 'Campos personalizados', children: cwr.customFields.map((f) => _InfoLine(icon: Icons.tune, text: '${f.name}: ${f.value ?? ''}')).toList()),
              tagsAsync.when(
                data: (tags) {
                  if (tags.isEmpty) return const SizedBox.shrink();
                  return _Section(title: 'Etiquetas', children: tags.map((t) => _InfoLine(icon: Icons.label, text: t['name'] as String)).toList());
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              collectionsAsync.when(
                data: (cols) {
                  if (cols.isEmpty) return const SizedBox.shrink();
                  return _Section(title: 'Colecciones', children: cols.map((c) => _InfoLine(icon: Icons.folder, text: c['name'] as String)).toList());
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          );
        },
        loading: () => const NexoLoading(),
        error: (e, _) => NexoErrorState(message: 'Error al cargar el contacto: $e'),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: NexoSpacing.md),
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: NexoSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  const _InfoLine({required this.icon, required this.text, this.subtitle});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: NexoColors.textTertiary),
          const SizedBox(width: NexoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  final List<_Action> actions;
  const _ActionLine({required this.icon, required this.text, this.subtitle, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: NexoColors.textTertiary),
          const SizedBox(width: NexoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          ...actions.map((a) => IconButton(
            icon: Icon(a.icon, size: 20),
            tooltip: a.tooltip,
            onPressed: a.onTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          )),
        ],
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.tooltip, required this.onTap});
}

class _BirthdayNotificationsSection extends ConsumerStatefulWidget {
  final String contactId;
  final String contactName;
  final List<ContactDate> dates;
  const _BirthdayNotificationsSection({
    required this.contactId,
    required this.contactName,
    required this.dates,
  });

  @override
  ConsumerState<_BirthdayNotificationsSection> createState() => _BirthdayNotificationsSectionState();
}

class _BirthdayNotificationsSectionState extends ConsumerState<_BirthdayNotificationsSection> {
  Map<String, bool> _individual = {};
  Map<String, int> _individualAdvance = {};
  bool _loaded = false;

  static const _advanceOptions = <int>[0, 1, 2, 3, 7];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = SettingsRepositoryImpl(ref.read(appDatabaseProvider));
    final enabled = <String, bool>{};
    final advance = <String, int>{};
    for (final d in widget.dates) {
      enabled[d.id] = await repo.getBool('birthday_indiv_enabled_${d.id}', defaultValue: true);
      final a = await repo.getInt('birthday_indiv_advance_${d.id}', defaultValue: -1);
      advance[d.id] = a;
    }
    if (mounted) {
      setState(() {
        _individual = enabled;
        _individualAdvance = advance;
        _loaded = true;
      });
    }
  }

  Future<void> _setEnabled(String dateId, bool v) async {
    final repo = SettingsRepositoryImpl(ref.read(appDatabaseProvider));
    await repo.setBool('birthday_indiv_enabled_$dateId', v);
    setState(() => _individual[dateId] = v);
    final notif = ref.read(notificationServiceProvider);
    if (!v) {
      await notif.cancelBirthdayNotifications(dateId);
    } else {
      // Al activar individualmente: comprobar permiso global y del sistema.
      final granted = await notif.hasPermission();
      if (!granted) {
        final status = await notif.requestPermission();
        if (status != PermissionStatus.granted) {
          setState(() => _individual[dateId] = false);
          await repo.setBool('birthday_indiv_enabled_$dateId', false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permiso de notificaciones no concedido.'),
              ),
            );
          }
          return;
        }
      }
      final globalOn = await repo.getBool('birthday_notifications', defaultValue: true);
      if (globalOn) {
        await _reprogramOne(repo, notif, dateId);
      }
    }
  }

  Future<void> _setAdvance(String dateId, int? v) async {
    final repo = SettingsRepositoryImpl(ref.read(appDatabaseProvider));
    await repo.setInt('birthday_indiv_advance_$dateId', v ?? -1);
    setState(() => _individualAdvance[dateId] = v ?? -1);
    final notif = ref.read(notificationServiceProvider);
    final globalOn = await repo.getBool('birthday_notifications', defaultValue: true);
    final indivOn = _individual[dateId] ?? true;
    if (globalOn && indivOn) {
      await _reprogramOne(repo, notif, dateId);
    } else {
      await notif.cancelBirthdayNotifications(dateId);
    }
  }

  Future<void> _reprogramOne(SettingsRepository repo, NotificationService notif, String dateId) async {
    final d = widget.dates.firstWhere((x) => x.id == dateId);
    final advance = _individualAdvance[dateId] ?? -1;
    final globalAdvance = await repo.getInt('birthday_advance_days', defaultValue: 0);
    final eff = advance >= 0 ? advance : globalAdvance;
    final sound = await repo.getBool('birthday_sound', defaultValue: true);
    await notif.scheduleBirthdayNotifications(
      dateId: dateId,
      contactName: widget.contactName,
      month: d.date.month,
      day: d.date.day,
      advanceDays: eff,
      sound: sound,
    );
  }

  String _advanceLabel(int? v, SettingsRepository repo) {
    // Synchronous-ish label using cached global when needed; fallback to 'general'
    if (v == null || v < 0) return 'Usar configuración general';
    return v == 0 ? 'Mismo día' : '$v días antes';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final repo = SettingsRepositoryImpl(ref.read(appDatabaseProvider));
    return _Section(
      title: 'Recordatorios de cumpleaños',
      children: widget.dates.map((d) {
        final on = _individual[d.id] ?? true;
        final advance = _individualAdvance[d.id] ?? -1;
        final isCustom = advance >= 0;
        return ListTile(
          leading: Icon(Icons.cake, color: NexoColors.accent),
          title: Text(d.label ?? 'Cumpleaños'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.displayDate),
              if (isCustom)
                Text('Antelación: ${_advanceLabel(advance, repo)} (individual)',
                    style: const TextStyle(fontSize: 12, color: NexoColors.textTertiary))
              else
                Text('Antelación: configuración general',
                    style: const TextStyle(fontSize: 12, color: NexoColors.textTertiary)),
            ],
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: on, onChanged: (val) => _setEnabled(d.id, val)),
              if (isCustom)
                const SizedBox(height: 6)
              else
                const SizedBox.shrink(),
            ],
          ),
          onTap: isCustom ? null : () => _showAdvancePicker(d.id),
        );
      }).toList(),
    );
  }

  Future<void> _showAdvancePicker(String dateId) async {
    final current = _individualAdvance[dateId] ?? -1;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Antelación individual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _advanceOptions.map((a) {
            final already = a == current;
            return ListTile(
              selected: already,
              title: Text(a == 0 ? 'Mismo día' : '$a días antes'),
              subtitle: already ? const Text('Seleccionado') : null,
              onTap: () => Navigator.pop(ctx, a),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Usar general')),
          TextButton(onPressed: () => Navigator.pop(ctx, current), child: const Text('Aceptar')),
        ],
      ),
    );
    if (selected != null) {
      await _setAdvance(dateId, selected);
    } else {
      await _setAdvance(dateId, -1);
    }
  }
}
