import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nexo_theme.dart';
import '../../../../shared/widgets/nexo_widgets.dart';
import '../../../tags/presentation/providers/tag_providers.dart';
import '../../../contacts/presentation/providers/contact_providers.dart';
import '../../../contacts/presentation/screens/contact_detail_screen.dart';

class TagDetailScreen extends ConsumerStatefulWidget {
  final String tagId;
  final String name;
  const TagDetailScreen({super.key, required this.tagId, required this.name});

  @override
  ConsumerState<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends ConsumerState<TagDetailScreen> {
  bool _busy = false;

  Future<void> _addContact() async {
    if (_busy) return;
    final contacts = await ref.read(contactsListProvider.future);
    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Añadir contacto'),
        children: contacts.map((c) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, c.id),
          child: Text(c.displayName),
        )).toList(),
      ),
    );
    if (selected == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(tagRepositoryProvider).addTagToContact(widget.tagId, selected);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String contactId) async {
    await ref.read(tagRepositoryProvider).removeTagFromContact(widget.tagId, contactId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(tagRepositoryProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _busy ? null : _addContact,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_busy ? 'Añadiendo…' : 'Añadir contacto'),
      ),
      body: FutureBuilder<List<String>>(
        future: repo.getContactIdsForTag(widget.tagId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const NexoLoading();
          }
          if (snap.hasError) {
            return NexoErrorState(message: 'Error: ${snap.error}');
          }
          final ids = snap.data ?? [];
          final contactsAsync = ref.watch(contactsListProvider);
          return contactsAsync.when(
            data: (all) {
              final inTag = all.where((c) => ids.contains(c.id)).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 104),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primary.withValues(alpha: 0.15),
                          colors.surfaceContainerLow,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Icon(
                            Icons.sell_rounded,
                            size: 27,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Contactos asociados a esta etiqueta',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CONTACTOS',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          '${inTag.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  if (inTag.isEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.sell_outlined,
                              size: 29,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'Esta etiqueta está vacía',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Asigna contactos a esta etiqueta para verlos agrupados aquí.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 15),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _addContact,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Añadir contacto'),
                          ),
                        ],
                      ),
                    )
                  else
                    ...inTag.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(19),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(19),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ContactDetailScreen(contactId: c.id),
                            ));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.55)),
                            ),
                            child: Row(
                              children: [
                                NexoAvatar(
                                  displayName: c.displayName,
                                  photoPath: c.photoPath,
                                  size: 48,
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Ver ficha del contacto',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Quitar de etiqueta',
                                  onPressed: () => _remove(c.id),
                                  style: IconButton.styleFrom(
                                    backgroundColor: colors.error.withValues(alpha: 0.08),
                                    foregroundColor: colors.error,
                                  ),
                                  icon: const Icon(Icons.remove_rounded, size: 20),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
                ],
              );
            },
            loading: () => const NexoLoading(),
            error: (e, _) => NexoErrorState(message: 'Error: $e'),
          );
        },
      ),
    );
  }
}
