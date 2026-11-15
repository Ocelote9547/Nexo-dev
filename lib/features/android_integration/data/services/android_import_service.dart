import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/android_contact.dart';
import '../../../import_export/data/services/duplicate_detection_service.dart';
import '../../../import_export/domain/entities/import_export.dart';
import '../../../import_export/domain/repositories/import_export_repository.dart';
import '../../../../database/app_database.dart' as db_lib;

/// Result of importing a batch of Android contacts.
class AndroidBatchImportResult {
  final int total;
  final int created;
  final int skipped;
  final int merged;
  final int replaced;
  final int errors;
  final List<AndroidImportResult> perContact;
  final List<String> warnings;
  final List<String> errorMessages;

  AndroidBatchImportResult({
    required this.total,
    required this.created,
    required this.skipped,
    required this.merged,
    required this.replaced,
    required this.errors,
    this.perContact = const [],
    this.warnings = const [],
    this.errorMessages = const [],
  });

  bool get allSucceeded => errors == 0 && total > 0;
}

/// Service that orchestrates the import of Android contacts into NEXO.
///
/// This service:
/// 1. Reads contacts from Android Contacts Provider via [AndroidContactsRepository]
/// 2. Maps them to [PortableContact] for NEXO's import pipeline
/// 3. Detects duplicates using [DuplicateDetectionService]
/// 4. Imports with appropriate resolution
/// 5. Creates [ImportProvenance] records with stable `originKey`
///
/// All operations are explicit and user-initiated. No automatic
/// synchronization or background operations are performed.
class AndroidImportService {
  final ImportExportRepository _importExportRepository;
  final DuplicateDetectionService _duplicateDetection;
  final db_lib.AppDatabase _db;

  AndroidImportService({
    required this._importExportRepository,
    required this._duplicateDetection,
    required this._db,
  });

  /// Computes a stable origin key for an Android RawContact.
  ///
  /// Returns null if no reliable individual identifier is available.
  ///
  /// Priority:
  /// 1. rawContactId (local, but identifies a specific raw contact)
  /// 2. sourceId (stable server UUID, when available)
  ///
  /// If neither is available, returns null to indicate the contact cannot be
  /// reliably identified for provenance tracking.
  static String? computeOriginKey({
    required String accountType,
    required String accountName,
    required String rawContactId,
    String? sourceId,
  }) {
    if (rawContactId.isNotEmpty) {
      return 'android|$accountType|$accountName|$rawContactId';
    }
    if (sourceId != null && sourceId.isNotEmpty) {
      return 'android|$accountType|$accountName|src:$sourceId';
    }
    return null;
  }

  /// Maps an [AndroidContact] to a [PortableContact].
  PortableContact mapToPortableContact(AndroidContact android) {
    final phones = <PortablePhone>[];
    if (android.phone != null && android.phone!.isNotEmpty) {
      phones.add(PortablePhone(
        id: '',
        valueRaw: android.phone!,
        label: 'mobile',
        isPrimary: true,
        sortOrder: 0,
      ));
    }

    final emails = <PortableEmail>[];
    if (android.email != null && android.email!.isNotEmpty) {
      emails.add(PortableEmail(
        id: '',
        value: android.email!,
        label: 'home',
        isPrimary: true,
        sortOrder: 0,
      ));
    }

    final organizations = <PortableOrganization>[];
    if (android.company != null || android.title != null) {
      organizations.add(PortableOrganization(
        id: '',
        company: android.company,
        title: android.title,
        isPrimary: true,
        sortOrder: 0,
      ));
    }

    return PortableContact(
      id: '',
      givenName: android.givenName,
      middleName: android.middleName,
      familyName: android.familyName,
      prefix: android.prefix,
      suffix: android.suffix,
      phoneticGiven: android.phoneticGiven,
      phoneticFamily: android.phoneticFamily,
      nickname: android.nickname,
      isFavorite: android.isStarred,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      phones: phones,
      emails: emails,
      organizations: organizations,
    );
  }

  /// Creates ImportProvenance records for a contact imported from Android.
  /// Returns true if provenance was created, false if the contact could not be
  /// reliably identified.
  Future<bool> createImportProvenance({
    required String nexoContactId,
    required AndroidRawContact rawContact,
  }) async {
    final originKey = computeOriginKey(
      accountType: rawContact.accountType,
      accountName: rawContact.accountName,
      rawContactId: rawContact.id,
      sourceId: rawContact.sourceId,
    );

    if (originKey == null) {
      return false;
    }

    final provenance = db_lib.ImportProvenancesCompanion.insert(
      id: const Uuid().v4(),
      contactId: nexoContactId,
      sourceType: 'android',
      originKey: originKey,
      accountType: Value(rawContact.accountType),
      accountName: Value(rawContact.accountName),
      rawContactId: Value(rawContact.id),
    );

    await _db.into(_db.importProvenances).insert(provenance);
    return true;
  }

  /// Imports a single Android contact into NEXO.
  Future<AndroidImportResult> importSingleContact({
    required AndroidContact androidContact,
    DuplicateResolution? resolution,
  }) async {
    try {
      final pc = mapToPortableContact(androidContact);
      final nexoId = await _importExportRepository.importPortableContact(
        pc,
        resolution: resolution,
      );

      // Create ImportProvenance records for each RawContact
      for (final rc in androidContact.rawContacts) {
        await createImportProvenance(
          nexoContactId: nexoId,
          rawContact: rc,
        );
      }

      // If no raw contacts, create one from the aggregated contact ID
      if (androidContact.rawContacts.isEmpty) {
        await createImportProvenance(
          nexoContactId: nexoId,
          rawContact: AndroidRawContact(
            id: androidContact.id,
            contactId: androidContact.id,
            accountName: '',
            accountType: 'com.android.contacts',
          ),
        );
      }

      return AndroidImportResult(
        androidContactId: androidContact.id,
        nexoContactId: nexoId,
        created: true,
      );
    } catch (e) {
      return AndroidImportResult(
        androidContactId: androidContact.id,
        errors: ['Failed to import: $e'],
      );
    }
  }

  /// Imports multiple Android contacts into NEXO.
  Future<AndroidBatchImportResult> importContacts({
    required List<AndroidContact> contacts,
    DuplicateResolution? defaultResolution,
  }) async {
    final results = <AndroidImportResult>[];
    int created = 0;
    int skipped = 0;
    int merged = 0;
    int replaced = 0;
    int errors = 0;
    final warnings = <String>[];
    final errorMessages = <String>[];

    for (final contact in contacts) {
      final result = await importSingleContact(
        androidContact: contact,
        resolution: defaultResolution,
      );
      results.add(result);

      if (result.created) created++;
      if (result.skipped) skipped++;
      if (result.merged) merged++;
      if (result.replaced) replaced++;
      if (!result.success) {
        errors++;
        errorMessages.addAll(result.errors);
      }
      warnings.addAll(result.warnings);
    }

    return AndroidBatchImportResult(
      total: contacts.length,
      created: created,
      skipped: skipped,
      merged: merged,
      replaced: replaced,
      errors: errors,
      perContact: results,
      warnings: warnings,
      errorMessages: errorMessages,
    );
  }

  /// Finds potential duplicates for an Android contact.
  Future<List<DuplicateCandidate>> findDuplicatesForAndroidContact(
    AndroidContact androidContact,
  ) async {
    final pc = mapToPortableContact(androidContact);
    return _duplicateDetection.findDuplicates(pc);
  }
}
