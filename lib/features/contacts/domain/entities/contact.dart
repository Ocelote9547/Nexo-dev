import 'package:uuid/uuid.dart';

class Contact {
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
  final bool isFavorite;
  final DateTime? favoriteMarkedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Contact({
    String? id,
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
    this.isFavorite = false,
    this.favoriteMarkedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get displayName {
    final parts = [
      prefix,
      givenName,
      middleName,
      familyName,
      suffix,
    ].where((e) => e != null && e.trim().isNotEmpty).join(' ');
    if (parts.isNotEmpty) return parts;
    if (nickname != null && nickname!.trim().isNotEmpty) return nickname!;
    return 'Contacto sin nombre';
  }

  bool get hasName =>
      (givenName != null && givenName!.trim().isNotEmpty) ||
      (familyName != null && familyName!.trim().isNotEmpty);

  Contact copyWith({
    String? givenName,
    String? middleName,
    String? familyName,
    String? prefix,
    String? suffix,
    String? phoneticGiven,
    String? phoneticFamily,
    String? nickname,
    String? photoPath,
    String? photoHash,
    bool? isFavorite,
    DateTime? favoriteMarkedAt,
    DateTime? updatedAt,
  }) => Contact(
    id: id,
    givenName: givenName ?? this.givenName,
    middleName: middleName ?? this.middleName,
    familyName: familyName ?? this.familyName,
    prefix: prefix ?? this.prefix,
    suffix: suffix ?? this.suffix,
    phoneticGiven: phoneticGiven ?? this.phoneticGiven,
    phoneticFamily: phoneticFamily ?? this.phoneticFamily,
    nickname: nickname ?? this.nickname,
    photoPath: photoPath ?? this.photoPath,
    photoHash: photoHash ?? this.photoHash,
    isFavorite: isFavorite ?? this.isFavorite,
    favoriteMarkedAt: favoriteMarkedAt ?? this.favoriteMarkedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

class Phone {
  final String id;
  final String contactId;
  final String valueRaw;
  final String? valueNormalized;
  final String label;
  final String? customLabel;
  final bool isPrimary;
  final int sortOrder;
  Phone({
    String? id,
    required this.contactId,
    required this.valueRaw,
    this.valueNormalized,
    this.label = 'mobile',
    this.customLabel,
    this.isPrimary = false,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  Phone copyWith({String? valueRaw, String? valueNormalized, String? label, bool? isPrimary, int? sortOrder}) =>
      Phone(id: id, contactId: contactId, valueRaw: valueRaw ?? this.valueRaw, valueNormalized: valueNormalized ?? this.valueNormalized, label: label ?? this.label, isPrimary: isPrimary ?? this.isPrimary, sortOrder: sortOrder ?? this.sortOrder);
}

class Email {
  final String id;
  final String contactId;
  final String value;
  final String label;
  final String? customLabel;
  final bool isPrimary;
  final int sortOrder;
  Email({
    String? id,
    required this.contactId,
    required this.value,
    this.label = 'home',
    this.customLabel,
    this.isPrimary = false,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  Email copyWith({String? value, String? label, bool? isPrimary, int? sortOrder}) =>
      Email(id: id, contactId: contactId, value: value ?? this.value, label: label ?? this.label, isPrimary: isPrimary ?? this.isPrimary, sortOrder: sortOrder ?? this.sortOrder);
}

class Address {
  final String id;
  final String contactId;
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
  Address({
    String? id,
    required this.contactId,
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
  }) : id = id ?? const Uuid().v4();

  Address copyWith({String? label, String? street, String? number, String? apartment, String? postalCode, String? city, String? region, String? country, double? latitude, double? longitude, int? sortOrder}) =>
      Address(id: id, contactId: contactId, label: label ?? this.label, street: street ?? this.street, number: number ?? this.number, apartment: apartment ?? this.apartment, postalCode: postalCode ?? this.postalCode, city: city ?? this.city, region: region ?? this.region, country: country ?? this.country, latitude: latitude ?? this.latitude, longitude: longitude ?? this.longitude, sortOrder: sortOrder ?? this.sortOrder);
}

class SocialLink {
  final String id;
  final String contactId;
  final String type;
  final String value;
  final String? url;
  final String? label;
  final int sortOrder;
  SocialLink({
    String? id,
    required this.contactId,
    required this.type,
    required this.value,
    this.url,
    this.label,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  SocialLink copyWith({String? type, String? value, String? url, String? label, int? sortOrder}) =>
      SocialLink(id: id, contactId: contactId, type: type ?? this.type, value: value ?? this.value, url: url ?? this.url, label: label ?? this.label, sortOrder: sortOrder ?? this.sortOrder);
}

class Organization {
  final String id;
  final String contactId;
  final String? company;
  final String? title;
  final String? department;
  final String? website;
  final String? notes;
  final bool isPrimary;
  final int sortOrder;
  Organization({
    String? id,
    required this.contactId,
    this.company,
    this.title,
    this.department,
    this.website,
    this.notes,
    this.isPrimary = false,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  Organization copyWith({String? company, String? title, String? department, String? website, String? notes, bool? isPrimary, int? sortOrder}) =>
      Organization(id: id, contactId: contactId, company: company ?? this.company, title: title ?? this.title, department: department ?? this.department, website: website ?? this.website, notes: notes ?? this.notes, isPrimary: isPrimary ?? this.isPrimary, sortOrder: sortOrder ?? this.sortOrder);
}

class ContactDate {
  final String id;
  final String contactId;
  final String type;
  final String? label;
  final DateTime date;
  final bool yearUnknown;
  final String recurrence;
  final int sortOrder;
  ContactDate({
    String? id,
    required this.contactId,
    this.type = 'birthday',
    this.label,
    required this.date,
    this.yearUnknown = false,
    this.recurrence = 'yearly',
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  ContactDate copyWith({String? type, String? label, DateTime? date, bool? yearUnknown, String? recurrence, int? sortOrder}) =>
      ContactDate(id: id, contactId: contactId, type: type ?? this.type, label: label ?? this.label, date: date ?? this.date, yearUnknown: yearUnknown ?? this.yearUnknown, recurrence: recurrence ?? this.recurrence, sortOrder: sortOrder ?? this.sortOrder);

  /// Devuelve la fecha de cumpleaños formateada para mostrar.
  /// Si yearUnknown es true, muestra solo día y mes (sin el año auxiliar 2000).
  String get displayDate {
    if (yearUnknown) {
      return '${date.day}/${date.month}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

class Note {
  final String id;
  final String contactId;
  final String content;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  Note({
    String? id,
    required this.contactId,
    required this.content,
    this.source = 'manual',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Note copyWith({String? content, String? source, DateTime? updatedAt}) =>
      Note(id: id, contactId: contactId, content: content ?? this.content, source: source ?? this.source, createdAt: createdAt, updatedAt: updatedAt ?? DateTime.now());
}

class CustomField {
  final String id;
  final String contactId;
  final String name;
  final String type;
  final String? value;
  final int sortOrder;
  CustomField({
    String? id,
    required this.contactId,
    required this.name,
    this.type = 'text',
    this.value,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  CustomField copyWith({String? name, String? type, String? value, int? sortOrder}) =>
      CustomField(id: id, contactId: contactId, name: name ?? this.name, type: type ?? this.type, value: value ?? this.value, sortOrder: sortOrder ?? this.sortOrder);
}

class ContactWithRelations {
  final Contact contact;
  final List<Phone> phones;
  final List<Email> emails;
  final List<Address> addresses;
  final List<SocialLink> socialLinks;
  final List<Organization> organizations;
  final List<ContactDate> dates;
  final List<Note> notes;
  final List<CustomField> customFields;
  ContactWithRelations({
    required this.contact,
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
    this.socialLinks = const [],
    this.organizations = const [],
    this.dates = const [],
    this.notes = const [],
    this.customFields = const [],
  });
}
