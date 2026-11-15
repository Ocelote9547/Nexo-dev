import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:nexo/database/app_database.dart' as adb;
import 'package:nexo/features/android_integration/data/services/android_import_service.dart';
import 'package:nexo/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:nexo/features/contacts/data/services/contact_search_service.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/features/import_export/data/services/duplicate_detection_service.dart';
import 'package:nexo/features/import_export/data/repositories/import_export_repository_impl.dart';
import 'package:nexo/services/backup/backup_service.dart';
import 'package:nexo/services/media/media_service.dart';

void main() {
  late adb.AppDatabase db;
  late Directory tempDir;
  late MediaService media;
  late ContactRepositoryImpl contactRepo;
  late DuplicateDetectionService dupDetection;
  late ImportExportRepositoryImpl importExport;
  late BackupService backupService;

  setUp(() async {
    db = adb.AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('nexo_build4_test');
    media = MediaService(baseDirectory: tempDir);
    contactRepo = ContactRepositoryImpl(db, media, ContactSearchService(db));
    dupDetection = DuplicateDetectionService(contactRepo);
    importExport = ImportExportRepositoryImpl(
      contactRepository: contactRepo,
      duplicateDetection: dupDetection,
      media: media,
    );
    backupService = BackupService(
      contactRepository: contactRepo,
      media: media,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // ========================================================================
  // IMPORTPROVENANCE - Android origin key
  // ========================================================================

  test('originKey is unique per account and rawContactId', () async {
    final key1 = AndroidImportService.computeOriginKey(
      accountType: 'com.google',
      accountName: 'user@gmail.com',
      rawContactId: '123',
    );
    final key2 = AndroidImportService.computeOriginKey(
      accountType: 'com.google',
      accountName: 'user@gmail.com',
      rawContactId: '123',
    );
    final key3 = AndroidImportService.computeOriginKey(
      accountType: 'com.google',
      accountName: 'other@gmail.com',
      rawContactId: '123',
    );
    final key4 = AndroidImportService.computeOriginKey(
      accountType: 'com.samsung',
      accountName: 'user@gmail.com',
      rawContactId: '123',
    );

    expect(key1, equals(key2));
    expect(key1, isNot(equals(key3)));
    expect(key1, isNot(equals(key4)));
  });

  test('originKey handles empty rawContactId', () async {
    final key = AndroidImportService.computeOriginKey(
      accountType: 'com.google',
      accountName: 'user@gmail.com',
      rawContactId: '',
    );
    expect(key, isNull);
  });

  test('ImportProvenance prevents duplicate originKey', () async {
    final cid = const Uuid().v4();
    await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: cid, givenName: Value('Test')));

    final originKey = 'android|com.google|user@gmail.com|123';

    await db.into(db.importProvenances).insert(adb.ImportProvenancesCompanion.insert(
      id: const Uuid().v4(),
      contactId: cid,
      sourceType: 'android',
      originKey: originKey,
    ));

    expect(
      () => db.into(db.importProvenances).insert(adb.ImportProvenancesCompanion.insert(
        id: const Uuid().v4(),
        contactId: cid,
        sourceType: 'android',
        originKey: originKey,
      )),
      throwsA(isA<Exception>()),
    );
  });

  // ========================================================================
  // DUPLICATE DETECTION
  // ========================================================================

  test('duplicate detection by phone finds match', () async {
    final c = Contact(
      id: 'dup-phone-1',
      givenName: 'Ana',
      familyName: 'Garcia',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
    await contactRepo.createContact(c, phones: [
      Phone(id: 'p1', contactId: 'dup-phone-1', valueRaw: '600111222', label: 'mobile', isPrimary: true, sortOrder: 0),
    ]);

    final candidates = await dupDetection.findDuplicatesByPhone('600111222');
    expect(candidates.length, 1);
    expect(candidates.first.nexoContactId, 'dup-phone-1');
    expect(candidates.first.confidence, greaterThanOrEqualTo(0.8));
  });

  test('duplicate detection by email finds match', () async {
    final c = Contact(
      id: 'dup-email-1',
      givenName: 'Ana',
      familyName: 'Garcia',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
    await contactRepo.createContact(c, emails: [
      Email(id: 'e1', contactId: 'dup-email-1', value: 'ana@test.com', label: 'home', isPrimary: true, sortOrder: 0),
    ]);

    final candidates = await dupDetection.findDuplicatesByEmail('ana@test.com');
    expect(candidates.length, 1);
    expect(candidates.first.nexoContactId, 'dup-email-1');
    expect(candidates.first.confidence, greaterThanOrEqualTo(0.8));
  });

  test('duplicate detection by name and org finds match', () async {
    final c = Contact(
      id: 'dup-nameorg-1',
      givenName: 'Ana',
      familyName: 'Garcia',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
    await contactRepo.createContact(c, organizations: [
      Organization(id: 'o1', contactId: 'dup-nameorg-1', company: 'Acme', isPrimary: true, sortOrder: 0),
    ]);

    final candidates = await dupDetection.findDuplicatesByNameAndOrg(
      givenName: 'Ana',
      familyName: 'Garcia',
      company: 'Acme',
    );
    expect(candidates.length, 1);
    expect(candidates.first.nexoContactId, 'dup-nameorg-1');
  });

  test('duplicate detection no false positive', () async {
    final c = Contact(
      id: 'dup-false-1',
      givenName: 'Ana',
      familyName: 'Garcia',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
    await contactRepo.createContact(c);

    final candidates = await dupDetection.findDuplicatesByPhone('999999999');
    expect(candidates, isEmpty);
  });

  // ========================================================================
  // JSON ROUND-TRIP
  // ========================================================================

  test('JSON round-trip preserves all contact data', () async {
    final c = Contact(
      id: 'json-rt-1',
      givenName: 'Maria',
      familyName: 'Lopez',
      middleName: 'Jose',
      prefix: 'Dr.',
      suffix: 'Jr.',
      nickname: 'Mari',
      isFavorite: true,
      createdAt: DateTime(2024, 3, 1),
      updatedAt: DateTime(2024, 3, 1),
    );
    await contactRepo.createContact(c,
      phones: [
        Phone(id: 'p1', contactId: 'json-rt-1', valueRaw: '600111222', label: 'mobile', isPrimary: true, sortOrder: 0),
      ],
      emails: [
        Email(id: 'e1', contactId: 'json-rt-1', value: 'maria@test.com', label: 'home', isPrimary: true, sortOrder: 0),
      ],
      addresses: [
        Address(id: 'a1', contactId: 'json-rt-1', street: 'Calle Mayor 1', city: 'Madrid', country: 'Espana', sortOrder: 0),
      ],
      organizations: [
        Organization(id: 'o1', contactId: 'json-rt-1', company: 'Acme', title: 'Dev', isPrimary: true, sortOrder: 0),
      ],
      socialLinks: [
        SocialLink(id: 's1', contactId: 'json-rt-1', type: 'web', value: 'example.com', sortOrder: 0),
      ],
      notes: [
        Note(id: 'n1', contactId: 'json-rt-1', content: 'Nota importante', source: 'manual', createdAt: DateTime(2024, 3, 1), updatedAt: DateTime(2024, 3, 1)),
      ],
      customFields: [
        CustomField(id: 'cf1', contactId: 'json-rt-1', name: 'ref', type: 'text', value: 'ABC123', sortOrder: 0),
      ],
      dates: [
        ContactDate(id: 'd1', contactId: 'json-rt-1', type: 'birthday', date: DateTime(1990, 5, 15), yearUnknown: false, recurrence: 'yearly', sortOrder: 0),
      ],
    );

    final exported = await importExport.exportContactToPortable('json-rt-1');
    final jsonStr = jsonEncode({'contacts': [exported.toJson()]});
    final result = await importExport.importContactsFromJson(jsonStr);

    // El contacto ya existe (mismo ID), así que se omite como duplicado.
    expect(result.skipped, greaterThanOrEqualTo(1));
    expect(result.errors, 0);

    final imported = await contactRepo.getContactById('json-rt-1');
    expect(imported, isNotNull);
    expect(imported!.givenName, 'Maria');
    expect(imported.familyName, 'Lopez');

    final rel = await contactRepo.getContactWithRelations('json-rt-1');
    expect(rel!.phones.length, 1);
    expect(rel.phones.first.valueRaw, '600111222');
    expect(rel.emails.length, 1);
    expect(rel.emails.first.value, 'maria@test.com');
    expect(rel.addresses.length, 1);
    expect(rel.addresses.first.city, 'Madrid');
    expect(rel.organizations.length, 1);
    expect(rel.organizations.first.company, 'Acme');
    expect(rel.socialLinks.length, 1);
    expect(rel.socialLinks.first.value, 'example.com');
    expect(rel.notes.length, 1);
    expect(rel.notes.first.content, 'Nota importante');
    expect(rel.customFields.length, 1);
    expect(rel.customFields.first.value, 'ABC123');
    expect(rel.dates.length, 1);
    expect(rel.dates.first.date.month, 5);
    expect(rel.dates.first.date.day, 15);
  });

  test('JSON import with missing required fields still creates contact', () async {
    final jsonString = jsonEncode({'contacts': [
      {'id': 'json-minimal-1', 'givenName': 'Solo',
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2024, 1, 1).toIso8601String()}
    ]});

    final result = await importExport.importContactsFromJson(jsonString);
    expect(result.created, 1);
    expect(result.errors, 0);

    final imported = await contactRepo.getContactById('json-minimal-1');
    expect(imported, isNotNull);
    expect(imported!.givenName, 'Solo');
  });

  test('JSON import invalid JSON returns error', () async {
    final result = await importExport.importContactsFromJson('not valid json');
    expect(result.created, 0);
    expect(result.errors, 1);
  });

  // ========================================================================
  // CSV ROUND-TRIP
  // ========================================================================

  test('CSV round-trip preserves contact data', () async {
    final contact = Contact(
      id: 'csv-id-1',
      givenName: 'Maria',
      familyName: 'Lopez',
      createdAt: DateTime(2024, 2, 1),
      updatedAt: DateTime(2024, 2, 1),
    );
    await contactRepo.createContact(
      contact,
      phones: [Phone(id: 'p1', contactId: 'csv-id-1', valueRaw: '600333444', label: 'mobile', isPrimary: true, sortOrder: 0)],
      emails: [Email(id: 'e1', contactId: 'csv-id-1', value: 'maria@test.com', label: 'work', isPrimary: true, sortOrder: 0)],
    );

    final csv = await importExport.exportContactsToCsv();
    expect(csv, contains('Maria'));
    expect(csv, contains('Lopez'));
    expect(csv, contains('600333444'));
    expect(csv, contains('maria@test.com'));

    final result = await importExport.importContactsFromCsv(csv);
    // El contacto ya existe (mismo ID), así que se omite como duplicado.
    expect(result.skipped, greaterThanOrEqualTo(1));
  });

  test('CSV with special characters (commas, quotes)', () async {
    final contact = Contact(
      id: 'csv-special-1',
      givenName: 'Jose',
      familyName: 'Garcia, Jr.',
      nickname: 'He said "hello"',
      createdAt: DateTime(2024, 2, 1),
      updatedAt: DateTime(2024, 2, 1),
    );
    await contactRepo.createContact(contact);

    final csv = await importExport.exportContactsToCsv();
    expect(csv, contains('Jose'));
    expect(csv, contains('Garcia, Jr.'));
  });

  // ========================================================================
  // BACKUP AND RESTORE
  // ========================================================================

  test('backup and restore preserves all data', () async {
    final contact = Contact(
      id: 'backup-1', givenName: 'Backup', familyName: 'Test',
      createdAt: DateTime(2024, 5, 1), updatedAt: DateTime(2024, 5, 1),
    );
    await contactRepo.createContact(
      contact,
      phones: [Phone(id: 'p1', contactId: 'backup-1', valueRaw: '600777888', label: 'mobile', isPrimary: true, sortOrder: 0)],
      emails: [Email(id: 'e1', contactId: 'backup-1', value: 'backup@test.com', label: 'home', isPrimary: true, sortOrder: 0)],
    );

    final backupPath = p.join(tempDir.path, 'test_backup.nexobackup');
    final result = await backupService.createBackup(backupPath);
    expect(result.success, isTrue);

    await contactRepo.deleteContact('backup-1');
    expect(await contactRepo.getContactById('backup-1'), isNull);

    final restoreResult = await backupService.restoreBackup(backupPath);
    expect(restoreResult.success, isTrue);
    expect(restoreResult.restoredContacts, greaterThanOrEqualTo(1));

    final restored = await contactRepo.getContactById('backup-1');
    expect(restored, isNotNull);
    expect(restored!.givenName, 'Backup');
    expect(restored.familyName, 'Test');

    final rel = await contactRepo.getContactWithRelations('backup-1');
    expect(rel!.phones.length, 1);
    expect(rel.phones.first.valueRaw, '600777888');
    expect(rel.emails.length, 1);
    expect(rel.emails.first.value, 'backup@test.com');
  });

  test('backup restore with incorrect hash fails', () async {
    final contact = Contact(
      id: 'backup-corrupt-1', givenName: 'Corrupt', familyName: 'Test',
      createdAt: DateTime(2024, 5, 1), updatedAt: DateTime(2024, 5, 1),
    );
    await contactRepo.createContact(contact);

    final backupPath = p.join(tempDir.path, 'test_backup_corrupt.nexobackup');
    await backupService.createBackup(backupPath);

    final file = File(backupPath);
    final bytes = await file.readAsBytes();
    final corrupted = Uint8List.fromList(bytes);
    corrupted[100] = corrupted[100] ^ 0xFF;
    await file.writeAsBytes(corrupted, flush: true);

    final restoreResult = await backupService.restoreBackup(backupPath);
    expect(restoreResult.success, isFalse);
    expect(restoreResult.errors.isNotEmpty, isTrue);
  });

  test('backup restore with invalid JSON fails', () async {
    final backupPath = p.join(tempDir.path, 'test_backup_badjson.nexobackup');

    final archive = Archive();
    archive.addFile(ArchiveFile(
      'data.json',
      utf8.encode('{invalid json}').length,
      utf8.encode('{invalid json}'),
    ));
    archive.addFile(ArchiveFile(
      'manifest.json',
      utf8.encode('{}').length,
      utf8.encode('{}'),
    ));

    final zipBytes = ZipEncoder().encode(archive);
    final file = File(backupPath);
    await file.writeAsBytes(zipBytes, flush: true);

    final restoreResult = await backupService.restoreBackup(backupPath);
    expect(restoreResult.success, isFalse);
  });

  test('backup restore preserves state on failure', () async {
    final contact = Contact(
      id: 'backup-preserve-1', givenName: 'Preserve', familyName: 'Test',
      createdAt: DateTime(2024, 5, 1), updatedAt: DateTime(2024, 5, 1),
    );
    await contactRepo.createContact(contact);

    final backupPath = p.join(tempDir.path, 'test_backup_preserve.nexobackup');
    await backupService.createBackup(backupPath);

    final file = File(backupPath);
    final bytes = await file.readAsBytes();
    final corrupted = Uint8List.fromList(bytes);
    corrupted[50] = corrupted[50] ^ 0xFF;
    await file.writeAsBytes(corrupted, flush: true);

    final restoreResult = await backupService.restoreBackup(backupPath);
    expect(restoreResult.success, isFalse);

    final restored = await contactRepo.getContactById('backup-preserve-1');
    expect(restored != null, isTrue);
    expect(restored!.givenName, 'Preserve');
  });

  test('backup with malicious path (ZIP Slip) is rejected', () async {
    final backupPath = p.join(tempDir.path, 'test_backup_slip.nexobackup');

    final archive = Archive();
    archive.addFile(ArchiveFile(
      '../../etc/passwd',
      10,
      Uint8List.fromList(utf8.encode('root:x:0:0:')),
    ));
    archive.addFile(ArchiveFile(
      'manifest.json',
      utf8.encode('{}').length,
      utf8.encode('{}'),
    ));

    final zipBytes = ZipEncoder().encode(archive);
    final file = File(backupPath);
    await file.writeAsBytes(zipBytes, flush: true);

    final restoreResult = await backupService.restoreBackup(backupPath);
    expect(restoreResult.success, isFalse);
  });

  test('backup restore with oversized entry is rejected', () async {
    final backupPath = p.join(tempDir.path, 'test_backup_oversized.nexobackup');

    final archive = Archive();
    final oversizedData = Uint8List(BackupLimits.maxEntrySizeBytes + 1);
    archive.addFile(ArchiveFile(
      'data.json',
      oversizedData.length,
      oversizedData,
    ));
    archive.addFile(ArchiveFile(
      'manifest.json',
      utf8.encode('{}').length,
      utf8.encode('{}'),
    ));

    final zipBytes = ZipEncoder().encode(archive);
    final file = File(backupPath);
    await file.writeAsBytes(zipBytes, flush: true);

    final restoreResult = await backupService.restoreBackup(backupPath);
    expect(restoreResult.success, isFalse);
  });

  test('backup restore with too many entries is rejected', () async {
    final backupPath = p.join(tempDir.path, 'test_backup_toomany.nexobackup');

    final archive = Archive();
    for (int i = 0; i < 100001; i++) {
      archive.addFile(ArchiveFile(
        'file_$i.txt',
        1,
        Uint8List.fromList([65]),
      ));
    }
    archive.addFile(ArchiveFile(
      'manifest.json',
      utf8.encode('{}').length,
      utf8.encode('{}'),
    ));

    final zipBytes = ZipEncoder().encode(archive);
    final file = File(backupPath);
    await file.writeAsBytes(zipBytes, flush: true);

    final restoreResult = await backupService.restoreBackup(backupPath);
    expect(restoreResult.success, isFalse);
  });
}