import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar y exportar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(19),
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
              border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.65)),
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
                  child: Icon(Icons.sync_alt_rounded, color: colors.primary, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gestiona tus contactos',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(
                        'Guarda una copia en otro formato o incorpora contactos desde un archivo.',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          _TransferSectionHeading(
            title: 'Exportar contactos',
            subtitle: 'Crea un archivo con la información de NEXO.',
            icon: Icons.file_upload_outlined,
          ),
          const SizedBox(height: 11),
          _TransferActionTile(
            icon: Icons.data_object_rounded,
            title: 'Archivo JSON',
            subtitle: 'Formato completo para conservar los datos de NEXO.',
            onTap: _busy ? null : _exportJson,
          ),
          const SizedBox(height: 9),
          _TransferActionTile(
            icon: Icons.table_chart_outlined,
            title: 'Hoja CSV',
            subtitle: 'Compatible con hojas de cálculo.',
            onTap: _busy ? null : _exportCsv,
          ),
          const SizedBox(height: 9),
          _TransferActionTile(
            icon: Icons.contact_page_outlined,
            title: 'Tarjetas vCard',
            subtitle: 'Para compartir o trasladar contactos entre agendas.',
            onTap: _busy ? null : _exportVCard,
          ),
          const SizedBox(height: 25),
          _TransferSectionHeading(
            title: 'Importar contactos',
            subtitle: 'Selecciona un archivo compatible para añadir datos.',
            icon: Icons.file_download_outlined,
          ),
          const SizedBox(height: 11),
          _TransferActionTile(
            icon: Icons.data_object_rounded,
            title: 'Importar JSON',
            subtitle: 'Recupera contactos desde un archivo JSON de NEXO.',
            primary: true,
            onTap: _busy ? null : () => _importFile(
              (String c, {int? batchSize, ImportProgressCallback? onProgress}) =>
                  repo.importContactsFromJson(
                    c,
                    batchSize: batchSize ?? 50,
                    onProgress: onProgress,
                  ),
              'JSON',
            ),
          ),
          const SizedBox(height: 9),
          _TransferActionTile(
            icon: Icons.table_chart_outlined,
            title: 'Importar CSV',
            subtitle: 'Añade contactos desde una hoja de cálculo.',
            primary: true,
            onTap: _busy ? null : () => _importFile(
              (String c, {int? batchSize, ImportProgressCallback? onProgress}) =>
                  repo.importContactsFromCsv(
                    c,
                    batchSize: batchSize ?? 50,
                    onProgress: onProgress,
                  ),
              'CSV',
            ),
          ),
          const SizedBox(height: 9),
          _TransferActionTile(
            icon: Icons.contact_page_outlined,
            title: 'Importar vCard',
            subtitle: 'Formato habitual de las aplicaciones de contactos.',
            primary: true,
            onTap: _busy ? null : () => _importFile(
              (String c, {int? batchSize, ImportProgressCallback? onProgress}) =>
                  repo.importContactsFromVCard(
                    c,
                    batchSize: batchSize ?? 50,
                    onProgress: onProgress,
                  ),
              'vCard',
              preCount: repo.countVcfCards,
            ),
          ),
          if (_busy || _status.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_busy ? Icons.sync_rounded : Icons.info_outline_rounded,
                        color: colors.primary, size: 19),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _busy ? 'Proceso en curso' : 'Resultado',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (_busy)
                        SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  if (_busy)
                    LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(8),
                      color: colors.primary,
                    ),
                  if (_busy) const SizedBox(height: 12),
                  Text(
                    _status,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferSectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TransferSectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransferActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback? onTap;

  const _TransferActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: primary
          ? colors.primary.withValues(alpha: 0.075)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primary
                  ? colors.primary.withValues(alpha: 0.30)
                  : colors.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                primary ? Icons.add_circle_outline_rounded : Icons.download_rounded,
                color: colors.primary,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
