import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/database_provider.dart';
import '../../../../core/theme/nexo_theme.dart';
import '../../../../shared/widgets/nexo_widgets.dart';
import '../providers/backup_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String _status = '';

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final tempPath = '${Directory.systemTemp.path}/nexo_backup_temp.nexobackup';
      final result = await service.createBackup(tempPath);
      if (!result.success) {
        _status = 'Error: ${result.errors.join(', ')}';
        return;
      }
      final bytes = await File(tempPath).readAsBytes();
      await FilePicker.saveFile(fileName: 'nexo_backup.nexobackup', bytes: bytes);
      _status = 'Copia creada';
    } catch (e) {
      _status = 'Error: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (res.isEmpty) return;
    final path = res.single.path;
    if (path == null) return;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar copia'),
        content: const Text('Esto sustituira los datos actuales. Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final result = await service.restoreBackup(path);
      if (result.success) {
        ref.invalidate(appDatabaseProvider);
        _status = 'Restaurados ${result.restoredContacts} contactos';
      } else {
        _status = 'Error: ${result.errors.join(', ')}';
      }
    } catch (e) {
      _status = 'Error: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Copias de seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.cloud_done_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Protege tu información. Las copias incluyen contactos, relaciones, etiquetas, colecciones y fotografías.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NexoSpacing.xl),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              leading: const Icon(Icons.backup_outlined, size: 26),
              title: const Text('Crear copia de seguridad'),
              subtitle: const Text('Guardar una copia cifrada en formato NEXO.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _busy ? null : _createBackup,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              leading: const Icon(Icons.restore_rounded, size: 26),
              title: const Text('Restaurar copia de seguridad'),
              subtitle: const Text('Recuperar datos desde un archivo de copia.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _busy ? null : _restoreBackup,
            ),
          ),
          const SizedBox(height: NexoSpacing.xl),
          if (_busy) const NexoLoading(),
          if (_status.isNotEmpty) Text(_status, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
