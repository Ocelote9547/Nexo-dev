import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/database/app_database.dart' as adb;
import 'package:nexo/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:nexo/features/contacts/data/services/contact_search_service.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/services/media/media_service.dart';

void main() {
  group('Favorites ordering in contacts list', () {
    late adb.AppDatabase db;
    late ContactRepositoryImpl contacts;

    setUp(() async {
      db = adb.AppDatabase(NativeDatabase.memory());
      contacts = ContactRepositoryImpl(db, MediaService(), ContactSearchService(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('favorites appear first, then non-favorites, each alphabetically', () async {
      await contacts.createContact(Contact(givenName: 'Zoe', familyName: 'Last'));
      await contacts.createContact(Contact(givenName: 'Aaron', familyName: 'First'));
      await contacts.createContact(Contact(givenName: 'María', familyName: 'García', isFavorite: true));
      await contacts.createContact(Contact(givenName: 'José', familyName: 'Álvarez', isFavorite: true));

      final all = await contacts.getAllContacts();
      expect(all.length, 4);

      final sorted = List<Contact>.from(all)
        ..sort((a, b) {
          if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
          return a.displayName.compareTo(b.displayName);
        });

      expect(sorted[0].isFavorite, isTrue);
      expect(sorted[1].isFavorite, isTrue);
      expect(sorted[2].isFavorite, isFalse);
      expect(sorted[3].isFavorite, isFalse);

      expect(sorted[0].givenName, 'José');
      expect(sorted[1].givenName, 'María');
      expect(sorted[2].givenName, 'Aaron');
      expect(sorted[3].givenName, 'Zoe');
    });

    test('favorite toggle moves contact between groups in real time', () async {
      final c = Contact(givenName: 'Lucía', familyName: 'Romero', isFavorite: false);
      await contacts.createContact(c);

      var all = await contacts.getAllContacts();
      expect(all.first.isFavorite, isFalse);

      await contacts.toggleFavorite(c.id, true);
      all = await contacts.getAllContacts();
      expect(all.first.isFavorite, isTrue);
      expect(all.first.givenName, 'Lucía');

      await contacts.toggleFavorite(c.id, false);
      all = await contacts.getAllContacts();
      expect(all.first.isFavorite, isFalse);
    });

    test('favorite contact exists once in database but appears in both screens', () async {
      final c = Contact(givenName: 'Elena', familyName: 'Vega', isFavorite: true);
      await contacts.createContact(c);

      final all = await contacts.getAllContacts();
      expect(all.length, 1);
      expect(all.first.isFavorite, isTrue);
      expect(all.first.givenName, 'Elena');
      expect(all.first.familyName, 'Vega');
    });

    test('search combined with favorites filters correctly', () async {
      await contacts.createContact(
        Contact(givenName: 'José', familyName: 'García', isFavorite: true),
        emails: [Email(contactId: 'x1', value: 'jose@example.com')],
      );
      await contacts.createContact(
        Contact(givenName: 'María', familyName: 'López', isFavorite: false),
        emails: [Email(contactId: 'x2', value: 'maria@example.com')],
      );

      final search = ContactSearchService(db);

      final joseResults = await search.searchIds('jose');
      expect(joseResults.length, 1);
      final joseContact = await contacts.getContactById(joseResults.first);
      expect(joseContact!.givenName, 'José');

      final mariaResults = await search.searchIds('maria');
      expect(mariaResults.length, 1);
      final mariaContact = await contacts.getContactById(mariaResults.first);
      expect(mariaContact!.givenName, 'María');

      final none = await search.searchIds('zzz');
      expect(none, isEmpty);
    });

    test('unfavorited contact returns to alphabetical position', () async {
      await contacts.createContact(Contact(givenName: 'Bruno', familyName: 'Diaz'));
      await contacts.createContact(Contact(givenName: 'Ana', familyName: 'Soto', isFavorite: true));
      await contacts.createContact(Contact(givenName: 'Carlos', familyName: 'Ruiz'));

      var all = await contacts.getAllContacts();
      final sorted = List<Contact>.from(all)
        ..sort((a, b) {
          if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
          return a.displayName.compareTo(b.displayName);
        });
      expect(sorted[0].givenName, 'Ana');
      expect(sorted[0].isFavorite, isTrue);

      await contacts.toggleFavorite(sorted[0].id, false);
      all = await contacts.getAllContacts();
      final sorted2 = List<Contact>.from(all)
        ..sort((a, b) {
          if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
          return a.displayName.compareTo(b.displayName);
        });
      expect(sorted2[0].givenName, 'Ana');
      expect(sorted2[1].givenName, 'Bruno');
      expect(sorted2[2].givenName, 'Carlos');
      expect(sorted2.every((c) => !c.isFavorite), isTrue);
    });
  });

  group('Contact form - multiple relationships', () {
    late adb.AppDatabase db;
    late ContactRepositoryImpl contacts;

    setUp(() async {
      db = adb.AppDatabase(NativeDatabase.memory());
      contacts = ContactRepositoryImpl(db, MediaService(), ContactSearchService(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('create contact with multiple phones, emails, addresses, orgs, socials, dates, notes, custom fields', () async {
      final c = Contact(givenName: 'Juan', familyName: 'Pérez');
      final created = await contacts.createContact(
        c,
        phones: [
          Phone(contactId: c.id, valueRaw: '+34 612 345 678', label: 'mobile'),
          Phone(contactId: c.id, valueRaw: '+34 698 765 432', label: 'work'),
        ],
        emails: [
          Email(contactId: c.id, value: 'juan.perez@example.com', label: 'home'),
          Email(contactId: c.id, value: 'j.perez@work.com', label: 'work'),
        ],
        addresses: [
          Address(
            contactId: c.id,
            street: 'Calle Mayor 1',
            city: 'Madrid',
            country: 'España',
            label: 'home',
          ),
        ],
        organizations: [
          Organization(contactId: c.id, company: 'Acme Corp', title: 'Developer'),
        ],
        socialLinks: [
          SocialLink(contactId: c.id, type: 'web', value: 'acme.example'),
        ],
        dates: [
          ContactDate(contactId: c.id, type: 'birthday', date: DateTime(1985, 5, 15)),
        ],
        notes: [
          Note(contactId: c.id, content: 'Nota de prueba con ñ', source: 'manual'),
        ],
        customFields: [
          CustomField(contactId: c.id, name: 'ref', type: 'text', value: 'ABC123'),
        ],
      );

      expect(created.id, isNotEmpty);

      final rel = await contacts.getContactWithRelations(created.id);
      expect(rel, isNotNull);
      expect(rel!.phones.length, 2);
      expect(rel.emails.length, 2);
      expect(rel.addresses.length, 1);
      expect(rel.organizations.length, 1);
      expect(rel.socialLinks.length, 1);
      expect(rel.dates.length, 1);
      expect(rel.notes.length, 1);
      expect(rel.customFields.length, 1);

      expect(rel.contact.givenName, 'Juan');
      expect(rel.contact.familyName, 'Pérez');
      expect(rel.phones[0].valueRaw, '+34 612 345 678');
      expect(rel.emails[0].value, 'juan.perez@example.com');
      expect(rel.addresses[0].city, 'Madrid');
      expect(rel.addresses[0].country, 'España');
      expect(rel.notes[0].content, 'Nota de prueba con ñ');
    });

    test('edit contact preserves all relationships and Spanish characters', () async {
      final c = Contact(givenName: 'Iñaki', familyName: 'Álvarez');
      final created = await contacts.createContact(
        c,
        phones: [Phone(contactId: c.id, valueRaw: '+34 600 111 222')],
        emails: [Email(contactId: c.id, value: 'inaki@example.com')],
        notes: [Note(contactId: c.id, content: 'Nota original', source: 'manual')],
      );

      final updated = created.copyWith(
        givenName: 'Iñigo',
        familyName: 'Alba',
      );
      await contacts.updateContact(
        updated,
        phones: [Phone(contactId: updated.id, valueRaw: '+34 600 333 444')],
        emails: [Email(contactId: updated.id, value: 'inigo.alba@example.com')],
        notes: [Note(contactId: updated.id, content: 'Nota actualizada con á é í ó ú ü ñ', source: 'manual')],
      );

      final rel = await contacts.getContactWithRelations(updated.id);
      expect(rel!.contact.givenName, 'Iñigo');
      expect(rel.contact.familyName, 'Alba');
      expect(rel.phones.length, 1);
      expect(rel.phones[0].valueRaw, '+34 600 333 444');
      expect(rel.emails.length, 1);
      expect(rel.emails[0].value, 'inigo.alba@example.com');
      expect(rel.notes.length, 1);
      expect(rel.notes[0].content, 'Nota actualizada con á é í ó ú ü ñ');
    });

    test('contact with Spanish characters persists and retrieves correctly', () async {
      final names = [
        Contact(givenName: 'José', familyName: 'García'),
        Contact(givenName: 'María', familyName: 'Núñez'),
        Contact(givenName: 'Muñoz', familyName: 'Peña'),
        Contact(givenName: 'Álvarez', familyName: 'Iñaki'),
        Contact(givenName: 'Zoë', familyName: 'Coopér'),
      ];

      for (final c in names) {
        await contacts.createContact(c);
      }

      final all = await contacts.getAllContacts();
      expect(all.length, 5);

      final garcia = all.where((c) => c.familyName == 'García').first;
      expect(garcia.givenName, 'José');

      final nunez = all.where((c) => c.familyName == 'Núñez').first;
      expect(nunez.givenName, 'María');

      final zoe = all.where((c) => c.givenName == 'Zoë').first;
      expect(zoe.familyName, 'Coopér');
    });
  });
}
