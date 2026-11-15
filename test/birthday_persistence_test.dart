import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/database/app_database.dart' as adb;
import 'package:nexo/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:nexo/features/contacts/data/services/contact_search_service.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/services/media/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexo_birthday_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('Birthday persistence', () {
    test('manually added birthday should persist after update', () async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      final contactRepo = ContactRepositoryImpl(db, MediaService(baseDirectory: tempDir), ContactSearchService(db));

      // Create a contact
      final contact = await contactRepo.createContact(
        Contact(givenName: 'Juan', familyName: 'Pérez'),
      );

      // Add a birthday date
      final birthday = ContactDate(
        contactId: contact.id,
        type: 'birthday',
        date: DateTime(1985, 5, 15),
        yearUnknown: false,
      );

      // Update contact with the date
      await contactRepo.updateContact(
        contact.copyWith(),
        dates: [birthday],
      );

      // Read back and verify
      final rel = await contactRepo.getContactWithRelations(contact.id);
      expect(rel, isNotNull);
      expect(rel!.dates.length, 1);
      expect(rel.dates[0].type, 'birthday');
      expect(rel.dates[0].date, DateTime(1985, 5, 15));
      expect(rel.dates[0].yearUnknown, isFalse);

      await db.close();
    });

    test('contact without name should be creatable', () async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      final contactRepo = ContactRepositoryImpl(db, MediaService(baseDirectory: tempDir), ContactSearchService(db));

      // Create a contact without name (only email)
      final contact = await contactRepo.createContact(
        Contact(givenName: null, familyName: null),
        emails: [Email(contactId: 'x', value: 'test@example.com')],
      );

      expect(contact.id, isNotEmpty);

      final rel = await contactRepo.getContactWithRelations(contact.id);
      expect(rel, isNotNull);
      expect(rel!.contact.displayName, 'Contacto sin nombre');

      await db.close();
    });

    test('multiple dates should persist', () async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      final contactRepo = ContactRepositoryImpl(db, MediaService(baseDirectory: tempDir), ContactSearchService(db));

      final contact = await contactRepo.createContact(
        Contact(givenName: 'Test', familyName: 'User'),
      );

      await contactRepo.updateContact(
        contact.copyWith(),
        dates: [
          ContactDate(contactId: contact.id, type: 'birthday', date: DateTime(1990, 3, 10)),
          ContactDate(contactId: contact.id, type: 'anniversary', date: DateTime(2010, 7, 20)),
        ],
      );

      final rel = await contactRepo.getContactWithRelations(contact.id);
      expect(rel!.dates.length, 2);

      await db.close();
    });

    test('partial birthday (no year) should persist', () async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      final contactRepo = ContactRepositoryImpl(db, MediaService(baseDirectory: tempDir), ContactSearchService(db));

      final contact = await contactRepo.createContact(
        Contact(givenName: 'Ana', familyName: 'García'),
      );

      await contactRepo.updateContact(
        contact.copyWith(),
        dates: [
          ContactDate(contactId: contact.id, type: 'birthday', date: DateTime(2000, 2, 25), yearUnknown: true),
        ],
      );

      final rel = await contactRepo.getContactWithRelations(contact.id);
      expect(rel!.dates.length, 1);
      expect(rel.dates[0].yearUnknown, isTrue);
      expect(rel.dates[0].date, DateTime(2000, 2, 25));

      await db.close();
    });
  });
}
