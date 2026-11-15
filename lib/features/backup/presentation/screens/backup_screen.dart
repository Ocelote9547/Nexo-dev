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
        padding: const EdgeInsets.all(NexoSpacing.lg),
        children: [
          Text('Una copia de seguridad conserva contactos, relaciones, etiquetas, colecciones y fotografias.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: NexoSpacing.xl),
          Card(child: ListTile(title: const Text('Crear copia de seguridad'), trailing: const Icon(Icons.backup), onTap: _busy ? null : _createBackup)),
          Card(child: ListTile(title: const Text('Restaurar copia de seguridad'), trailing: const Icon(Icons.restore), onTap: _busy ? null : _restoreBackup)),
          const SizedBox(height: NexoSpacing.xl),
          if (_busy) const NexoLoading(),
          if (_status.isNotEmpty) Text(_status, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
