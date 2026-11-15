import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../database/app_database.dart';
import '../../domain/repositories/collection_repository.dart';

class CollectionRepositoryImpl implements CollectionRepository {
  final AppDatabase _db;
  CollectionRepositoryImpl(this._db);

  @override
  Future<String> createCollection(String name, {String? description, String? color, String? icon}) async {
    final id = const Uuid().v4();
    await _db.into(_db.collections).insert(CollectionsCompanion.insert(id: id, name: name, description: Value(description), color: Value(color), icon: Value(icon)));
    return id;
  }

  @override
  Future<void> updateCollection(String id, {String? name, String? description, String? color, String? icon}) async {
    await (_db.update(_db.collections)..where((t) => t.id.equals(id))).write(CollectionsCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          description: description != null ? Value(description) : const Value.absent(),
          color: color != null ? Value(color) : const Value.absent(),
          icon: icon != null ? Value(icon) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ));
  }

  @override
  Future<void> deleteCollection(String id) async {
    await (_db.delete(_db.collections)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<Map<String, dynamic>?> getCollectionById(String id) async {
    final row = await (_db.select(_db.collections)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return {'id': row.id, 'name': row.name, 'description': row.description, 'color': row.color, 'icon': row.icon};
  }

  @override
  Future<List<Map<String, dynamic>>> getAllCollections() async {
    final rows = await _db.select(_db.collections).get();
    return rows.map((r) => {'id': r.id, 'name': r.name, 'description': r.description, 'color': r.color, 'icon': r.icon}).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCollections() {
    return _db.select(_db.collections).watch().map((rows) => rows.map((r) => {'id': r.id, 'name': r.name, 'description': r.description, 'color': r.color, 'icon': r.icon}).toList());
  }

  @override
  Future<void> addContactToCollection(String collectionId, String contactId) async {
    final existing = await (_db.select(_db.collectionContacts)..where((t) => t.collectionId.equals(collectionId) & t.contactId.equals(contactId))).getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.collectionContacts).insert(CollectionContactsCompanion.insert(collectionId: collectionId, contactId: contactId));
  }

  @override
  Future<void> removeContactFromCollection(String collectionId, String contactId) async {
    await (_db.delete(_db.collectionContacts)..where((t) => t.collectionId.equals(collectionId) & t.contactId.equals(contactId))).go();
  }

  @override
  Future<List<String>> getContactIdsForCollection(String collectionId) async {
    final rows = await (_db.select(_db.collectionContacts)..where((t) => t.collectionId.equals(collectionId))).get();
    return rows.map((r) => r.contactId).toList();
  }

  @override
  Future<List<String>> getCollectionIdsForContact(String contactId) async {
    final rows = await (_db.select(_db.collectionContacts)..where((t) => t.contactId.equals(contactId))).get();
    return rows.map((r) => r.collectionId).toList();
  }

  @override
  Future<bool> hasMembership(String collectionId, String contactId) async {
    final row = await (_db.select(_db.collectionContacts)..where((t) => t.collectionId.equals(collectionId) & t.contactId.equals(contactId))).getSingleOrNull();
    return row != null;
  }
}
