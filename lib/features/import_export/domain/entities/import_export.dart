
/// Resultado detallado de un intento de importación de un contacto individual.
class ImportedContactResult {
  final bool success;
  final String? contactId;
  final String? sourceIdentifier; // identificador de origen (ej: línea CSV, tarjeta vCard)
  final String? errorMessage;
  final Map<String, dynamic>? contactData;

  ImportedContactResult({
    required this.success,
    this.contactId,
    this.sourceIdentifier,
    this.errorMessage,
    this.contactData,
  });
}

/// Resultado de importar uno o más contactos desde cualquier origen.
class ImportResult {
  int created;
  int skipped;
  int merged;
  int replaced;
  int errors;
  int photosImported;
  int photosUnavailable;
  final List<String> warnings;
  final List<String> errorMessages;
  final List<ImportedContactResult> failedRecords;
  int processed;
  int total;

  ImportResult({
    this.created = 0,
    this.skipped = 0,
    this.merged = 0,
    this.replaced = 0,
    this.errors = 0,
    this.photosImported = 0,
    this.photosUnavailable = 0,
    List<String> warnings = const [],
    List<String> errorMessages = const [],
    List<ImportedContactResult> failedRecords = const [],
    this.processed = 0,
    this.total = 0,
  })  : warnings = List<String>.from(warnings),
        errorMessages = List<String>.from(errorMessages),
        failedRecords = List<ImportedContactResult>.from(failedRecords);

  int get totalProcessed => created + skipped + merged + replaced + errors;
  bool get allSucceeded => errors == 0 && totalProcessed > 0;
}

/// Callback de progreso para importación masiva.
typedef ImportProgressCallback = void Function(ImportProgressInfo);

/// Información de progreso de una importación en curso.
class ImportProgressInfo {
  final int processed;
  final int total;
  final int created;
  final int skipped;
  final int errors;
  final int photosImported;
  final int photosUnavailable;
  final int warningsCount;
  final String? currentSource;

  ImportProgressInfo({
    required this.processed,
    required this.total,
    required this.created,
    this.skipped = 0,
    required this.errors,
    this.photosImported = 0,
    this.photosUnavailable = 0,
    this.warningsCount = 0,
    this.currentSource,
  });

  double get percentage => total > 0 ? processed / total : 0.0;
}

/// A potential duplicate match between an incoming contact and an existing NEXO contact.
class DuplicateCandidate {
  final String nexoContactId;
  final String nexoDisplayName;
  final double confidence;
  final List<String> matchReasons;
  final Map<String, dynamic> nexoContactData;
  final Map<String, dynamic> incomingContactData;

  DuplicateCandidate({
    required this.nexoContactId,
    required this.nexoDisplayName,
    required this.confidence,
    required this.matchReasons,
    required this.nexoContactData,
    required this.incomingContactData,
  });

  bool get isStrongMatch => confidence >= 0.8;
  bool get isPossibleMatch => confidence >= 0.5 && confidence < 0.8;
}

/// How to resolve a duplicate.
enum DuplicateResolution {
  skip,
  createNew,
  merge,
  replace,
}

/// Result of duplicate resolution for a single contact.
class DuplicateResolutionResult {
  final String incomingSourceId;
  final String? nexoContactId;
  final String? newContactId;
  final DuplicateResolution resolution;
  final Map<String, dynamic>? mergedData;

  DuplicateResolutionResult({
    required this.incomingSourceId,
    this.nexoContactId,
    this.newContactId,
    required this.resolution,
    this.mergedData,
  });
}

/// Information about an export operation to Android.
class AndroidExportSummary {
  final int total;
  final int created;
  final int skipped;
  final int replaced;
  final int errors;
  final List<dynamic> results;

  AndroidExportSummary({
    required this.total,
    required this.created,
    required this.skipped,
    required this.replaced,
    required this.errors,
    required this.results,
  });

  bool get allSucceeded => errors == 0 && total > 0;
}

/// Represents a contact ready for import/export in NEXO's portable format.
class PortableContact {
  final String id;
  final String? givenName;
  final String? middleName;
  final String? familyName;
  final String? prefix;
  final String? suffix;
  final String? phoneticGiven;
  final String? phoneticFamily;
  final String? nickname;
  final String? photoPath;
  final String? photoHash;
  final String? photoBase64;
  final String? photoMimeType;
  final bool isFavorite;
  final DateTime? favoriteMarkedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PortablePhone> phones;
  final List<PortableEmail> emails;
  final List<PortableAddress> addresses;
  final List<PortableSocialLink> socialLinks;
  final List<PortableOrganization> organizations;
  final List<PortableContactDate> dates;
  final List<PortableNote> notes;
  final List<PortableCustomField> customFields;
  final List<String> tagIds;
  final List<String> collectionIds;

  PortableContact({
    required this.id,
    this.givenName,
    this.middleName,
    this.familyName,
    this.prefix,
    this.suffix,
    this.phoneticGiven,
    this.phoneticFamily,
    this.nickname,
    this.photoPath,
    this.photoHash,
    this.photoBase64,
    this.photoMimeType,
    this.isFavorite = false,
    this.favoriteMarkedAt,
    required this.createdAt,
    required this.updatedAt,
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
    this.socialLinks = const [],
    this.organizations = const [],
    this.dates = const [],
    this.notes = const [],
    this.customFields = const [],
    this.tagIds = const [],
    this.collectionIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'givenName': givenName,
      'middleName': middleName,
      'familyName': familyName,
      'prefix': prefix,
      'suffix': suffix,
      'phoneticGiven': phoneticGiven,
      'phoneticFamily': phoneticFamily,
      'nickname': nickname,
      'photoPath': photoPath,
      'photoHash': photoHash,
      'photoBase64': photoBase64,
      'photoMimeType': photoMimeType,
      'isFavorite': isFavorite,
      'favoriteMarkedAt': favoriteMarkedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'phones': phones.map((p) => p.toJson()).toList(),
      'emails': emails.map((e) => e.toJson()).toList(),
      'addresses': addresses.map((a) => a.toJson()).toList(),
      'socialLinks': socialLinks.map((s) => s.toJson()).toList(),
      'organizations': organizations.map((o) => o.toJson()).toList(),
      'dates': dates.map((d) => d.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'customFields': customFields.map((c) => c.toJson()).toList(),
      'tagIds': tagIds,
      'collectionIds': collectionIds,
    };
  }

  factory PortableContact.fromJson(Map<String, dynamic> json) {
    return PortableContact(
      id: json['id'] as String,
      givenName: json['givenName'] as String?,
      middleName: json['middleName'] as String?,
      familyName: json['familyName'] as String?,
      prefix: json['prefix'] as String?,
      suffix: json['suffix'] as String?,
      phoneticGiven: json['phoneticGiven'] as String?,
      phoneticFamily: json['phoneticFamily'] as String?,
      nickname: json['nickname'] as String?,
      photoPath: json['photoPath'] as String?,
      photoHash: json['photoHash'] as String?,
      photoBase64: json['photoBase64'] as String?,
      photoMimeType: json['photoMimeType'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      favoriteMarkedAt: json['favoriteMarkedAt'] != null
          ? DateTime.parse(json['favoriteMarkedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      phones: (json['phones'] as List? ?? [])
          .map((p) => PortablePhone.fromJson(p as Map<String, dynamic>))
          .toList(),
      emails: (json['emails'] as List? ?? [])
          .map((e) => PortableEmail.fromJson(e as Map<String, dynamic>))
          .toList(),
      addresses: (json['addresses'] as List? ?? [])
          .map((a) => PortableAddress.fromJson(a as Map<String, dynamic>))
          .toList(),
      socialLinks: (json['socialLinks'] as List? ?? [])
          .map((s) => PortableSocialLink.fromJson(s as Map<String, dynamic>))
          .toList(),
      organizations: (json['organizations'] as List? ?? [])
          .map((o) => PortableOrganization.fromJson(o as Map<String, dynamic>))
          .toList(),
      dates: (json['dates'] as List? ?? [])
          .map((d) => PortableContactDate.fromJson(d as Map<String, dynamic>))
          .toList(),
      notes: (json['notes'] as List? ?? [])
          .map((n) => PortableNote.fromJson(n as Map<String, dynamic>))
          .toList(),
      customFields: (json['customFields'] as List? ?? [])
          .map((c) => PortableCustomField.fromJson(c as Map<String, dynamic>))
          .toList(),
      tagIds: (json['tagIds'] as List? ?? []).cast<String>(),
      collectionIds: (json['collectionIds'] as List? ?? []).cast<String>(),
    );
  }
}

class PortablePhone {
  final String id;
  final String valueRaw;
  final String? valueNormalized;
  final String label;
  final String? customLabel;
  final bool isPrimary;
  final int sortOrder;

  PortablePhone({
    required this.id,
    required this.valueRaw,
    this.valueNormalized,
    this.label = 'mobile',
    this.customLabel,
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'valueRaw': valueRaw,
      'valueNormalized': valueNormalized,
      'label': label,
      'customLabel': customLabel,
      'isPrimary': isPrimary,
      'sortOrder': sortOrder,
    };
  }

  factory PortablePhone.fromJson(Map<String, dynamic> json) {
    return PortablePhone(
      id: json['id'] as String,
      valueRaw: json['valueRaw'] as String,
      valueNormalized: json['valueNormalized'] as String?,
      label: json['label'] as String? ?? 'mobile',
      customLabel: json['customLabel'] as String?,
      isPrimary: json['isPrimary'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class PortableEmail {
  final String id;
  final String value;
  final String label;
  final String? customLabel;
  final bool isPrimary;
  final int sortOrder;

  PortableEmail({
    required this.id,
    required this.value,
    this.label = 'home',
    this.customLabel,
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'label': label,
      'customLabel': customLabel,
      'isPrimary': isPrimary,
      'sortOrder': sortOrder,
    };
  }

  factory PortableEmail.fromJson(Map<String, dynamic> json) {
    return PortableEmail(
      id: json['id'] as String,
      value: json['value'] as String,
      label: json['label'] as String? ?? 'home',
      customLabel: json['customLabel'] as String?,
      isPrimary: json['isPrimary'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class PortableAddress {
  final String id;
  final String? label;
  final String? street;
  final String? number;
  final String? apartment;
  final String? postalCode;
  final String? city;
  final String? region;
  final String? country;
  final double? latitude;
  final double? longitude;
  final int sortOrder;

  PortableAddress({
    required this.id,
    this.label,
    this.street,
    this.number,
    this.apartment,
    this.postalCode,
    this.city,
    this.region,
    this.country,
    this.latitude,
    this.longitude,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'street': street,
      'number': number,
      'apartment': apartment,
      'postalCode': postalCode,
      'city': city,
      'region': region,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'sortOrder': sortOrder,
    };
  }

  factory PortableAddress.fromJson(Map<String, dynamic> json) {
    return PortableAddress(
      id: json['id'] as String,
      label: json['label'] as String?,
      street: json['street'] as String?,
      number: json['number'] as String?,
      apartment: json['apartment'] as String?,
      postalCode: json['postalCode'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      country: json['country'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class PortableSocialLink {
  final String id;
  final String type;
  final String value;
  final String? url;
  final String? label;
  final int sortOrder;

  PortableSocialLink({
    required this.id,
    required this.type,
    required this.value,
    this.url,
    this.label,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'value': value,
      'url': url,
      'label': label,
      'sortOrder': sortOrder,
    };
  }

  factory PortableSocialLink.fromJson(Map<String, dynamic> json) {
    return PortableSocialLink(
      id: json['id'] as String,
      type: json['type'] as String,
      value: json['value'] as String,
      url: json['url'] as String?,
      label: json['label'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class PortableOrganization {
  final String id;
  final String? company;
  final String? title;
  final String? department;
  final String? website;
  final String? notes;
  final bool isPrimary;
  final int sortOrder;

  PortableOrganization({
    required this.id,
    this.company,
    this.title,
    this.department,
    this.website,
    this.notes,
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company': company,
      'title': title,
      'department': department,
      'website': website,
      'notes': notes,
      'isPrimary': isPrimary,
      'sortOrder': sortOrder,
    };
  }

  factory PortableOrganization.fromJson(Map<String, dynamic> json) {
    return PortableOrganization(
      id: json['id'] as String,
      company: json['company'] as String?,
      title: json['title'] as String?,
      department: json['department'] as String?,
      website: json['website'] as String?,
      notes: json['notes'] as String?,
      isPrimary: json['isPrimary'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class PortableContactDate {
  final String id;
  final String type;
  final String? label;
  final DateTime date;
  final bool yearUnknown;
  final String recurrence;
  final int sortOrder;

  PortableContactDate({
    required this.id,
    this.type = 'birthday',
    this.label,
    required this.date,
    this.yearUnknown = false,
    this.recurrence = 'yearly',
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'label': label,
      'date': date.toIso8601String(),
      'yearUnknown': yearUnknown,
      'recurrence': recurrence,
      'sortOrder': sortOrder,
    };
  }

  factory PortableContactDate.fromJson(Map<String, dynamic> json) {
    return PortableContactDate(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'birthday',
      label: json['label'] as String?,
      date: DateTime.parse(json['date'] as String),
      yearUnknown: json['yearUnknown'] as bool? ?? false,
      recurrence: json['recurrence'] as String? ?? 'yearly',
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class PortableNote {
  final String id;
  final String content;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  PortableNote({
    required this.id,
    required this.content,
    this.source = 'manual',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PortableNote.fromJson(Map<String, dynamic> json) {
    return PortableNote(
      id: json['id'] as String,
      content: json['content'] as String,
      source: json['source'] as String? ?? 'manual',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class PortableCustomField {
  final String id;
  final String name;
  final String type;
  final String? value;
  final int sortOrder;

  PortableCustomField({
    required this.id,
    required this.name,
    this.type = 'text',
    this.value,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'value': value,
      'sortOrder': sortOrder,
    };
  }

  factory PortableCustomField.fromJson(Map<String, dynamic> json) {
    return PortableCustomField(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'text',
      value: json['value'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}
