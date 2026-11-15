import 'package:drift/drift.dart';

// ---------- Contact ----------
class Contacts extends Table {
  TextColumn get id => text()();
  TextColumn get givenName => text().nullable()();
  TextColumn get middleName => text().nullable()();
  TextColumn get familyName => text().nullable()();
  TextColumn get prefix => text().nullable()();
  TextColumn get suffix => text().nullable()();
  TextColumn get phoneticGiven => text().nullable()();
  TextColumn get phoneticFamily => text().nullable()();
  TextColumn get nickname => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get photoHash => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get favoriteMarkedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Phone ----------
class Phones extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get valueRaw => text()();
  TextColumn get valueNormalized => text().nullable()();
  TextColumn get label => text().withDefault(const Constant('mobile'))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Email ----------
class Emails extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get value => text()();
  TextColumn get label => text().withDefault(const Constant('home'))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Address ----------
class Addresses extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text().nullable()();
  TextColumn get street => text().nullable()();
  TextColumn get number => text().nullable()();
  TextColumn get apartment => text().nullable()();
  TextColumn get postalCode => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get country => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- SocialLink ----------
class SocialLinks extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get value => text()();
  TextColumn get url => text().nullable()();
  TextColumn get label => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Organization ----------
class Organizations extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get company => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get department => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- ContactDate ----------
class ContactDates extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text().withDefault(const Constant('birthday'))();
  TextColumn get label => text().nullable()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get yearUnknown => boolean().withDefault(const Constant(false))();
  TextColumn get recurrence => text().withDefault(const Constant('yearly'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Note ----------
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- CustomField ----------
class CustomFields extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('text'))();
  TextColumn get value => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Tag ----------
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- ContactTag ----------
class ContactTags extends Table {
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {contactId, tagId};
}

// ---------- Collection ----------
class Collections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- CollectionContact ----------
class CollectionContacts extends Table {
  TextColumn get collectionId =>
      text().references(Collections, #id, onDelete: KeyAction.cascade)();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {collectionId, contactId};
}

// ---------- AppSettings ----------
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {key};
}

// ---------- ContactExtra ----------
class ContactExtras extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get source => text()();
  TextColumn get dataType => text()();
  TextColumn get provenance => text().nullable()();
  TextColumn get payload => text()(); // JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------- ImportProvenance ----------
class ImportProvenances extends Table {
  TextColumn get id => text()();
  TextColumn get contactId =>
      text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceType => text()(); // android, vcf, csv, json, backup
  TextColumn get originKey =>
      text()(); // normalized unique source identity (non-null)
  TextColumn get accountType => text().nullable()();
  TextColumn get accountName => text().nullable()();
  TextColumn get rawContactId => text().nullable()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get rawContactIds => text().nullable()(); // JSON array
  TextColumn get fileHash => text().nullable()();
  IntColumn get recordIndex => integer().nullable()();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {originKey},
  ];
}
