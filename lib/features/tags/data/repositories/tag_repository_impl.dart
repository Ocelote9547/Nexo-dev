import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repositories/tag_repository.dart';

import '../../../../database/app_database.dart';

class TagRepositoryImpl implements TagRepository {
  final AppDatabase _db;
  TagRepositoryImpl(this._db);

  @override
  Future<String> createTag(String name, {String? color}) async {
    final id = const Uuid().v4();
    await _db.into(_db.tags).insert(TagsCompanion.insert(id: id, name: name, color: Value(color)));
    return id;
  }

  @override
  Future<void> updateTag(String id, {String? name, String? color}) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(TagsCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          color: color != null ? Value(color) : const Value.absent(),
        ));
  }

  @override
  Future<void> deleteTag(String id) async {
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<Map<String, dynamic>?> getTagById(String id) async {
    final row = await (_db.select(_db.tags)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return {'id': row.id, 'name': row.name, 'color': row.color};
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTags() async {
    final rows = await _db.select(_db.tags).get();
    return rows.map((r) => {'id': r.id, 'name': r.name, 'color': r.color}).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTags() {
    return _db.select(_db.tags).watch().map((rows) => rows.map((r) => {'id': r.id, 'name': r.name, 'color': r.color}).toList());
  }

  @override
  Future<void> addTagToContact(String tagId, String contactId) async {
    final existing = await (_db.select(_db.contactTags)..where((t) => t.tagId.equals(tagId) & t.contactId.equals(contactId))).getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.contactTags).insert(ContactTagsCompanion.insert(tagId: tagId, contactId: contactId));
  }

  @override
  Future<void> removeTagFromContact(String tagId, String contactId) async {
    await (_db.delete(_db.contactTags)..where((t) => t.tagId.equals(tagId) & t.contactId.equals(contactId))).go();
  }

  @override
  Future<List<String>> getTagIdsForContact(String contactId) async {
    final rows = await (_db.select(_db.contactTags)..where((t) => t.contactId.equals(contactId))).get();
    return rows.map((r) => r.tagId).toList();
  }

  @override
  Future<List<String>> getContactIdsForTag(String tagId) async {
    final rows = await (_db.select(_db.contactTags)..where((t) => t.tagId.equals(tagId))).get();
    return rows.map((r) => r.contactId).toList();
  }

  @override
  Future<bool> hasAssignment(String tagId, String contactId) async {
    final row = await (_db.select(_db.contactTags)..where((t) => t.tagId.equals(tagId) & t.contactId.equals(contactId))).getSingleOrNull();
    return row != null;
  }
}
