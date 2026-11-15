/// Represents an aggregated contact from Android Contacts Provider.
///
/// Android may merge multiple RawContacts (from different accounts) into one
/// aggregated contact. This entity represents that aggregated view.
class AndroidContact {
  final String id;
  final String displayName;
  final String? givenName;
  final String? familyName;
  final String? middleName;
  final String? prefix;
  final String? suffix;
  final String? phoneticGiven;
  final String? phoneticFamily;
  final String? nickname;
  final String? phone; // primary phone
  final String? email; // primary email
  final String? company;
  final String? title;
  final bool isStarred; // Android favorite/starred
  final List<AndroidRawContact> rawContacts;

  AndroidContact({
    required this.id,
    required this.displayName,
    this.givenName,
    this.familyName,
    this.middleName,
    this.prefix,
    this.suffix,
    this.phoneticGiven,
    this.phoneticFamily,
    this.nickname,
    this.phone,
    this.email,
    this.company,
    this.title,
    this.isStarred = false,
    this.rawContacts = const [],
  });
}

/// Represents a single RawContact from an Android account.
///
/// Multiple RawContacts can belong to the same aggregated contact.
class AndroidRawContact {
  final String id;
  final String contactId; // aggregated contact id
  final String accountName;
  final String accountType;
  final String? sourceId; // stable server UUID (when available)
  final List<AndroidDataRow> dataRows;

  AndroidRawContact({
    required this.id,
    required this.contactId,
    required this.accountName,
    required this.accountType,
    this.sourceId,
    this.dataRows = const [],
  });
}

/// Represents a single data row from ContactsContract.Data.
class AndroidDataRow {
  final String id;
  final String rawContactId;
  final String mimeType;
  final String? data1; // primary value (phone, email, etc.)
  final String? data2; // secondary value (label, type, etc.)
  final String? data3;
  final String? data4;
  final String? data5;
  final String? data6;
  final String? data7;
  final String? data8;
  final String? data9;
  final String? data10;
  final String? data11;
  final String? data12;
  final String? data13;
  final String? data14;
  final String? data15; // BLOB (photo)

  AndroidDataRow({
    required this.id,
    required this.rawContactId,
    required this.mimeType,
    this.data1,
    this.data2,
    this.data3,
    this.data4,
    this.data5,
    this.data6,
    this.data7,
    this.data8,
    this.data9,
    this.data10,
    this.data11,
    this.data12,
    this.data13,
    this.data14,
    this.data15,
  });
}

/// Represents an Android account (Google, local, SIM, etc.).
class AndroidAccount {
  final String name;
  final String type;

  AndroidAccount({required this.name, required this.type});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AndroidAccount &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type;

  @override
  int get hashCode => name.hashCode ^ type.hashCode;

  @override
  String toString() => 'AndroidAccount(name: $name, type: $type)';
}

/// Result of importing a single Android contact into NEXO.
class AndroidImportResult {
  final String androidContactId;
  final String? nexoContactId;
  final bool created;
  final bool skipped;
  final bool merged;
  final bool replaced;
  final List<String> warnings;
  final List<String> errors;

  AndroidImportResult({
    required this.androidContactId,
    this.nexoContactId,
    this.created = false,
    this.skipped = false,
    this.merged = false,
    this.replaced = false,
    this.warnings = const [],
    this.errors = const [],
  });

  bool get success => errors.isEmpty;
}

/// Result of exporting a single NEXO contact to Android.
class AndroidExportResult {
  final String nexoContactId;
  final String? androidContactId;
  final bool created;
  final bool skipped;
  final bool replaced;
  final List<String> warnings;
  final List<String> errors;

  AndroidExportResult({
    required this.nexoContactId,
    this.androidContactId,
    this.created = false,
    this.skipped = false,
    this.replaced = false,
    this.warnings = const [],
    this.errors = const [],
  });

  bool get success => errors.isEmpty;
}
