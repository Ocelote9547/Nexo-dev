import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'package:nexo/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/services/media/media_service.dart';

/// Result of a backup operation.
class BackupResult {
  final bool success;
  final String? backupPath;
  final int? fileCount;
  final int? totalSizeBytes;
  final List<String> errors;
  final List<String> warnings;

  BackupResult({
    required this.success,
    this.backupPath,
    this.fileCount,
    this.totalSizeBytes,
    this.errors = const [],
    this.warnings = const [],
  });
}

/// Result of a restore operation.
class RestoreResult {
  final bool success;
  final int restoredContacts;
  final List<String> errors;
  final List<String> warnings;

  RestoreResult({
    required this.success,
    this.restoredContacts = 0,
    this.errors = const [],
    this.warnings = const [],
  });
}

/// Manifest for a .nexobackup file.
class BackupManifest {
  final String formatVersion;
  final int schemaVersion;
  final String nexosVersion;
  final DateTime createdAt;
  final List<String> includedFiles;
  final Map<String, int> fileSizes;
  final Map<String, String> fileChecksums;

  BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.nexosVersion,
    required this.createdAt,
    required this.includedFiles,
    required this.fileSizes,
    required this.fileChecksums,
  });

  Map<String, dynamic> toJson() {
    return {
      'formatVersion': formatVersion,
      'schemaVersion': schemaVersion,
      'nexosVersion': nexosVersion,
      'createdAt': createdAt.toIso8601String(),
      'includedFiles': includedFiles,
      'fileSizes': fileSizes,
      'fileChecksums': fileChecksums,
    };
  }

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    final formatVersion = json['formatVersion'];
    final schemaVersion = json['schemaVersion'];
    final nexosVersion = json['nexosVersion'];
    final createdAt = json['createdAt'];
    final includedFiles = json['includedFiles'];
    final fileSizes = json['fileSizes'];
    final fileChecksums = json['fileChecksums'];

    if (formatVersion is! String ||
        schemaVersion is! int ||
        nexosVersion is! String ||
        createdAt is! String ||
        includedFiles is! List ||
        fileSizes is! Map ||
        fileChecksums is! Map) {
      throw FormatException('Campos obligatorios del manifiesto faltantes o inválidos');
    }

    return BackupManifest(
      formatVersion: formatVersion,
      schemaVersion: schemaVersion,
      nexosVersion: nexosVersion,
      createdAt: DateTime.parse(createdAt),
      includedFiles: includedFiles.cast<String>(),
      fileSizes: fileSizes.map((k, v) => MapEntry(k as String, v as int)),
      fileChecksums: fileChecksums.map((k, v) => MapEntry(k as String, v as String)),
    );
  }
}

/// Constants for backup limits.
class BackupLimits {
  static const int maxTotalSizeBytes = 2 * 1024 * 1024 * 1024;
  static const int maxEntrySizeBytes = 512 * 1024 * 1024;
  static const int maxEntries = 100000;
  static const String formatVersion = '1.0';
}

/// Service for creating and restoring .nexobackup files.
class BackupService {
  final ContactRepository _contactRepository;
  final MediaService _media;

  BackupService({
    required this._contactRepository,
    required this._media,
  });

  Future<BackupResult> createBackup(String destinationPath) async {
    try {
      final warnings = <String>[];

      final contacts = await _contactRepository.getAllContacts();
      final contactData = <Map<String, dynamic>>[];
      final mediaFiles = <String, Uint8List>{};

      for (final c in contacts) {
        final rel = await _contactRepository.getContactWithRelations(c.id);
        if (rel == null) continue;

        final entry = {
          'id': rel.contact.id,
          'givenName': rel.contact.givenName,
          'middleName': rel.contact.middleName,
          'familyName': rel.contact.familyName,
          'prefix': rel.contact.prefix,
          'suffix': rel.contact.suffix,
          'phoneticGiven': rel.contact.phoneticGiven,
          'phoneticFamily': rel.contact.phoneticFamily,
          'nickname': rel.contact.nickname,
          'photoPath': rel.contact.photoPath,
          'photoHash': rel.contact.photoHash,
          'isFavorite': rel.contact.isFavorite,
          'favoriteMarkedAt':
              rel.contact.favoriteMarkedAt?.toIso8601String(),
          'createdAt': rel.contact.createdAt.toIso8601String(),
          'updatedAt': rel.contact.updatedAt.toIso8601String(),
          'phones': rel.phones.map((p) => {
            'id': p.id,
            'valueRaw': p.valueRaw,
            'valueNormalized': p.valueNormalized,
            'label': p.label,
            'isPrimary': p.isPrimary,
            'sortOrder': p.sortOrder,
          }).toList(),
          'emails': rel.emails.map((e) => {
            'id': e.id,
            'value': e.value,
            'label': e.label,
            'isPrimary': e.isPrimary,
            'sortOrder': e.sortOrder,
          }).toList(),
          'addresses': rel.addresses.map((a) => {
            'id': a.id,
            'label': a.label,
            'street': a.street,
            'number': a.number,
            'apartment': a.apartment,
            'postalCode': a.postalCode,
            'city': a.city,
            'region': a.region,
            'country': a.country,
            'latitude': a.latitude,
            'longitude': a.longitude,
            'sortOrder': a.sortOrder,
          }).toList(),
          'socialLinks': rel.socialLinks.map((s) => {
            'id': s.id,
            'type': s.type,
            'value': s.value,
            'url': s.url,
            'label': s.label,
            'sortOrder': s.sortOrder,
          }).toList(),
          'organizations': rel.organizations.map((o) => {
            'id': o.id,
            'company': o.company,
            'title': o.title,
            'department': o.department,
            'website': o.website,
            'notes': o.notes,
            'isPrimary': o.isPrimary,
            'sortOrder': o.sortOrder,
          }).toList(),
          'dates': rel.dates.map((d) => {
            'id': d.id,
            'type': d.type,
            'label': d.label,
            'date': d.date.toIso8601String(),
            'yearUnknown': d.yearUnknown,
            'recurrence': d.recurrence,
            'sortOrder': d.sortOrder,
          }).toList(),
          'notes': rel.notes.map((n) => {
            'id': n.id,
            'content': n.content,
            'source': n.source,
            'createdAt': n.createdAt.toIso8601String(),
            'updatedAt': n.updatedAt.toIso8601String(),
          }).toList(),
          'customFields': rel.customFields.map((c) => {
            'id': c.id,
            'name': c.name,
            'type': c.type,
            'value': c.value,
            'sortOrder': c.sortOrder,
          }).toList(),
        };
        contactData.add(entry);

        if (rel.contact.photoPath != null) {
          try {
            final file = await _media.resolve(rel.contact.photoPath!);
            if (file != null && await file.exists()) {
              final bytes = await file.readAsBytes();
              mediaFiles[rel.contact.photoPath!] = bytes;
            }
          } catch (_) {
            warnings.add(
              'No se pudo leer el archivo multimedia: ${rel.contact.photoPath}',
            );
          }
        }
      }

      final dataJson = jsonEncode({
        'contacts': contactData,
        'exportedAt': DateTime.now().toIso8601String(),
      });
      final dataBytes = Uint8List.fromList(utf8.encode(dataJson));

      final archive = Archive();

      archive.addFile(
        ArchiveFile(
          'data.json',
          dataBytes.length,
          dataBytes,
        ),
      );

      for (final entry in mediaFiles.entries) {
        archive.addFile(
          ArchiveFile(
            'media/${entry.key}',
            entry.value.length,
            entry.value,
          ),
        );
      }

      final fileChecksums = <String, String>{};
      final fileSizes = <String, int>{};

      fileChecksums['data.json'] = sha256.convert(dataBytes).toString();
      fileSizes['data.json'] = dataBytes.length;

      for (final entry in mediaFiles.entries) {
        final checksum = sha256.convert(entry.value).toString();
        fileChecksums['media/${entry.key}'] = checksum;
        fileSizes['media/${entry.key}'] = entry.value.length;
      }

      final manifest = BackupManifest(
        formatVersion: BackupLimits.formatVersion,
        schemaVersion: 2,
        nexosVersion: '1.0.0',
        createdAt: DateTime.now(),
        includedFiles: ['data.json', ...mediaFiles.keys],
        fileSizes: fileSizes,
        fileChecksums: fileChecksums,
      );

      final manifestJson = jsonEncode(manifest.toJson());
      final manifestBytes = Uint8List.fromList(utf8.encode(manifestJson));
      archive.addFile(
        ArchiveFile(
          'manifest.json',
          manifestBytes.length,
          manifestBytes,
        ),
      );

      final finalZipBytes = ZipEncoder().encode(archive);

      if (finalZipBytes.length > BackupLimits.maxTotalSizeBytes) {
        return BackupResult(
          success: false,
          errors: [
            'El archivo de respaldo excede el tamaño máximo permitido',
          ],
        );
      }

      final destFile = File(destinationPath);
      await destFile.writeAsBytes(finalZipBytes, flush: true);

      return BackupResult(
        success: true,
        backupPath: destinationPath,
        fileCount: archive.files.length,
        totalSizeBytes: finalZipBytes.length,
        warnings: warnings,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        errors: ['Error al crear respaldo: $e'],
      );
    }
  }

  Future<BackupManifest> validateBackup(String backupPath) async {
    final file = File(backupPath);
    if (!await file.exists()) {
      throw FileSystemException(
        'No se encontró el archivo de respaldo',
        backupPath,
      );
    }

    final bytes = await file.readAsBytes();
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw FormatException('Archivo ZIP inválido: $e');
    }
    if (archive.files.isEmpty) {
      throw FormatException(
        'El archivo de respaldo está vacío o no es válido',
      );
    }

    final manifestFile = archive.files.firstWhere(
      (f) => p.basename(f.name) == 'manifest.json',
      orElse: () =>
          throw FormatException('El manifiesto del respaldo falta'),
    );

    Map<String, dynamic> manifestJson;
    try {
      final manifestContent = manifestFile.content as List<int>;
      manifestJson = jsonDecode(utf8.decode(manifestContent)) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Manifiesto inválido: $e');
    }

    BackupManifest manifest;
    try {
      manifest = BackupManifest.fromJson(manifestJson);
    } catch (e) {
      throw FormatException('Manifiesto inválido: $e');
    }

    for (final archivedFile in archive.files) {
      final fileName = archivedFile.name;
      if (fileName == 'manifest.json') continue;

      final fileBytes = archivedFile.content as List<int>;
      final actualChecksum = sha256.convert(fileBytes).toString();
      final expectedChecksum = manifest.fileChecksums[fileName];

      if (expectedChecksum == null) {
        throw FormatException('Archivo no listado en el manifiesto: $fileName');
      }

      if (actualChecksum != expectedChecksum) {
        throw FormatException(
          'Checksum no coincide para $fileName. '
          'El archivo puede estar corrupto.',
        );
      }

      if (fileBytes.length > BackupLimits.maxEntrySizeBytes) {
        throw FormatException('Entrada demasiado grande: $fileName');
      }
    }

    for (final archivedFile in archive.files) {
      final fileName = archivedFile.name;
      if (fileName.contains('..') || p.isAbsolute(fileName)) {
        throw FormatException('Ruta no segura en el respaldo: $fileName');
      }
    }

    if (archive.files.length > BackupLimits.maxEntries) {
      throw FormatException('Demasiadas entradas en el respaldo');
    }

    // Total uncompressed size check.
    var totalSize = 0;
    for (final archivedFile in archive.files) {
      totalSize += (archivedFile.content as List<int>).length;
      if (totalSize > BackupLimits.maxTotalSizeBytes) {
        throw FormatException('Tamaño total descomprimido excede el límite');
      }
    }

    // Duplicate/conflicting names check.
    final names = <String>{};
    for (final archivedFile in archive.files) {
      final base = p.basename(archivedFile.name);
      if (!names.add(base)) {
        throw FormatException('Nombre de archivo duplicado o conflictivo: $base');
      }
    }

    return manifest;
  }

  Future<RestoreResult> restoreBackup(String backupPath) async {
    try {
      await validateBackup(backupPath);
    } catch (e) {
      return RestoreResult(
        success: false,
        errors: ['Respaldo inválido: $e'],
      );
    }

    final tempDir = Directory.systemTemp.createTempSync('nexo_restore_');
    final backupDir = Directory(p.join(tempDir.path, 'backup'));
    await backupDir.create(recursive: true);

    final previousBackupPath = p.join(tempDir.path, 'previous.nexobackup');
    await createBackup(previousBackupPath);

    try {
      final file = File(backupPath);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final archivedFile in archive.files) {
        final fileName = archivedFile.name;
        final targetFile = File(p.join(backupDir.path, fileName));
        await targetFile.create(recursive: true);
        await targetFile.writeAsBytes(
          archivedFile.content as List<int>,
          flush: true,
        );
      }

      final dataFile = File(p.join(backupDir.path, 'data.json'));
      final dataJson =
          jsonDecode(await dataFile.readAsString()) as Map<String, dynamic>;
      final contactsData = (dataJson['contacts'] as List? ?? []);

      final existing = await _contactRepository.getAllContacts();
      for (final c in existing) {
        await _contactRepository.deleteContact(c.id);
      }

      int restored = 0;
      for (final cData in contactsData) {
        try {
          final contact = Contact(
            id: cData['id'] as String,
            givenName: cData['givenName'] as String?,
            middleName: cData['middleName'] as String?,
            familyName: cData['familyName'] as String?,
            prefix: cData['prefix'] as String?,
            suffix: cData['suffix'] as String?,
            phoneticGiven: cData['phoneticGiven'] as String?,
            phoneticFamily: cData['phoneticFamily'] as String?,
            nickname: cData['nickname'] as String?,
            photoPath: cData['photoPath'] as String?,
            photoHash: cData['photoHash'] as String?,
            isFavorite: cData['isFavorite'] as bool? ?? false,
            favoriteMarkedAt: cData['favoriteMarkedAt'] != null
                ? DateTime.parse(cData['favoriteMarkedAt'] as String)
                : null,
            createdAt: DateTime.parse(cData['createdAt'] as String),
            updatedAt: DateTime.parse(cData['updatedAt'] as String),
          );

          final phones = (cData['phones'] as List? ?? []).map((p) => Phone(
            id: p['id'] as String,
            contactId: contact.id,
            valueRaw: p['valueRaw'] as String,
            valueNormalized: p['valueNormalized'] as String?,
            label: p['label'] as String? ?? 'mobile',
            isPrimary: p['isPrimary'] as bool? ?? false,
            sortOrder: p['sortOrder'] as int? ?? 0,
          )).toList();

          final emails = (cData['emails'] as List? ?? []).map((e) => Email(
            id: e['id'] as String,
            contactId: contact.id,
            value: e['value'] as String,
            label: e['label'] as String? ?? 'home',
            isPrimary: e['isPrimary'] as bool? ?? false,
            sortOrder: e['sortOrder'] as int? ?? 0,
          )).toList();

          final addresses = (cData['addresses'] as List? ?? []).map((a) => Address(
            id: a['id'] as String,
            contactId: contact.id,
            label: a['label'] as String?,
            street: a['street'] as String?,
            number: a['number'] as String?,
            apartment: a['apartment'] as String?,
            postalCode: a['postalCode'] as String?,
            city: a['city'] as String?,
            region: a['region'] as String?,
            country: a['country'] as String?,
            latitude: a['latitude'] as double?,
            longitude: a['longitude'] as double?,
            sortOrder: a['sortOrder'] as int? ?? 0,
          )).toList();

          final socialLinks = (cData['socialLinks'] as List? ?? []).map((s) => SocialLink(
            id: s['id'] as String,
            contactId: contact.id,
            type: s['type'] as String,
            value: s['value'] as String,
            url: s['url'] as String?,
            label: s['label'] as String?,
            sortOrder: s['sortOrder'] as int? ?? 0,
          )).toList();

          final organizations = (cData['organizations'] as List? ?? []).map((o) => Organization(
            id: o['id'] as String,
            contactId: contact.id,
            company: o['company'] as String?,
            title: o['title'] as String?,
            department: o['department'] as String?,
            website: o['website'] as String?,
            notes: o['notes'] as String?,
            isPrimary: o['isPrimary'] as bool? ?? false,
            sortOrder: o['sortOrder'] as int? ?? 0,
          )).toList();

          final dates = (cData['dates'] as List? ?? []).map((d) => ContactDate(
            id: d['id'] as String,
            contactId: contact.id,
            type: d['type'] as String? ?? 'birthday',
            label: d['label'] as String?,
            date: DateTime.parse(d['date'] as String),
            yearUnknown: d['yearUnknown'] as bool? ?? false,
            recurrence: d['recurrence'] as String? ?? 'yearly',
            sortOrder: d['sortOrder'] as int? ?? 0,
          )).toList();

          final notes = (cData['notes'] as List? ?? []).map((n) => Note(
            id: n['id'] as String,
            contactId: contact.id,
            content: n['content'] as String,
            source: n['source'] as String? ?? 'manual',
            createdAt: DateTime.parse(n['createdAt'] as String),
            updatedAt: DateTime.parse(n['updatedAt'] as String),
          )).toList();

          final customFields = (cData['customFields'] as List? ?? []).map((f) => CustomField(
            id: f['id'] as String,
            contactId: contact.id,
            name: f['name'] as String,
            type: f['type'] as String? ?? 'text',
            value: f['value'] as String?,
            sortOrder: f['sortOrder'] as int? ?? 0,
          )).toList();

          await _contactRepository.createContact(
            contact,
            phones: phones,
            emails: emails,
            addresses: addresses,
            socialLinks: socialLinks,
            organizations: organizations,
            dates: dates,
            notes: notes,
            customFields: customFields,
          );

          final photoPath = contact.photoPath;
          if (photoPath != null) {
            final mediaFile = File(p.join(backupDir.path, photoPath));
            if (await mediaFile.exists()) {
              final bytes = await mediaFile.readAsBytes();
              await _media.saveBytes(contact.id, p.basename(photoPath), bytes);
            }
          }

          restored++;
        } catch (e) {
          // Continue with next contact
        }
      }

      return RestoreResult(
        success: true,
        restoredContacts: restored,
      );
    } catch (e) {
      try {
        await restoreBackup(previousBackupPath);
      } catch (_) {}
      return RestoreResult(
        success: false,
        errors: ['Error al restaurar respaldo: $e'],
      );
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
