import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/database/app_database.dart' as adb;
import 'package:nexo/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:nexo/features/contacts/data/services/contact_search_service.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/features/tags/data/repositories/tag_repository_impl.dart';
import 'package:nexo/features/collections/data/repositories/collection_repository_impl.dart';
import 'package:nexo/services/media/media_service.dart';

void main() {
  late adb.AppDatabase db;
  late TagRepositoryImpl tags;
  late CollectionRepositoryImpl collections;
  late ContactRepositoryImpl contacts;
  late ContactSearchService search;

  setUp(() {
    db = adb.AppDatabase(NativeDatabase.memory());
    tags = TagRepositoryImpl(db);
    collections = CollectionRepositoryImpl(db);
    contacts = ContactRepositoryImpl(db, MediaService(), ContactSearchService(db));
    search = ContactSearchService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('tag CRUD and assignment', () async {
    final tagId = await tags.createTag('Work', color: '#fff');
    expect((await tags.getTagById(tagId)) != null, isTrue);
    await tags.updateTag(tagId, name: 'Job');
    final updated = await tags.getTagById(tagId);
    expect(updated!['name'], 'Job');
    final c = Contact(givenName: 'Ana');
    await contacts.createContact(c);
    await tags.addTagToContact(tagId, c.id);
    expect(await tags.hasAssignment(tagId, c.id), isTrue);
    expect(await tags.getContactIdsForTag(tagId), contains(c.id));
    expect(await tags.getTagIdsForContact(c.id), contains(tagId));
    // duplicate assignment avoided
    await tags.addTagToContact(tagId, c.id);
    expect((await tags.getContactIdsForTag(tagId)).length, 1);
    await tags.removeTagFromContact(tagId, c.id);
    expect(await tags.hasAssignment(tagId, c.id), isFalse);
    await tags.deleteTag(tagId);
    expect(await tags.getTagById(tagId) == null, isTrue);
  });

  test('collection CRUD and membership', () async {
    final collId = await collections.createCollection('Friends', description: 'd');
    expect((await collections.getCollectionById(collId)) != null, isTrue);
    await collections.updateCollection(collId, name: 'Best');
    expect((await collections.getCollectionById(collId))!['name'], 'Best');
    final c = Contact(givenName: 'Ana');
    await contacts.createContact(c);
    await collections.addContactToCollection(collId, c.id);
    expect(await collections.hasMembership(collId, c.id), isTrue);
    expect(await collections.getContactIdsForCollection(collId), contains(c.id));
    expect(await collections.getCollectionIdsForContact(c.id), contains(collId));
    await collections.addContactToCollection(collId, c.id);
    expect((await collections.getContactIdsForCollection(collId)).length, 1);
    await collections.removeContactFromCollection(collId, c.id);
    expect(await collections.hasMembership(collId, c.id), isFalse);
    await collections.deleteCollection(collId);
    expect(await collections.getCollectionById(collId) == null, isTrue);
  });

  test('search FTS5 basic, special chars, no results, update, delete', () async {
    final c = Contact(givenName: 'Ana', familyName: 'Garcia');
    await contacts.createContact(c, phones: [Phone(contactId: c.id, valueRaw: '123456')], emails: [Email(contactId: c.id, value: 'ana@example.com')]);
    await search.upsert(c.id);
    final res = await search.searchIds('ana');
    expect(res, contains(c.id));
    final noRes = await search.searchIds('zzzz');
    expect(noRes, isEmpty);
    // special chars should not throw
    final special = await search.searchIds('a"b (test)');
    expect(special, isA<List<String>>());
    // update index
    await contacts.updateContact(c.copyWith(givenName: 'Anita'), phones: [Phone(contactId: c.id, valueRaw: '123456')], emails: [Email(contactId: c.id, value: 'ana@example.com')]);
    await search.upsert(c.id);
    final res2 = await search.searchIds('anita');
    expect(res2, contains(c.id));
    final oldRes = await search.searchIds('ana garcia');
    // may or may not contain; ensure no crash
    expect(oldRes, isA<List<String>>());
    // delete
    await contacts.deleteContact(c.id);
    await search.delete(c.id);
    final after = await search.searchIds('anita');
    expect(after, isNot(contains(c.id)));
  });

  test('search filters favorites/tags/collections', () async {
    final c = Contact(givenName: 'Ana', isFavorite: true);
    await contacts.createContact(c);
    await search.upsert(c.id);
    final tagId = await tags.createTag('Work');
    await tags.addTagToContact(tagId, c.id);
    final collId = await collections.createCollection('Friends');
    await collections.addContactToCollection(collId, c.id);
    final favRes = await search.searchIds('ana', favoritesOnly: true);
    expect(favRes, contains(c.id));
    final tagRes = await search.searchIds('ana', tagId: tagId);
    expect(tagRes, contains(c.id));
    final collRes = await search.searchIds('ana', collectionId: collId);
    expect(collRes, contains(c.id));
  });

  test('search fallback sin FTS5 encuentra todos los campos', () async {
    final fallbackSearch = ContactSearchService(db, forceFallback: true);
    expect(await fallbackSearch.isFts5Available(), isFalse);

    final c = Contact(givenName: 'Juan', familyName: 'Lopez');
    await contacts.createContact(
      c,
      phones: [Phone(contactId: c.id, valueRaw: '600111222')],
      emails: [Email(contactId: c.id, value: 'juan.lopez@mail.com')],
      addresses: [
        Address(contactId: c.id, street: 'Calle Mayor 1', city: 'Madrid', country: 'España')
      ],
      organizations: [Organization(contactId: c.id, company: 'Acme Corp', title: 'Dev')],
      socialLinks: [SocialLink(contactId: c.id, type: 'web', value: 'acme.example')],
      notes: [Note(contactId: c.id, content: 'nota de prueba')],
      customFields: [CustomField(contactId: c.id, name: 'ref', type: 'text', value: 'ABC123')],
    );

    expect((await fallbackSearch.searchIds('juan')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('lopez')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('600111222')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('mail')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('mayor')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('madrid')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('acme')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('dev')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('acme.example')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('nota')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('abc123')).contains(c.id), isTrue);
    expect((await fallbackSearch.searchIds('zzznoresults')).isEmpty, isTrue);

    final ids = await fallbackSearch.searchIds('juan');
    expect(ids.toSet().length, ids.length);

    await contacts.toggleFavorite(c.id, true);
    final fav = await fallbackSearch.searchIds('juan', favoritesOnly: true);
    expect(fav.contains(c.id), isTrue);
  });

  test('tag streams react to create modify delete', () async {
    final received = <int>[];
    final sub = tags.watchTags().listen((list) => received.add(list.length));
    await tags.createTag('T1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final id = (await tags.getAllTags()).first['id'] as String;
    await tags.updateTag(id, name: 'T1 modified');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tags.deleteTag(id);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(received, contains(1));
    expect(received.last, 0);
  });

  test('collection streams react to create modify delete', () async {
    final received = <int>[];
    final sub = collections.watchCollections().listen((list) => received.add(list.length));
    await collections.createCollection('C1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final id = (await collections.getAllCollections()).first['id'] as String;
    await collections.updateCollection(id, name: 'C1 modified');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await collections.deleteCollection(id);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(received, contains(1));
    expect(received.last, 0);
  });
}
