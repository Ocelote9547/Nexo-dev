abstract class CollectionRepository {
  Future<String> createCollection(String name, {String? description, String? color, String? icon});
  Future<void> updateCollection(String id, {String? name, String? description, String? color, String? icon});
  Future<void> deleteCollection(String id);
  Future<Map<String, dynamic>?> getCollectionById(String id);
  Future<List<Map<String, dynamic>>> getAllCollections();
  Stream<List<Map<String, dynamic>>> watchCollections();
  Future<void> addContactToCollection(String collectionId, String contactId);
  Future<void> removeContactFromCollection(String collectionId, String contactId);
  Future<List<String>> getContactIdsForCollection(String collectionId);
  Future<List<String>> getCollectionIdsForContact(String contactId);
  Future<bool> hasMembership(String collectionId, String contactId);
}
