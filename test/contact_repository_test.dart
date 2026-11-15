import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:nexo/database/app_database.dart' as adb;
import 'package:image/image.dart' as img;
import 'package:nexo/core/errors/nexo_exception.dart';
import 'package:nexo/features/contacts/data/services/contact_search_service.dart';
import 'package:nexo/services/media/media_service.dart';
import 'package:nexo/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late adb.AppDatabase db;
  late MediaService media;
  late ContactRepositoryImpl repo;
  late Directory tempDir;

  setUp(() async {
    db = adb.AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('nexo_media');
    media = MediaService(baseDirectory: tempDir);
    final search = ContactSearchService(db);
    repo = ContactRepositoryImpl(db, media, search);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('create and get contact', () async {
    final c = Contact(givenName: 'Ana', familyName: 'Garcia');
    final created = await repo.createContact(c);
    final fetched = await repo.getContactById(created.id);
    expect(fetched != null, isTrue);
    expect(fetched!.displayName, contains('Ana'));
  });

  test('contact without name is allowed', () async {
    final c = Contact();
    final created = await repo.createContact(c);
    expect(created.id, isNotEmpty);
    expect(created.displayName, 'Contacto sin nombre');
  });

  test('update contact', () async {
    final c = Contact(givenName: 'Ana');
    await repo.createContact(c);
    final updated = c.copyWith(givenName: 'Anita');
    await repo.updateContact(updated);
    final fetched = await repo.getContactById(c.id);
    expect(fetched!.givenName, 'Anita');
  });

  test('delete contact', () async {
    final c = Contact(givenName: 'Ana');
    await repo.createContact(c);
    await repo.deleteContact(c.id);
    final fetched = await repo.getContactById(c.id);
    expect(fetched == null, isTrue);
  });

  test('duplicate contact', () async {
    final c = Contact(givenName: 'Ana', familyName: 'Garcia');
    await repo.createContact(
      c,
      phones: [Phone(contactId: c.id, valueRaw: '123')],
    );
    final dup = await repo.duplicateContact(c.id);
    expect(dup.id, isNot(c.id));
    final rel = await repo.getContactWithRelations(dup.id);
    expect(rel!.phones.length, 1);
    expect(dup.isFavorite, false);
  });

  test('multiple phones primary unique', () async {
    final c = Contact(givenName: 'Ana');
    await repo.createContact(c);
    final p1 = Phone(contactId: c.id, valueRaw: '111', isPrimary: true);
    final p2 = Phone(contactId: c.id, valueRaw: '222', isPrimary: true);
    await repo.addPhone(p1);
    await repo.addPhone(p2);
    await repo.setPrimaryPhone(c.id, p2.id);
    final rel = await repo.getContactWithRelations(c.id);
    final primaries = rel!.phones.where((p) => p.isPrimary).toList();
    expect(primaries.length, 1);
    expect(primaries.first.id, p2.id);
  });

  test('favorite toggle persists', () async {
    final c = Contact(givenName: 'Ana');
    await repo.createContact(c);
    await repo.toggleFavorite(c.id, true);
    final fetched = await repo.getContactById(c.id);
    expect(fetched!.isFavorite, true);
  });

  test('children CRUD', () async {
    final c = Contact(givenName: 'Ana');
    await repo.createContact(c);
    final email = Email(contactId: c.id, value: 'a@b.com');
    await repo.addEmail(email);
    final org = Organization(contactId: c.id, company: 'ACME');
    await repo.addOrganization(org);
    final addr = Address(contactId: c.id, city: 'Madrid');
    await repo.addAddress(addr);
    final note = Note(contactId: c.id, content: 'nota');
    await repo.addNote(note);
    final field = CustomField(
      contactId: c.id,
      name: 'x',
      type: 'text',
      value: 'v',
    );
    await repo.addCustomField(field);
    final date = ContactDate(contactId: c.id, date: DateTime(2020, 1, 1));
    await repo.addContactDate(date);
    final link = SocialLink(contactId: c.id, type: 'web', value: 'example.com');
    await repo.addSocialLink(link);

    final rel = await repo.getContactWithRelations(c.id);
    expect(rel!.emails.length, 1);
    expect(rel.organizations.length, 1);
    expect(rel.addresses.length, 1);
    expect(rel.notes.length, 1);
    expect(rel.customFields.length, 1);
    expect(rel.dates.length, 1);
    expect(rel.socialLinks.length, 1);

    await repo.deleteEmail(email.id);
    await repo.deleteOrganization(org.id);
    await repo.deleteAddress(addr.id);
    await repo.deleteNote(note.id);
    await repo.deleteCustomField(field.id);
    await repo.deleteContactDate(date.id);
    await repo.deleteSocialLink(link.id);
    final rel2 = await repo.getContactWithRelations(c.id);
    expect(rel2!.emails, isEmpty);
    expect(rel2.organizations, isEmpty);
    expect(rel2.addresses, isEmpty);
    expect(rel2.notes, isEmpty);
    expect(rel2.customFields, isEmpty);
    expect(rel2.dates, isEmpty);
    expect(rel2.socialLinks, isEmpty);
  });

  test('watchContacts stream', () async {
    await repo.createContact(Contact(givenName: 'Ana'));
    final list = await repo.watchContacts().first;
    expect(list.length, 1);
  });
  test('transaction rollback on create failure', () async {
    final c = Contact(givenName: 'Ana');
    final sharedId = const Uuid().v4();
    final p1 = Phone(id: sharedId, contactId: c.id, valueRaw: '111');
    final p2 = Phone(id: sharedId, contactId: c.id, valueRaw: '222');
    expect(
      () => repo.createContact(c, phones: [p1, p2]),
      throwsA(isA<Exception>()),
    );
    final fetched = await repo.getContactById(c.id);
    expect(fetched == null, isTrue);
  });

  test('update sync relations', () async {
    final c = Contact(givenName: 'Ana');
    final phone = Phone(contactId: c.id, valueRaw: '111');
    final email = Email(contactId: c.id, value: 'a@b.com');
    final addr = Address(contactId: c.id, city: 'Madrid');
    await repo.createContact(c, phones: [phone], emails: [email], addresses: [addr]);
    final newPhone = Phone(contactId: c.id, valueRaw: '222');
    final updatedEmail = Email(id: email.id, contactId: c.id, value: 'x@y.com');
    await repo.updateContact(
      c,
      phones: [phone, newPhone],
      emails: [updatedEmail],
      addresses: [],
    );
    var rel = await repo.getContactWithRelations(c.id);
    expect(rel!.phones.length, 2);
    expect(rel.emails.first.value, 'x@y.com');
    expect(rel.addresses, isEmpty);
    await repo.updateContact(
      c,
      phones: [phone, newPhone],
      emails: [updatedEmail],
      addresses: [],
    );
    rel = await repo.getContactWithRelations(c.id);
    expect(rel!.phones.length, 2);
    expect(rel.emails.length, 1);
  });

  test('primary uniqueness', () async {
    final c = Contact(givenName: 'Ana');
    await repo.createContact(c);
    final p1 = Phone(contactId: c.id, valueRaw: '111', isPrimary: true);
    final p2 = Phone(contactId: c.id, valueRaw: '222', isPrimary: true);
    await repo.addPhone(p1);
    await repo.addPhone(p2);
    var rel = await repo.getContactWithRelations(c.id);
    expect(rel!.phones.where((p) => p.isPrimary).length, 1);
    await repo.setPrimaryPhone(c.id, p1.id);
    rel = await repo.getContactWithRelations(c.id);
    expect(rel!.phones.firstWhere((p) => p.id == p1.id).isPrimary, isTrue);
    expect(rel.phones.firstWhere((p) => p.id == p2.id).isPrimary, isFalse);
  });

  test('media service operations', () async {
    final bytes = img.encodePng(img.Image(width: 4, height: 4));
    final path = await media.savePhoto('cmedia', bytes);
    final file = await media.resolve(path);
    expect(file != null, isTrue);
    expect(await file!.readAsBytes(), bytes);
    expect(media.sha256Of(bytes), isNotEmpty);
    await media.replacePhoto('cmedia', img.encodePng(img.Image(width: 2, height: 2)));
    final newFile = await media.resolve(path);
    expect(newFile != null, isTrue);
    await media.deleteContactFiles('cmedia');
    expect(await media.resolve(path), isNull);
  });

  test('watchContacts reactivity', () async {
    final events = <int>[];
    final sub = repo.watchContacts().listen((l) => events.add(l.length));
    final c = await repo.createContact(Contact(givenName: 'Ana'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.toggleFavorite(c.id, true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.deleteContact(c.id);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events, contains(1));
    await sub.cancel();
  });
  test('duplicate contact with photo creates independent file', () async {
    final bytes = img.encodePng(img.Image(width: 4, height: 4));
    final original = Contact(givenName: 'Ana', familyName: 'Garcia');
    final photoPath = await media.savePhoto(original.id, bytes);
    final photoHash = media.sha256Of(bytes);
    final originalWithPhoto = original.copyWith(photoPath: photoPath, photoHash: photoHash);
    await repo.createContact(originalWithPhoto);
    final duplicate = await repo.duplicateContact(originalWithPhoto.id);
    expect(duplicate.photoPath, isNotNull);
    expect(duplicate.photoPath, isNot(originalWithPhoto.photoPath));
    final originalFile = await media.resolve(originalWithPhoto.photoPath!);
    final duplicateFile = await media.resolve(duplicate.photoPath!);
    expect(originalFile, isNotNull);
    expect(duplicateFile, isNotNull);
    expect(await originalFile!.readAsBytes(), bytes);
    expect(await duplicateFile!.readAsBytes(), bytes);
    expect(duplicate.photoHash, media.sha256Of(bytes));
    await repo.deleteContact(originalWithPhoto.id);
    expect(await media.resolve(duplicate.photoPath!), isNotNull);
  });

  test('duplicate contact fails if original photo missing', () async {
    final original = Contact(givenName: 'Ana', photoPath: 'contacts/missing/photo.jpg');
    await repo.createContact(original);
    expect(
      () => repo.duplicateContact(original.id),
      throwsA(isA<StorageException>()),
    );
    final contacts = await repo.getAllContacts();
    expect(contacts.length, 1);
  });

  test('updateContact rollback on failure', () async {
    final c = Contact(givenName: 'Original', familyName: 'Name');
    final phone = Phone(contactId: c.id, valueRaw: '111');
    final email = Email(contactId: c.id, value: 'a@b.com');
    final addr = Address(contactId: c.id, city: 'Madrid');
    await repo.createContact(c, phones: [phone], emails: [email], addresses: [addr]);
    final other = Contact(givenName: 'Other');
    await repo.createContact(other, phones: [Phone(contactId: other.id, valueRaw: '999')]);
    final otherPhone = (await repo.getContactWithRelations(other.id))!.phones.first;
    expect(
      () => repo.updateContact(
        c.copyWith(givenName: 'Changed'),
        phones: [Phone(id: otherPhone.id, contactId: c.id, valueRaw: '222')],
        emails: [Email(id: email.id, contactId: c.id, value: 'changed@b.com')],
        addresses: [],
      ),
      throwsA(isA<Exception>()),
    );
    final fetched = await repo.getContactById(c.id);
    expect(fetched!.givenName, 'Original');
    final rel = await repo.getContactWithRelations(c.id);
    expect(rel!.phones.length, 1);
    expect(rel.phones.first.valueRaw, '111');
    expect(rel.emails.first.value, 'a@b.com');
    expect(rel.addresses.length, 1);
    expect(rel.addresses.first.city, 'Madrid');
  });

  Future<List<String>> searchIds(String query) async {
    final search = ContactSearchService(db);
    return search.searchIds(query);
  }

  test('phone and email sync are reflected in search', () async {
    final c = Contact(givenName: 'Ana', familyName: 'Perez');
    final phone = Phone(contactId: c.id, valueRaw: '600000001');
    final email = Email(contactId: c.id, value: 'ana@oldmail.com');
    await repo.createContact(c, phones: [phone], emails: [email]);

    expect((await searchIds('ana')).isNotEmpty, isTrue);
    expect((await searchIds('perez')).isNotEmpty, isTrue);
    expect((await searchIds('600000001')).isNotEmpty, isTrue);
    expect((await searchIds('oldmail')).isNotEmpty, isTrue);

    // modificar teléfono: el valor anterior deja de encontrarse y el nuevo aparece
    await repo.updatePhone(Phone(id: phone.id, contactId: c.id, valueRaw: '600000002'));
    expect((await searchIds('600000001')).isEmpty, isTrue);
    expect((await searchIds('600000002')).isNotEmpty, isTrue);

    // eliminar teléfono
    await repo.deletePhone(phone.id);
    expect((await searchIds('600000002')).isEmpty, isTrue);

    // modificar correo
    await repo.updateEmail(Email(id: email.id, contactId: c.id, value: 'ana@newmail.com'));
    expect((await searchIds('oldmail')).isEmpty, isTrue);
    expect((await searchIds('newmail')).isNotEmpty, isTrue);

    // eliminar correo
    await repo.deleteEmail(email.id);
    expect((await searchIds('newmail')).isEmpty, isTrue);
  });

  test('delete contact removes from search', () async {
    final c = Contact(givenName: 'Luis', familyName: 'Gomez');
    await repo.createContact(c);
    expect((await searchIds('luis')).isNotEmpty, isTrue);
    expect((await searchIds('gomez')).isNotEmpty, isTrue);
    await repo.deleteContact(c.id);
    expect((await searchIds('luis')).isEmpty, isTrue);
    expect((await searchIds('gomez')).isEmpty, isTrue);
  });

}

