import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/database/app_database.dart' as adb;
import 'package:nexo/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:nexo/features/contacts/data/services/contact_search_service.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/features/import_export/data/repositories/import_export_repository_impl.dart';
import 'package:nexo/features/import_export/data/services/duplicate_detection_service.dart';
import 'package:nexo/features/import_export/data/services/quoted_printable_decoder.dart';
import 'package:nexo/features/import_export/domain/entities/import_export.dart';
import 'package:nexo/services/media/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexo_media_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('QuotedPrintableDecoder', () {
    test('decodes UTF-8 quoted-printable sequences correctly', () {
      // é = 0xC3 0xA9, í = 0xC3 0xAD, ñ = 0xC3 0xB1
      expect(QuotedPrintableDecoder.decode('Jos=C3=A9'), 'José');
      expect(QuotedPrintableDecoder.decode('Mar=C3=ADa'), 'María');
      expect(QuotedPrintableDecoder.decode('Mu=C3=B1oz'), 'Muñoz');
    });

    test('decodes mixed ASCII and quoted-printable', () {
      // José García: é=C3=A9, í=C3=AD
      expect(
        QuotedPrintableDecoder.decode('Jos=C3=A9 Garc=C3=ADa'),
        'José García',
      );
    });

    test('does not decode invalid =HH sequences', () {
      expect(QuotedPrintableDecoder.decode('Jos=ZZ'), 'Jos=ZZ');
    });

    test('removes soft line breaks (=CRLF)', () {
      expect(
        QuotedPrintableDecoder.decode('Jos=\r\n=C3=A9'),
        'José',
      );
    });

    test('leaves plain ASCII text unchanged', () {
      expect(QuotedPrintableDecoder.decode('Hello World'), 'Hello World');
    });

    test('decodeVCardValue returns correct UTF-8 without double-decoding', () {
      expect(decodeVCardValue('Jos=C3=A9'), 'José');
      expect(decodeVCardValue('Jos=C3=A9 Garc=C3=ADa'), 'José García');
    });
  });

  group('ImportExportRepository encoding', () {
    late adb.AppDatabase db;
    late ContactRepositoryImpl contactRepo;
    late DuplicateDetectionService duplicateDetection;
    late ImportExportRepositoryImpl importRepo;

    setUp(() async {
      db = adb.AppDatabase(NativeDatabase.memory());
      final search = ContactSearchService(db);
      contactRepo = ContactRepositoryImpl(db, MediaService(baseDirectory: tempDir), search);
      duplicateDetection = DuplicateDetectionService(contactRepo);
      importRepo = ImportExportRepositoryImpl(
        contactRepository: contactRepo,
        duplicateDetection: duplicateDetection,
        media: MediaService(baseDirectory: tempDir),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('imports vCard with quoted-printable UTF-8 names', () async {
      // Google Contacts vCard 2.1 uses ENCODING=QUOTED-PRINTABLE with CHARSET=UTF-8
      // é = C3=A9, í = C3=AD, Á = C3=81
      final vcf =
          'BEGIN:VCARD\nVERSION:2.1\n'
          'FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=C3=A9lena Garc=C3=ADa\n'
          'N;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Garc=C3=ADa;=C3=81lena;;;\n'
          'TEL;TYPE=CELL:+34 612 345 678\n'
          'EMAIL;TYPE=INTERNET:elena.garcia@example.com\n'
          'END:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);

      // ignore: avoid_print
      print('vCard QP import: created=${result.created} errors=${result.errors} '
          'messages=${result.errorMessages}');

      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, 'Álena');
      expect(contacts[0].familyName, 'García');
      expect(contacts[0].displayName, 'Álena García');
    });

    test('imports vCard with plain UTF-8 names (no QP encoding)', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:María Núñez\n'
          'N:Núñez;María;;;\nTEL;TYPE=mobile:+34612345679\n'
          'EMAIL;TYPE=home:maria.nunez@example.com\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);

      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts[0].givenName, 'María');
      expect(contacts[0].familyName, 'Núñez');
    });

    test('imports vCard with multiple Spanish names', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Iñaki Álvarez\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:Zoë Peña\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);

      expect(result.errors, 0);
      expect(result.created, 2);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 2);
      final names = contacts.map((c) => c.displayName).toSet();
      expect(names, contains('Iñaki Álvarez'));
      expect(names, contains('Zoë Peña'));
    });

    test('imports CSV with UTF-8 BOM and Spanish characters', () async {
      const bom = '\uFEFF';
      final csv =
          '${bom}id,givenName,middleName,familyName,prefix,suffix,nickname,'
          'isFavorite,createdAt,updatedAt\n'
          '1,José,,García,,,0,2024-01-01T00:00:00,2024-01-01T00:00:00\n';

      final result = await importRepo.importContactsFromCsv(csv);

      // ignore: avoid_print
      print('CSV BOM import: created=${result.created} errors=${result.errors} '
          'messages=${result.errorMessages} failed=${result.failedRecords.length}');

      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, 'José');
      expect(contacts[0].familyName, 'García');
    });

    test('imports CSV without BOM with Spanish characters', () async {
      final csv =
          'id,givenName,middleName,familyName,prefix,suffix,nickname,'
          'isFavorite,createdAt,updatedAt\n'
          '1,María,,Núñez,,,0,2024-01-01T00:00:00,2024-01-01T00:00:00\n';

      final result = await importRepo.importContactsFromCsv(csv);

      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, 'María');
      expect(contacts[0].familyName, 'Núñez');
    });

    test('export to vCard preserves UTF-8 names', () async {
      await contactRepo.createContact(
        Contact(givenName: 'José', familyName: 'García'),
        phones: [Phone(contactId: 'x', valueRaw: '+34612345678')],
        emails: [Email(contactId: 'x', value: 'jose.garcia@example.com')],
      );
      await contactRepo.createContact(
        Contact(givenName: 'María', familyName: 'Núñez'),
        phones: [Phone(contactId: 'y', valueRaw: '+34612345679')],
        emails: [Email(contactId: 'y', value: 'maria.nunez@example.com')],
      );

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 2);

      final vcf = await importRepo.exportAllContactsToVCard();

      expect(vcf, contains('Jos=C3=A9'));
      expect(vcf, contains('Garc=C3=ADa'));
      expect(vcf, contains('Mar=C3=ADa'));
      expect(vcf, contains('N=C3=BA=C3=B1ez'));
    });

    test('export to CSV preserves UTF-8 names', () async {
      await contactRepo.createContact(
        Contact(givenName: 'José', familyName: 'García'),
      );
      await contactRepo.createContact(
        Contact(givenName: 'Iñaki', familyName: 'Álvarez'),
      );

      final csv = await importRepo.exportContactsToCsv();

      expect(csv, contains('José'));
      expect(csv, contains('García'));
      expect(csv, contains('Iñaki'));
      expect(csv, contains('Álvarez'));
    });

    test('re-import round-trip preserves Spanish names', () async {
      await contactRepo.createContact(
        Contact(givenName: 'Zoë', familyName: 'Peña'),
        emails: [Email(contactId: 'z', value: 'zoe.pena@example.com')],
      );

      final vcf = await importRepo.exportAllContactsToVCard();

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);

      final contacts = await contactRepo.getAllContacts();
      // Duplicate is skipped (resolution defaults to null), so count stays at 1
      expect(contacts.length, 1);
      expect(contacts[0].givenName, 'Zoë');
      expect(contacts[0].familyName, 'Peña');
    });

    test('import reports detailed errors for failed records', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Valid Contact\n'
          'TEL;TYPE=mobile:+1234567890\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);

      expect(result.created, 1);
      expect(result.errors, 0);
      expect(result.failedRecords.isEmpty, isTrue);
      expect(result.errorMessages.isEmpty, isTrue);
    });

    test('countVcfCards detects correct number of BEGIN:VCARD cards', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Contact 1\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:Contact 2\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:Contact 3\nEND:VCARD';

      final count = importRepo.countVcfCards(vcf);
      expect(count, 3);
    });

    test('countVcfCards returns 0 for empty content', () async {
      final count = importRepo.countVcfCards('');
      expect(count, 0);
    });

    test('countVcfCards does not count phones/emails as cards', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Un Contacto\n'
          'TEL;TYPE=mobile:+34 612 345 678\n'
          'TEL;TYPE=work:+34 698 765 432\n'
          'EMAIL;TYPE=home:test@example.com\n'
          'END:VCARD';

      final count = importRepo.countVcfCards(vcf);
      expect(count, 1); // One card, not three (one per phone/email)
    });

    test('import progress totals add up: created + skipped + errors = processed', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Contact 1\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:Contact 2\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);

      expect(result.total, 2);
      expect(result.processed, 2);
      expect(result.created, 2);
      expect(result.errors, 0);
      // Imported + skipped + failed = processed
      expect(result.created + result.skipped + result.errors, result.processed);
    });

    test('import with multiple cards processes each exactly once', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana García\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:José López\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:María Ruiz\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);

      expect(result.total, 3);
      expect(result.processed, 3);
      expect(result.created, 3);
      expect(result.errors, 0);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 3);
    });

    test('import vCard with Base64 JPEG photo creates local file', () async {
      // Minimal valid JPEG: SOI + APP0 + EOI
      final jpegBytes = [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
        0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
      ];
      final photoBase64 = base64Encode(jpegBytes);

      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Contact with Photo\n'
          'PHOTO;TYPE=JPEG:$photoBase64\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);

      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, 'Contact with Photo');
    });

    test('import vCard with invalid Base64 photo does not fail contact', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Contact with Bad Photo\n'
          'PHOTO;TYPE=JPEG:!!not-base64!!\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);

      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, 'Contact with Bad Photo');
    });

    test('import vCard birthday partial --MM-DD shows no year', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Partial Birthday\n'
          'BDAY:--02-25\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);

      final rel = await contactRepo.getContactWithRelations(contacts[0].id);
      expect(rel!.dates.length, 1);
      expect(rel.dates[0].type, 'birthday');
      expect(rel.dates[0].yearUnknown, isTrue);
      expect(rel.dates[0].displayDate, '25/2');
    });

    test('import vCard birthday complete YYYY-MM-DD shows year', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Full Birthday\n'
          'BDAY:2009-01-06\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);

      final rel = await contactRepo.getContactWithRelations(contacts[0].id);
      expect(rel!.dates.length, 1);
      expect(rel.dates[0].yearUnknown, isFalse);
      expect(rel.dates[0].displayDate, '6/1/2009');
    });

    test('export vCard preserves partial birthday --MM-DD format', () async {
      await contactRepo.createContact(
        Contact(givenName: 'Partial', familyName: 'Birthday'),
        dates: [ContactDate(contactId: 'x', type: 'birthday', date: DateTime(2000, 2, 25), yearUnknown: true)],
      );

      final vcf = await importRepo.exportAllContactsToVCard();
      expect(vcf, contains('BDAY:--02-25'));
    });

    test('export vCard preserves complete birthday YYYY-MM-DD format', () async {
      await contactRepo.createContact(
        Contact(givenName: 'Full', familyName: 'Birthday'),
        dates: [ContactDate(contactId: 'x', type: 'birthday', date: DateTime(2009, 1, 6), yearUnknown: false)],
      );

      final vcf = await importRepo.exportAllContactsToVCard();
      expect(vcf, contains('BDAY:2009-01-06'));
    });

    test('export then import preserves birthday without year', () async {
      await contactRepo.createContact(
        Contact(givenName: 'Partial', familyName: 'Birthday'),
        dates: [ContactDate(contactId: 'x', type: 'birthday', date: DateTime(2000, 2, 25), yearUnknown: true)],
      );

      final vcf = await importRepo.exportAllContactsToVCard();
      expect(vcf, contains('BDAY:--02-25'));

      final result = await importRepo.importContactsFromVCard(
        vcf,
        resolution: DuplicateResolution.createNew,
      );
      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 2); // original + re-imported

      final partialContacts = contacts
          .where((c) => c.familyName == 'Birthday')
          .toList();
      expect(partialContacts.length, 2);

      for (final c in partialContacts) {
        final rel = await contactRepo.getContactWithRelations(c.id);
        final bday = rel!.dates.firstWhere((d) => d.type == 'birthday');
        expect(bday.yearUnknown, isTrue);
        expect(bday.displayDate, '25/2');
      }
    });

    test('same batch: two identical vCard cards, both are created (name-only match is weak)', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana García\nN:García;;Ana;;\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana García\nN:García;;Ana;;\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 2);
      expect(result.skipped, 0);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 2);
    });

    test('same batch: same name different surname are NOT duplicates', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana García\nN:García;;Ana;;\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana López\nN:López;;Ana;;\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 2);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 2);
    });

    test('same batch: same surname different name are NOT duplicates', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana García\nN:García;;Ana;;\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:María García\nN:García;;María;;\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 2);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 2);
    });

    test('same batch: contacts with incomplete names are created', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:García\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:\nEMAIL;TYPE=INTERNET:test@example.com\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 3);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 3);
    });

    test('import vCard with email-only contact creates contact', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:\n'
          'EMAIL;TYPE=INTERNET:contacto001@example.invalid\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);
      expect(result.skipped, 0);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, isNull);
      expect(contacts[0].familyName, isNull);
      final rel = await contactRepo.getContactWithRelations(contacts[0].id);
            expect(rel!.emails.length, 1);
      expect(rel.emails[0].value, 'contacto001@example.invalid');
    });

    test('re-import email-only contact is skipped as duplicate', () async {
      // First import
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:\n'
          'EMAIL;TYPE=INTERNET:contacto001@example.invalid\nEND:VCARD';

      final result1 = await importRepo.importContactsFromVCard(vcf);
      expect(result1.created, 1);
      expect(result1.skipped, 0);

      // Second import - same email should be detected as duplicate
      final result2 = await importRepo.importContactsFromVCard(vcf);
      expect(result2.errors, 0);
      expect(result2.created, 0);
      expect(result2.skipped, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
    });

    test('import email-only cards from anonymized VCF', () async {
      final vcfContent = File('local_test_data/contacts_272_anonymized.vcf')
          .readAsStringSync();
      final result = await importRepo.importContactsFromVCard(vcfContent);

      expect(result.created, 272);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test('re-import full anonymized VCF: all 272 skipped, 0 created', () async {
      final vcfContent = File('local_test_data/contacts_272_anonymized.vcf')
          .readAsStringSync();

      // First import
      final result1 = await importRepo.importContactsFromVCard(vcfContent);
      expect(result1.created, 272);
      expect(result1.skipped, 0);
      expect(result1.errors, 0);

      final count1 = await contactRepo.getAllContacts();
      expect(count1.length, 272);

      // Second import - all should be skipped as duplicates
      final result2 = await importRepo.importContactsFromVCard(vcfContent);
      expect(result2.created, 0);
      expect(result2.skipped, 272);
      expect(result2.errors, 0);

      final count2 = await contactRepo.getAllContacts();
      expect(count2.length, 272);
    });

    test('two contacts sharing phone are NOT duplicates', () async {
      await contactRepo.createContact(
        Contact(givenName: 'Ana', familyName: 'García'),
        phones: [Phone(contactId: 'a', valueRaw: '+34600111222', label: 'mobile')],
      );
      await contactRepo.createContact(
        Contact(givenName: 'María', familyName: 'López'),
        phones: [Phone(contactId: 'b', valueRaw: '+34600111222', label: 'mobile')],
      );

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 2);

      // Import a third contact with same phone - should be created (phone-only = 0.6 < 0.8)
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Carlos Ruiz\n'
          'TEL;CELL:+34600111222\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);
      expect(result.skipped, 0);

      final contacts2 = await contactRepo.getAllContacts();
      expect(contacts2.length, 3);
    });

    test('two contacts sharing email are NOT merged automatically', () async {
      await contactRepo.createContact(
        Contact(givenName: 'Ana', familyName: 'García'),
        emails: [Email(contactId: 'a', value: 'shared@example.com')],
      );
      await contactRepo.createContact(
        Contact(givenName: 'María', familyName: 'López'),
        emails: [Email(contactId: 'b', value: 'shared@example.com')],
      );

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 2);

      // Import a third contact with same email - email-only match = 0.8 (strong match)
      // But since two contacts share the email, only the first match found is skipped
      // The other contact remains. No new contact should be created since we found
      // a strong match.
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Carlos Ruiz\n'
          'EMAIL;TYPE=INTERNET:shared@example.com\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 0);
      expect(result.skipped, 1);

      final contacts2 = await contactRepo.getAllContacts();
      // Still 2 contacts - no new contact created, no existing contact removed
      expect(contacts2.length, 2);
    });

    test('email with different case and spaces is matched', () async {
      await contactRepo.createContact(
        Contact(givenName: 'Ana', familyName: 'García'),
        emails: [Email(contactId: 'a', value: 'ANA.GARCIA@Example.COM')],
      );

      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana García\n'
          'EMAIL;TYPE=INTERNET:  ana.garcia@example.com  \nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 0);
      expect(result.skipped, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
    });

    test('contact without name phone or email is created', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, isNull);
      expect(contacts[0].familyName, isNull);
      final rel = await contactRepo.getContactWithRelations(contacts[0].id);
      expect(rel!.phones.isEmpty, isTrue);
      expect(rel.emails.isEmpty, isTrue);
    });

    test('contact with email-only gets photo imported', () async {
      // First create contact with email only
      await contactRepo.createContact(
        Contact(givenName: 'Juan', familyName: 'Pérez'),
        emails: [Email(contactId: 'x', value: 'juan.perez@example.invalid')],
      );

      // Then import vCard with same email and a photo
      final jpegBytes = [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
        0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
      ];
      final photoBase64 = base64Encode(jpegBytes);

      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Juan Pérez\n'
          'EMAIL;TYPE=INTERNET:juan.perez@example.invalid\n'
          'PHOTO;ENCODING=BASE64;TYPE=JPEG:$photoBase64\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 0);
      expect(result.skipped, 1);

      // Contact should now have photo
      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      final rel = await contactRepo.getContactWithRelations(contacts[0].id);
      expect(rel!.contact.photoPath, isNotNull);
      expect(rel.contact.photoPath, isNotEmpty);
    });
  });
    late adb.AppDatabase db;
    late ContactRepositoryImpl contactRepo;
    late DuplicateDetectionService duplicateDetection;
    late ImportExportRepositoryImpl importRepo;

    setUp(() async {
      db = adb.AppDatabase(NativeDatabase.memory());
      final search = ContactSearchService(db);
      contactRepo = ContactRepositoryImpl(db, MediaService(baseDirectory: tempDir), search);
      duplicateDetection = DuplicateDetectionService(contactRepo);
      importRepo = ImportExportRepositoryImpl(
        contactRepository: contactRepo,
        duplicateDetection: duplicateDetection,
        media: MediaService(baseDirectory: tempDir),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('FN without N does not set nickname', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:José García\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      // When FN is present without N, the full FN goes into givenName
      expect(contacts[0].givenName, 'José García');
      expect(contacts[0].familyName, isNull);
      expect(contacts[0].nickname, isNull);
    });

    test('NICKNAME field is imported as nickname, not FN', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:José García\n'
          'NICKNAME:Pepe\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, 'José García');
      expect(contacts[0].familyName, isNull);
      expect(contacts[0].nickname, 'Pepe');
    });

    test('contact without name but with email is importable', () async {
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:\n'
          'EMAIL;TYPE=INTERNET:test@example.com\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, isNull);
      expect(contacts[0].familyName, isNull);
      expect(contacts[0].displayName, 'Contacto sin nombre');
      final rel = await contactRepo.getContactWithRelations(contacts[0].id);
      expect(rel!.emails.length, 1);
      expect(rel.emails[0].value, 'test@example.com');
    });

    test('very long givenName and familyName are preserved', () async {
      final longName = 'A' * 200;
      final longFamily = 'B' * 200;
      // When FN contains both names without N, the full string goes into givenName
      final fullName = '$longName $longFamily';
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:$fullName\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, fullName);
    });

    test('name longer than 100 chars is preserved', () async {
      final longName = 'A' * 150;
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:$longName\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      expect(contacts[0].givenName, longName);
    });

    test('phone-only match is NOT a strong duplicate (same phone, different name)', () async {
      // Primer contacto con teléfono
      final c1 = Contact(givenName: 'Ana', familyName: 'García');
      await contactRepo.createContact(
        c1,
        phones: [Phone(contactId: c1.id, valueRaw: '+34600111222', label: 'mobile')],
      );

      // Segundo contacto con mismo teléfono pero nombre diferente
      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:María López\n'
          'TEL;CELL:+34600111222\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      // Teléfono solo no es coincidencia fuerte: se crea nuevo contacto
      expect(result.created, 1);
      expect(result.skipped, 0);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 2);
    });

    test('email-only match IS a strong duplicate (same email is skipped)', () async {
      final c1 = Contact(givenName: 'Ana', familyName: 'García');
      await contactRepo.createContact(
        c1,
        emails: [Email(contactId: c1.id, value: 'ana@example.com', label: 'home')],
      );

      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana García\n'
          'EMAIL;TYPE=INTERNET:ana@example.com\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      // Email solo sí es coincidencia fuerte: se omite
      expect(result.created, 0);
      expect(result.skipped, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
    });

    test('phone + name match IS a strong duplicate', () async {
      final c1 = Contact(givenName: 'Ana', familyName: 'García');
      await contactRepo.createContact(
        c1,
        phones: [Phone(contactId: c1.id, valueRaw: '+34600111222', label: 'mobile')],
      );

      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana García\n'
          'TEL;CELL:+34600111222\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      // Teléfono + nombre = coincidencia fuerte: se omite
      expect(result.created, 0);
      expect(result.skipped, 1);

      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
    });

    test('photo enrichment: existing contact without photo gets photo from VCF', () async {
      // Contacto existente sin foto
      final c1 = Contact(givenName: 'Ana', familyName: 'García');
      await contactRepo.createContact(
        c1,
        phones: [Phone(contactId: c1.id, valueRaw: '+34600111222', label: 'mobile')],
      );

      // VCF con mismo contacto pero con foto
      final jpegBytes = [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
        0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
      ];
      final photoBase64 = base64Encode(jpegBytes);

      final vcf =
          'BEGIN:VCARD\nVERSION:3.0\nFN:Ana García\n'
          'TEL;CELL:+34600111222\n'
          'PHOTO;ENCODING=BASE64;TYPE=JPEG:$photoBase64\nEND:VCARD';

      final result = await importRepo.importContactsFromVCard(vcf);
      expect(result.errors, 0);
      expect(result.created, 0);
      expect(result.skipped, 1);

      // Verificar que el contacto existente ahora tiene foto
      final contacts = await contactRepo.getAllContacts();
      expect(contacts.length, 1);
      final rel = await contactRepo.getContactWithRelations(contacts[0].id);
      expect(rel!.contact.photoPath, isNotNull);
      expect(rel.contact.photoPath, isNotEmpty);

      // Verificar que el archivo existe
      final media = MediaService(baseDirectory: tempDir);
      final file = await media.resolve(rel.contact.photoPath!);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
    });
}
