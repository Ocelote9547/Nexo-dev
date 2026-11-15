import 'package:nexo/database/app_database.dart';
import 'package:nexo/services/media/media_service.dart';

/// Service for privacy-related operations.
class PrivacyService {
  final AppDatabase _db;
  final MediaService _media;

  PrivacyService(this._db, this._media);

  /// Returns a summary of stored data for privacy transparency.
  Future<Map<String, dynamic>> getDataSummary() async {
    final contacts = await _db.select(_db.contacts).get();
    final phones = await _db.select(_db.phones).get();
    final emails = await _db.select(_db.emails).get();
    final addresses = await _db.select(_db.addresses).get();
    final notes = await _db.select(_db.notes).get();
    final collections = await _db.select(_db.collections).get();
    final tags = await _db.select(_db.tags).get();

    return {
      'contacts': contacts.length,
      'phones': phones.length,
      'emails': emails.length,
      'addresses': addresses.length,
      'notes': notes.length,
      'collections': collections.length,
      'tags': tags.length,
    };
  }

  /// Deletes all data from NEXO. Requires explicit confirmation.
  Future<void> deleteAllData({required bool confirmed}) async {
    if (!confirmed) {
      throw StateError('Se requiere confirmación explícita para eliminar todos los datos');
    }
    final contacts = await _db.select(_db.contacts).get();
    for (final c in contacts) {
      await _media.deleteContactFiles(c.id);
      await (_db.delete(_db.contacts)..where((t) => t.id.equals(c.id))).go();
    }
    await _db.delete(_db.appSettings).go();
  }
}
