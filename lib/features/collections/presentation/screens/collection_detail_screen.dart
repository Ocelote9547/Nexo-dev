import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/nexo_theme.dart';
import '../../../../../shared/widgets/nexo_widgets.dart';
import '../providers/collection_providers.dart';
import '../../../contacts/presentation/providers/contact_providers.dart';
import '../../../contacts/presentation/screens/contact_detail_screen.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;
  final String name;
  const CollectionDetailScreen({super.key, required this.collectionId, required this.name});

  @override
  ConsumerState<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen> {
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
      await ref.read(collectionRepositoryProvider).addContactToCollection(widget.collectionId, selected);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String contactId) async {
    await ref.read(collectionRepositoryProvider).removeContactFromCollection(widget.collectionId, contactId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(collectionRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _busy ? null : _addContact,
        child: const Icon(Icons.person_add),
      ),
      body: FutureBuilder<List<String>>(
        future: repo.getContactIdsForCollection(widget.collectionId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const NexoLoading();
          }
          final ids = snap.data ?? [];
          if (ids.isEmpty) {
            return const NexoEmptyState(
              icon: Icons.people_outline,
              title: 'Sin contactos',
              subtitle: 'Añade contactos a esta colección.',
            );
          }
          final contactsAsync = ref.watch(contactsListProvider);
          return contactsAsync.when(
            data: (all) {
              final inCol = all.where((c) => ids.contains(c.id)).toList();
              return ListView.builder(
                padding: const EdgeInsets.all(NexoSpacing.lg),
                itemCount: inCol.length,
                itemBuilder: (context, index) {
                  final c = inCol[index];
                  return Card(
                    child: ListTile(
                      leading: NexoAvatar(displayName: c.displayName, photoPath: c.photoPath),
                      title: Text(c.displayName, style: Theme.of(context).textTheme.titleMedium),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _remove(c.id),
                      ),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ContactDetailScreen(contactId: c.id),
                        ));
                      },
                    ),
                  );
                },
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
