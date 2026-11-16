import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/nexo_theme.dart';
import '../../../../../shared/widgets/nexo_widgets.dart';
import '../providers/collection_providers.dart';
import 'collection_detail_screen.dart';
import '../../../tags/presentation/providers/tag_providers.dart';
import '../../../tags/presentation/screens/tag_detail_screen.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Colecciones'),
        centerTitle: false,
        bottom: TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
          controller: _tabController,
          tabs: const [
            Tab(text: 'Colecciones'),
            Tab(text: 'Etiquetas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CollectionsTab(),
          _TagsTab(),
        ],
      ),
    );
  }
}

class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionsListProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _createCollection(context, ref),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        data: (list) {
          if (list.isEmpty) {
            return const NexoEmptyState(
              icon: Icons.folder_outlined,
              title: 'Sin colecciones',
              subtitle: 'Crea una colección para organizar tus contactos.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final c = list[index];
              final id = c['id'] as String;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
                  leading: const Icon(Icons.folder_rounded, color: NexoColors.accent),
                  title: Text(c['name'] as String,
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: FutureBuilder<List<String>>(
                    future: ref
                        .read(collectionRepositoryProvider)
                        .getContactIdsForCollection(id),
                    builder: (context, snap) {
                      final n = snap.data?.length ?? 0;
                      return Text('$n contactos',
                          style: Theme.of(context).textTheme.bodySmall);
                    },
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _renameCollection(context, ref, id, c['name'] as String);
                      if (v == 'delete') _deleteCollection(context, ref, id);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Renombrar')),
                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CollectionDetailScreen(collectionId: id, name: c['name'] as String),
                    ));
                  },
                ),
              );
            },
          );
        },
        loading: () => const NexoLoading(),
        error: (e, _) => NexoErrorState(message: 'Error al cargar colecciones: $e'),
      ),
    );
  }
}

Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.folder_rounded, color: NexoColors.accent),
          SizedBox(width: 10),
          Text('Nueva colección'),
        ],
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Nombre',
          hintText: 'Ej. Trabajo, Familia…',
          prefixIcon: const Icon(Icons.drive_file_rename_outline),
          filled: true,
          fillColor: Theme.of(ctx).colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear colección')),
      ],
    ),
  );
  if (ok == true && controller.text.trim().isNotEmpty) {
    await ref.read(collectionRepositoryProvider).createCollection(controller.text.trim());
  }
}

Future<void> _renameCollection(BuildContext context, WidgetRef ref, String id, String current) async {
  final controller = TextEditingController(text: current);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Renombrar colección'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Nombre',
          prefixIcon: const Icon(Icons.drive_file_rename_outline),
          filled: true,
          fillColor: Theme.of(ctx).colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
      ],
    ),
  );
  if (ok == true && controller.text.trim().isNotEmpty) {
    await ref.read(collectionRepositoryProvider).updateCollection(id, name: controller.text.trim());
  }
}

Future<void> _deleteCollection(BuildContext context, WidgetRef ref, String id) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar colección'),
      content: const Text('¿Eliminar esta colección? Los contactos no se borrarán.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
      ],
    ),
  );
  if (confirm == true) {
    await ref.read(collectionRepositoryProvider).deleteCollection(id);
  }
}

// Tags tab

class _TagsTab extends ConsumerWidget {
  const _TagsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tagsListProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _createTag(context, ref),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        data: (list) {
          if (list.isEmpty) {
            return const NexoEmptyState(
              icon: Icons.label_outlined,
              title: 'Sin etiquetas',
              subtitle: 'Crea una etiqueta para clasificar contactos.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final t = list[index];
              final id = t['id'] as String;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
                  leading: const Icon(Icons.label_rounded, color: NexoColors.accent),
                  title: Text(t['name'] as String,
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: FutureBuilder<List<String>>(
                    future: ref.read(tagRepositoryProvider).getContactIdsForTag(id),
                    builder: (context, snap) {
                      final n = snap.data?.length ?? 0;
                      return Text('$n contactos',
                          style: Theme.of(context).textTheme.bodySmall);
                    },
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _renameTag(context, ref, id, t['name'] as String);
                      if (v == 'delete') _deleteTag(context, ref, id);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Renombrar')),
                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TagDetailScreen(tagId: id, name: t['name'] as String),
                    ));
                  },
                ),
              );
            },
          );
        },
        loading: () => const NexoLoading(),
        error: (e, _) => NexoErrorState(message: 'Error al cargar etiquetas: $e'),
      ),
    );
  }
}

Future<void> _createTag(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.label_rounded, color: NexoColors.accent),
          SizedBox(width: 10),
          Text('Nueva etiqueta'),
        ],
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Nombre',
          hintText: 'Ej. Prioridad, Personal…',
          prefixIcon: const Icon(Icons.sell_outlined),
          filled: true,
          fillColor: Theme.of(ctx).colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear etiqueta')),
      ],
    ),
  );
  if (ok == true && controller.text.trim().isNotEmpty) {
    await ref.read(tagRepositoryProvider).createTag(controller.text.trim());
    ref.invalidate(tagsListProvider);
  }
}

Future<void> _renameTag(BuildContext context, WidgetRef ref, String id, String current) async {
  final controller = TextEditingController(text: current);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Renombrar etiqueta'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Nombre',
          prefixIcon: const Icon(Icons.sell_outlined),
          filled: true,
          fillColor: Theme.of(ctx).colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
      ],
    ),
  );
  if (ok == true && controller.text.trim().isNotEmpty) {
    await ref.read(tagRepositoryProvider).updateTag(id, name: controller.text.trim());
    ref.invalidate(tagsListProvider);
  }
}

Future<void> _deleteTag(BuildContext context, WidgetRef ref, String id) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar etiqueta'),
      content: const Text('¿Eliminar esta etiqueta?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
      ],
    ),
  );
  if (confirm == true) {
    await ref.read(tagRepositoryProvider).deleteTag(id);
    ref.invalidate(tagsListProvider);
  }
}
