import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/database/app_database.dart' as adb;
import 'package:nexo/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:nexo/features/contacts/data/services/contact_search_service.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/services/media/media_service.dart';

void main() {
  group('ContactSearchService partial matching', () {
    late adb.AppDatabase db;
    late ContactRepositoryImpl contacts;
    late ContactSearchService search;

    setUp(() async {
      db = adb.AppDatabase(NativeDatabase.memory());
      contacts = ContactRepositoryImpl(db, MediaService(), ContactSearchService(db));
      search = ContactSearchService(db);

      // Seed contacts with Spanish names, phones, emails
      await contacts.createContact(
        Contact(givenName: 'José', familyName: 'García'),
        phones: [Phone(contactId: 'x1', valueRaw: '+34 612 345 678')],
        emails: [Email(contactId: 'x1', value: 'jose.garcia@mail.com')],
      );
      await contacts.createContact(
        Contact(givenName: 'María', familyName: 'Núñez'),
        phones: [Phone(contactId: 'x2', valueRaw: '+34 698 765 432')],
        emails: [Email(contactId: 'x2', value: 'maria.nunez@gmail.com')],
      );
      await contacts.createContact(
        Contact(givenName: 'Iñaki', familyName: 'Álvarez'),
        phones: [Phone(contactId: 'x3', valueRaw: '+34 611 222 333')],
        emails: [Email(contactId: 'x3', value: 'inaki.alvarez@correo.es')],
      );
      await contacts.createContact(
        Contact(givenName: 'Ana', familyName: 'Lopez'),
        phones: [Phone(contactId: 'x4', valueRaw: '+34 600 111 222')],
        emails: [Email(contactId: 'x4', value: 'ana.lopez@test.org')],
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('searchIds returns empty for empty query', () async {
      final res = await search.searchIds('');
      expect(res, isEmpty);
    });

    test('finds partial match by given name (jos → José)', () async {
      final res = await search.searchIds('jos');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.givenName, 'José');
    });

    test('finds partial match by family name (gar → García)', () async {
      final res = await search.searchIds('gar');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.familyName, 'García');
    });

    test('finds partial match by middle fragment (ñez → Núñez)', () async {
      final res = await search.searchIds('ñez');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.familyName, 'Núñez');
    });

    test('search is accent-insensitive (jose finds José)', () async {
      final res = await search.searchIds('jose');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.givenName, 'José');
    });

    test('search is accent-insensitive (nunez finds Núñez)', () async {
      final res = await search.searchIds('nunez');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.familyName, 'Núñez');
    });

    test('search is accent-insensitive (alvarez finds Álvarez)', () async {
      final res = await search.searchIds('alvarez');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.familyName, 'Álvarez');
    });

    test('finds partial match by phone digits (612 → José García)', () async {
      final res = await search.searchIds('612');
      expect(res.isNotEmpty, isTrue);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.givenName, 'José');
    });

    test('finds partial match by phone intermediate digits (345 → José García)', () async {
      final res = await search.searchIds('345');
      expect(res.isNotEmpty, isTrue);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.givenName, 'José');
    });

    test('finds partial match by email domain (gmail → María Núñez)', () async {
      final res = await search.searchIds('gmail');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.familyName, 'Núñez');
    });

    test('finds partial match by email fragment (jose → José García)', () async {
      final res = await search.searchIds('jose');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.givenName, 'José');
    });

    test('returns empty when no results match', () async {
      final res = await search.searchIds('zzznomatch');
      expect(res, isEmpty);
    });

    test('case-insensitive search (JOS finds José)', () async {
      final res = await search.searchIds('JOS');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.givenName, 'José');
    });

    test('contact without email does not produce false email results', () async {
      await contacts.createContact(
        Contact(givenName: 'Sin', familyName: 'Correo'),
        phones: [Phone(contactId: 'x5', valueRaw: '+34 600 000 000')],
        // no emails
      );
      // 'Sin' should match only by name (Sin Correo has no email)
      final res = await search.searchIds('Sin');
      expect(res.length, 1);
      final contact = await contacts.getContactById(res.first);
      expect(contact!.familyName, 'Correo');
      // Verify the contact has no emails
      final rel = await contacts.getContactWithRelations(contact.id);
      expect(rel!.emails.isEmpty, isTrue);
      // A query that only matches an email domain should not find this contact
      final noEmailRes = await search.searchIds('nonexistentdomain.com');
      expect(noEmailRes.isEmpty, isTrue);
    });
  });
}
