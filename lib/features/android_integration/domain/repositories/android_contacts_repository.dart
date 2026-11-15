import '../entities/android_contact.dart';

/// Interface for accessing the Android Contacts Provider.
///
/// All operations are explicit and user-initiated. No automatic
/// synchronization or background operations are performed.
abstract class AndroidContactsRepository {
  /// Checks whether contact read permission is granted.
  Future<bool> hasReadPermission();

  /// Requests read permission for contacts.
  /// Returns true if granted, false otherwise.
  Future<bool> requestReadPermission();

  /// Checks whether contact write permission is granted.
  Future<bool> hasWritePermission();

  /// Requests write permission for contacts.
  /// Returns true if granted, false otherwise.
  Future<bool> requestWritePermission();

  /// Returns all available accounts on the device.
  Future<List<AndroidAccount>> getAccounts();

  /// Returns all aggregated contacts from Android.
  ///
  /// If [account] is provided, only contacts from that account are returned.
  Future<List<AndroidContact>> getContacts({
    AndroidAccount? account,
    String? query,
  });

  /// Returns a single aggregated contact by its Android ID.
  Future<AndroidContact?> getContactById(String androidContactId);

  /// Exports a NEXO contact to Android, creating a new contact.
  ///
  /// If [account] is null, the default account is used.
  Future<AndroidExportResult> exportContact({
    required String nexoContactId,
    required String displayName,
    String? givenName,
    String? familyName,
    String? phone,
    String? phoneLabel,
    String? email,
    String? emailLabel,
    String? company,
    String? title,
    String? notes,
    AndroidAccount? account,
    List<int>? photoBytes, // JPEG/PNG bytes
    String? photoMimeType,
  });

  /// Exports multiple NEXO contacts to Android.
  Future<List<AndroidExportResult>> exportContacts({
    required List<Map<String, dynamic>> contacts,
    AndroidAccount? account,
  });

  /// Detects potential duplicates in Android for a given phone or email.
  /// Returns matching Android contact IDs.
  Future<List<String>> findDuplicates({
    String? phone,
    String? email,
  });
}
