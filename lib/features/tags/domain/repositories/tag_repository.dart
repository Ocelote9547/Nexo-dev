
abstract class TagRepository {
  Future<String> createTag(String name, {String? color});
  Future<void> updateTag(String id, {String? name, String? color});
  Future<void> deleteTag(String id);
  Future<Map<String, dynamic>?> getTagById(String id);
  Future<List<Map<String, dynamic>>> getAllTags();
  Stream<List<Map<String, dynamic>>> watchTags();
  Future<void> addTagToContact(String tagId, String contactId);
  Future<void> removeTagFromContact(String tagId, String contactId);
  Future<List<String>> getTagIdsForContact(String contactId);
  Future<List<String>> getContactIdsForTag(String tagId);
  Future<bool> hasAssignment(String tagId, String contactId);
}
