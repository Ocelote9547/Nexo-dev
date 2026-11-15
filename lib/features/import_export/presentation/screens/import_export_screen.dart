import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/components/nexo_button.dart';
import '../../../../core/design/components/nexo_card.dart';
import '../../../../core/design/nexo_design_system.dart';
import '../../../../shared/widgets/nexo_widgets.dart';
import '../providers/import_export_providers.dart';
import '../../domain/entities/import_export.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  bool _busy = false;
  String _status = '';
  double _progress = 0.0;

  Future<void> _exportJson() async {
    setState(() {
      _busy = true;
      _progress = 0.0;
      _status = '';
    });
    try {
      final repo = ref.read(importExportRepositoryProvider);
      final list = await repo.exportAllContactsToPortable(
        onProgress: (info) {
          if (mounted) {
            setState(() {
              _progress = info.percentage;
              _status =
                  'Exportando ${info.processed}/${info.total} contactos a JSON';
            });
          }
        },
      );
      final jsonStr = jsonEncode(list.map((c) => c.toJson()).toList());
      await FilePicker.saveFile(
        fileName: 'nexo_contacts.json',
        bytes: Uint8List.fromList(utf8.encode(jsonStr)),
      );
      _status = 'Exportado ${list.length} contactos a JSON';
    } catch (e) {
      _status = 'Error: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() {
      _busy = true;
      _progress = 0.0;
      _status = '';
    });
    try {
      final repo = ref.read(importExportRepositoryProvider);
      final csv = await repo.exportContactsToCsv(
        onProgress: (info) {
          if (mounted) {
            setState(() {
              _progress = info.percentage;
              _status =
                  'Exportando ${info.processed}/${info.total} contactos a CSV';
            });
          }
        },
      );
      await FilePicker.saveFile(
        fileName: 'nexo_contacts.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      _status = 'Exportado CSV';
    } catch (e) {
      _status = 'Error: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportVCard() async {
    setState(() {
      _busy = true;
      _progress = 0.0;
      _status = '';
    });
    try {
      final repo = ref.read(importExportRepositoryProvider);
      final vcf = await repo.exportAllContactsToVCard(
        onProgress: (info) {
          if (mounted) {
            setState(() {
              _progress = info.percentage;
              _status =
                  'Exportando ${info.processed}/${info.total} contactos a vCard';
            });
          }
        },
      );
      await FilePicker.saveFile(
        fileName: 'nexo_contacts.vcf',
        bytes: Uint8List.fromList(utf8.encode(vcf)),
      );
      _status = 'Exportado vCard';
    } catch (e) {
      _status = 'Error: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFile(
    Future<ImportResult> Function(String, {int? batchSize, ImportProgressCallback? onProgress}) importer,
    String label, {
    int Function(String)? preCount,
  }) async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (res.isEmpty) return;
    final path = res.single.path;
    if (path == null) return;

    // Pre-count for vCard: show detected cards before importing
    int? detectedCount;
    if (preCount != null) {
      final content = await File(path).readAsString(encoding: utf8);
      detectedCount = preCount(content);
      if (mounted) {
        setState(() {
          _busy = true;
          _progress = 0.0;
          _status =
              'Detectadas $detectedCount tarjetas vCard. Iniciando importación...';
        });
      }
    } else {
      setState(() {
        _busy = true;
        _progress = 0.0;
        _status = 'Importando...';
      });
    }

    try {
      // Re-read content if we already read it for pre-counting
      final content = detectedCount != null
          ? (await File(path).readAsString(encoding: utf8))
          : await File(path).readAsString(encoding: utf8);

      final r = await importer(
        content,
        batchSize: 50,
        onProgress: (info) {
          if (mounted) {
            setState(() {
              _progress = info.percentage;
              _status =
                  'Importando ${info.processed}/${info.total} - '
                  '${info.created} creados, ${info.skipped} omitidos, '
                  '${info.errors} errores, ${info.warningsCount} advertencias';
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _status =
              'Importación completada: ${r.created} creados, ${r.skipped} omitidos, '
              '${r.errors} errores, ${r.replaced} reemplazados, '
              '${r.warnings.length} advertencias.';
          if (r.failedRecords.isNotEmpty) {
            _status += '\n${r.failedRecords.length} registros con errores';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(importExportRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Importar y exportar')),
      body: ListView(
        padding: const EdgeInsets.all(NexoDesignSpacing.lg),
        children: [
          Text('Exportar', style: NexoDesignTypography.titleLarge),
          const SizedBox(height: NexoDesignSpacing.md),
          NexoCard(
            child: Column(
              children: [
                NexoButton(
                  onPressed: _busy ? null : _exportJson,
                  variant: NexoButtonVariant.secondary,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Exportar JSON'),
                      Icon(Icons.download, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: NexoDesignSpacing.md),
                NexoButton(
                  onPressed: _busy ? null : _exportCsv,
                  variant: NexoButtonVariant.secondary,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Exportar CSV'),
                      Icon(Icons.download, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: NexoDesignSpacing.md),
                NexoButton(
                  onPressed: _busy ? null : _exportVCard,
                  variant: NexoButtonVariant.secondary,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Exportar vCard'),
                      Icon(Icons.download, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NexoDesignSpacing.xl),
          Text('Importar', style: NexoDesignTypography.titleLarge),
          const SizedBox(height: NexoDesignSpacing.md),
          NexoCard(
            child: Column(
              children: [
                NexoButton(
                  onPressed: _busy ? null : () => _importFile(
                    (String c, {int? batchSize, ImportProgressCallback? onProgress}) =>
                        repo.importContactsFromJson(
                          c,
                          batchSize: batchSize ?? 50,
                          onProgress: onProgress,
                        ),
                    'JSON',
                  ),
                  variant: NexoButtonVariant.primary,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Importar JSON'),
                      Icon(Icons.upload, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: NexoDesignSpacing.md),
                NexoButton(
                  onPressed: _busy ? null : () => _importFile(
                    (String c, {int? batchSize, ImportProgressCallback? onProgress}) =>
                        repo.importContactsFromCsv(
                          c,
                          batchSize: batchSize ?? 50,
                          onProgress: onProgress,
                        ),
                    'CSV',
                  ),
                  variant: NexoButtonVariant.primary,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Importar CSV'),
                      Icon(Icons.upload, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: NexoDesignSpacing.md),
                NexoButton(
                  onPressed: _busy ? null : () => _importFile(
                    (String c, {int? batchSize, ImportProgressCallback? onProgress}) =>
                        repo.importContactsFromVCard(
                          c,
                          batchSize: batchSize ?? 50,
                          onProgress: onProgress,
                        ),
                    'vCard',
                    preCount: repo.countVcfCards,
                  ),
                  variant: NexoButtonVariant.primary,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Importar vCard'),
                      Icon(Icons.upload, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NexoDesignSpacing.xl),
          if (_busy)
            Column(
              children: [
                const NexoLoading(),
                const SizedBox(height: NexoDesignSpacing.md),
                LinearProgressIndicator(
                  value: _progress,
                  color: NexoDesignColors.accent,
                ),
                const SizedBox(height: NexoDesignSpacing.md),
                Text(
                  _status,
                  style: NexoDesignTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          if (!_busy && _status.isNotEmpty)
            Text(
              _status,
              style: NexoDesignTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
