import 'package:drift/drift.dart';

import '../../../../core/errors/nexo_exception.dart';
import '../../../../services/media/media_service.dart';
import '../../../../database/app_database.dart' as db;
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../services/contact_search_service.dart';

class ContactRepositoryImpl implements ContactRepository {
  final db.AppDatabase _db;
  final MediaService _media;
  final ContactSearchService? _search;

  ContactRepositoryImpl(this._db, this._media, [this._search]);

  // ---------- helpers ----------
  Contact _mapContact(db.Contact r) => Contact(
    id: r.id,
    givenName: r.givenName,
    middleName: r.middleName,
    familyName: r.familyName,
    prefix: r.prefix,
    suffix: r.suffix,
    phoneticGiven: r.phoneticGiven,
    phoneticFamily: r.phoneticFamily,
    nickname: r.nickname,
    photoPath: r.photoPath,
    photoHash: r.photoHash,
    isFavorite: r.isFavorite,
    favoriteMarkedAt: r.favoriteMarkedAt,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  Phone _mapPhone(db.Phone r) => Phone(
    id: r.id,
    contactId: r.contactId,
    valueRaw: r.valueRaw,
    valueNormalized: r.valueNormalized,
    label: r.label,
    isPrimary: r.isPrimary,
    sortOrder: r.sortOrder,
  );

  Email _mapEmail(db.Email r) => Email(
    id: r.id,
    contactId: r.contactId,
    value: r.value,
    label: r.label,
    isPrimary: r.isPrimary,
    sortOrder: r.sortOrder,
  );

  Address _mapAddress(db.AddressesData r) => Address(
    id: r.id,
    contactId: r.contactId,
    label: r.label,
    street: r.street,
    number: r.number,
    apartment: r.apartment,
    postalCode: r.postalCode,
    city: r.city,
    region: r.region,
    country: r.country,
    latitude: r.latitude,
    longitude: r.longitude,
    sortOrder: r.sortOrder,
  );

  SocialLink _mapSocial(db.SocialLink r) => SocialLink(
    id: r.id,
    contactId: r.contactId,
    type: r.type,
    value: r.value,
    url: r.url,
    label: r.label,
    sortOrder: r.sortOrder,
  );

  Organization _mapOrg(db.Organization r) => Organization(
    id: r.id,
    contactId: r.contactId,
    company: r.company,
    title: r.title,
    department: r.department,
    website: r.website,
    notes: r.notes,
    isPrimary: r.isPrimary,
    sortOrder: r.sortOrder,
  );

  ContactDate _mapDate(db.ContactDate r) => ContactDate(
    id: r.id,
    contactId: r.contactId,
    type: r.type,
    label: r.label,
    date: r.date,
    yearUnknown: r.yearUnknown,
    recurrence: r.recurrence,
    sortOrder: r.sortOrder,
  );

  Note _mapNote(db.Note r) => Note(
    id: r.id,
    contactId: r.contactId,
    content: r.content,
    source: r.source,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  CustomField _mapCustom(db.CustomField r) => CustomField(
    id: r.id,
    contactId: r.contactId,
    name: r.name,
    type: r.type,
    value: r.value,
    sortOrder: r.sortOrder,
  );

  void _validate(Contact c) {
    // Los nombres y apellidos admiten textos largos sin límites artificiales.
    // No se requiere nombre: un contacto puede tener solo teléfono, correo,
    // organización u otros datos. El nombre de presentación se deriva en
    // Contact.displayName.
  }

  String _normPhone(String v) => v.replaceAll(RegExp(r'[^0-9+]'), '');

  // ---------- create ----------
  @override
  Future<Contact> createContact(
    Contact contact, {
    List<Phone> phones = const [],
    List<Email> emails = const [],
    List<Address> addresses = const [],
    List<SocialLink> socialLinks = const [],
    List<Organization> organizations = const [],
    List<ContactDate> dates = const [],
    List<Note> notes = const [],
    List<CustomField> customFields = const [],
  }) async {
    _validate(contact);
    await _search?.ensureFtsTable();
    final created = await _db.transaction(() async {
      await _db
          .into(_db.contacts)
          .insert(
            db.ContactsCompanion.insert(
              id: contact.id,
              givenName: Value(contact.givenName),
              middleName: Value(contact.middleName),
              familyName: Value(contact.familyName),
              prefix: Value(contact.prefix),
              suffix: Value(contact.suffix),
              phoneticGiven: Value(contact.phoneticGiven),
              phoneticFamily: Value(contact.phoneticFamily),
              nickname: Value(contact.nickname),
              photoPath: Value(contact.photoPath),
              photoHash: Value(contact.photoHash),
              isFavorite: Value(contact.isFavorite),
              favoriteMarkedAt: Value(contact.favoriteMarkedAt),
              createdAt: Value(contact.createdAt),
              updatedAt: Value(contact.updatedAt),
            ),
          );
      var phonePrimarySet = false;
      for (final p in phones) {
        final isPrimary = p.isPrimary && !phonePrimarySet;
        if (isPrimary) {
          phonePrimarySet = true;
        }
        await _db
            .into(_db.phones)
            .insert(
              db.PhonesCompanion.insert(
                id: p.id,
                contactId: contact.id,
                valueRaw: p.valueRaw,
                valueNormalized: Value(
                  p.valueNormalized ?? _normPhone(p.valueRaw),
                ),
                label: Value(p.label),
                isPrimary: Value(isPrimary),
                sortOrder: Value(p.sortOrder),
              ),
            );
      }
      var emailPrimarySet = false;
      for (final e in emails) {
        final isPrimary = e.isPrimary && !emailPrimarySet;
        if (isPrimary) {
          emailPrimarySet = true;
        }
        await _db
            .into(_db.emails)
            .insert(
              db.EmailsCompanion.insert(
                id: e.id,
                contactId: contact.id,
                value: e.value,
                label: Value(e.label),
                isPrimary: Value(isPrimary),
                sortOrder: Value(e.sortOrder),
              ),
            );
      }
      for (final a in addresses) {
        await _db
            .into(_db.addresses)
            .insert(
              db.AddressesCompanion.insert(
                id: a.id,
                contactId: contact.id,
                label: Value(a.label),
                street: Value(a.street),
                number: Value(a.number),
                apartment: Value(a.apartment),
                postalCode: Value(a.postalCode),
                city: Value(a.city),
                region: Value(a.region),
                country: Value(a.country),
                latitude: Value(a.latitude),
                longitude: Value(a.longitude),
                sortOrder: Value(a.sortOrder),
              ),
            );
      }
      for (final s in socialLinks) {
        await _db
            .into(_db.socialLinks)
            .insert(
              db.SocialLinksCompanion.insert(
                id: s.id,
                contactId: contact.id,
                type: s.type,
                value: s.value,
                url: Value(s.url),
                label: Value(s.label),
                sortOrder: Value(s.sortOrder),
              ),
            );
      }
      // primary uniqueness for organizations
      var orgPrimarySet = false;
      for (final o in organizations) {
        final isPrimary = o.isPrimary && !orgPrimarySet;
        if (isPrimary) orgPrimarySet = true;
        await _db
            .into(_db.organizations)
            .insert(
              db.OrganizationsCompanion.insert(
                id: o.id,
                contactId: contact.id,
                company: Value(o.company),
                title: Value(o.title),
                department: Value(o.department),
                website: Value(o.website),
                notes: Value(o.notes),
                isPrimary: Value(isPrimary),
                sortOrder: Value(o.sortOrder),
              ),
            );
      }
      for (final d in dates) {
        await _db
            .into(_db.contactDates)
            .insert(
              db.ContactDatesCompanion.insert(
                id: d.id,
                contactId: contact.id,
                type: Value(d.type),
                label: Value(d.label),
                date: d.date,
                yearUnknown: Value(d.yearUnknown),
                recurrence: Value(d.recurrence),
                sortOrder: Value(d.sortOrder),
              ),
            );
      }
      for (final n in notes) {
        await _db
            .into(_db.notes)
            .insert(
              db.NotesCompanion.insert(
                id: n.id,
                contactId: contact.id,
                content: n.content,
                source: Value(n.source),
                createdAt: Value(n.createdAt),
                updatedAt: Value(n.updatedAt),
              ),
            );
      }
      for (final c in customFields) {
        await _db
            .into(_db.customFields)
            .insert(
              db.CustomFieldsCompanion.insert(
                id: c.id,
                contactId: contact.id,
                name: c.name,
                type: Value(c.type),
                value: Value(c.value),
                sortOrder: Value(c.sortOrder),
              ),
            );
      }
      await _search?.upsertWithinTransaction(contact.id);
      return contact;
    });
    return created;
  }

  // ---------- get ----------
  @override
  Future<Contact?> getContactById(String id) async {
    final row = await (_db.select(
      _db.contacts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapContact(row);
  }

  @override
  Future<ContactWithRelations?> getContactWithRelations(String id) async {
    final c = await getContactById(id);
    if (c == null) return null;
    final phones = (await (_db.select(
      _db.phones,
    )..where((t) => t.contactId.equals(id))).get()).map(_mapPhone).toList();
    final emails = (await (_db.select(
      _db.emails,
    )..where((t) => t.contactId.equals(id))).get()).map(_mapEmail).toList();
    final addresses = (await (_db.select(
      _db.addresses,
    )..where((t) => t.contactId.equals(id))).get()).map(_mapAddress).toList();
    final socials = (await (_db.select(
      _db.socialLinks,
    )..where((t) => t.contactId.equals(id))).get()).map(_mapSocial).toList();
    final orgs = (await (_db.select(
      _db.organizations,
    )..where((t) => t.contactId.equals(id))).get()).map(_mapOrg).toList();
    final dates = (await (_db.select(
      _db.contactDates,
    )..where((t) => t.contactId.equals(id))).get()).map(_mapDate).toList();
    final notes = (await (_db.select(
      _db.notes,
    )..where((t) => t.contactId.equals(id))).get()).map(_mapNote).toList();
    final customs = (await (_db.select(
      _db.customFields,
    )..where((t) => t.contactId.equals(id))).get()).map(_mapCustom).toList();
    return ContactWithRelations(
      contact: c,
      phones: phones,
      emails: emails,
      addresses: addresses,
      socialLinks: socials,
      organizations: orgs,
      dates: dates,
      notes: notes,
      customFields: customs,
    );
  }

  @override
  Future<List<Contact>> getAllContacts() async {
    final rows =
        await (_db.select(_db.contacts)..orderBy([
              (t) => OrderingTerm.asc(t.familyName),
              (t) => OrderingTerm.asc(t.givenName),
            ]))
            .get();
    return rows.map(_mapContact).toList();
  }

  /// Batch-fetch all contacts with all their relations in a single pass per
  /// relation type, avoiding N+1 queries. Used by export operations.
  @override
  Future<List<ContactWithRelations>> getAllContactsWithRelations() async {
    final contacts = await getAllContacts();
    if (contacts.isEmpty) return [];

    // Batch-fetch all relations for all contacts in single queries (no WHERE filter,
    // group by contactId in Dart).
    final phonesRows = await _db.select(_db.phones).get();
    final emailsRows = await _db.select(_db.emails).get();
    final addressesRows = await _db.select(_db.addresses).get();
    final socialsRows = await _db.select(_db.socialLinks).get();
    final orgsRows = await _db.select(_db.organizations).get();
    final datesRows = await _db.select(_db.contactDates).get();
    final notesRows = await _db.select(_db.notes).get();
    final customsRows = await _db.select(_db.customFields).get();

    // Group by contactId
    final phonesByContact = <String, List<db.Phone>>{};
    for (final p in phonesRows) {
      phonesByContact.putIfAbsent(p.contactId, () => []).add(p);
    }
    final emailsByContact = <String, List<db.Email>>{};
    for (final e in emailsRows) {
      emailsByContact.putIfAbsent(e.contactId, () => []).add(e);
    }
    final addressesByContact = <String, List<db.AddressesData>>{};
    for (final a in addressesRows) {
      addressesByContact.putIfAbsent(a.contactId, () => []).add(a);
    }
    final socialsByContact = <String, List<db.SocialLink>>{};
    for (final s in socialsRows) {
      socialsByContact.putIfAbsent(s.contactId, () => []).add(s);
    }
    final orgsByContact = <String, List<db.Organization>>{};
    for (final o in orgsRows) {
      orgsByContact.putIfAbsent(o.contactId, () => []).add(o);
    }
    final datesByContact = <String, List<db.ContactDate>>{};
    for (final d in datesRows) {
      datesByContact.putIfAbsent(d.contactId, () => []).add(d);
    }
    final notesByContact = <String, List<db.Note>>{};
    for (final n in notesRows) {
      notesByContact.putIfAbsent(n.contactId, () => []).add(n);
    }
    final customsByContact = <String, List<db.CustomField>>{};
    for (final c in customsRows) {
      customsByContact.putIfAbsent(c.contactId, () => []).add(c);
    }

    final result = <ContactWithRelations>[];
    for (final c in contacts) {
      result.add(ContactWithRelations(
        contact: c,
        phones: phonesByContact[c.id]?.map(_mapPhone).toList() ?? [],
        emails: emailsByContact[c.id]?.map(_mapEmail).toList() ?? [],
        addresses: addressesByContact[c.id]?.map(_mapAddress).toList() ?? [],
        socialLinks: socialsByContact[c.id]?.map(_mapSocial).toList() ?? [],
        organizations: orgsByContact[c.id]?.map(_mapOrg).toList() ?? [],
        dates: datesByContact[c.id]?.map(_mapDate).toList() ?? [],
        notes: notesByContact[c.id]?.map(_mapNote).toList() ?? [],
        customFields: customsByContact[c.id]?.map(_mapCustom).toList() ?? [],
      ));
    }
    return result;
  }

  @override
  Stream<List<Contact>> watchContacts() {
    final q = _db.select(_db.contacts)
      ..orderBy([
        (t) => OrderingTerm.asc(t.familyName),
        (t) => OrderingTerm.asc(t.givenName),
      ]);
    return q.watch().map((rows) => rows.map(_mapContact).toList());
  }

  @override
  Stream<Contact?> watchContactById(String id) {
    final q = _db.select(_db.contacts)..where((t) => t.id.equals(id));
    return q.watchSingleOrNull().map((r) => r == null ? null : _mapContact(r));
  }

  @override
  Future<List<Contact>> getRecentContacts({
    int days = 30,
    int limit = 20,
  }) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows =
        await (_db.select(_db.contacts)
              ..where((t) => t.updatedAt.isBiggerOrEqualValue(since))
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
              ..limit(limit))
            .get();
    return rows.map(_mapContact).toList();
  }

  @override
  Future<void> toggleFavorite(String id, bool value) async {
    await (_db.update(_db.contacts)..where((t) => t.id.equals(id))).write(
      db.ContactsCompanion(
        isFavorite: Value(value),
        favoriteMarkedAt: Value(value ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteContact(String id) async {
    final c = await getContactById(id);
    if (c == null) throw const NotFoundException('Contacto no encontrado');
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.delete(_db.contacts)..where((t) => t.id.equals(id))).go();
      await _search?.deleteWithinTransaction(id);
    });
    if (c.photoPath != null) {
      try {
        await _media.deleteContactFiles(id);
      } catch (e) {
        throw StorageException('No se pudieron eliminar los archivos del contacto: $e');
      }
    }
  }

  // ---------- update ----------
  @override
  Future<Contact> updateContact(
    Contact contact, {
    List<Phone>? phones,
    List<Email>? emails,
    List<Address>? addresses,
    List<SocialLink>? socialLinks,
    List<Organization>? organizations,
    List<ContactDate>? dates,
    List<Note>? notes,
    List<CustomField>? customFields,
  }) async {
    _validate(contact);
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.update(
        _db.contacts,
      )..where((t) => t.id.equals(contact.id))).write(
        db.ContactsCompanion(
          givenName: Value(contact.givenName),
          middleName: Value(contact.middleName),
          familyName: Value(contact.familyName),
          prefix: Value(contact.prefix),
          suffix: Value(contact.suffix),
          phoneticGiven: Value(contact.phoneticGiven),
          phoneticFamily: Value(contact.phoneticFamily),
          nickname: Value(contact.nickname),
          photoPath: Value(contact.photoPath),
          photoHash: Value(contact.photoHash),
          isFavorite: Value(contact.isFavorite),
          favoriteMarkedAt: Value(contact.favoriteMarkedAt),
          updatedAt: Value(DateTime.now()),
        ),
      );

      if (phones != null) {
        if (phones.any((p) => p.isPrimary)) {
          await (_db.update(_db.phones)..where((t) => t.contactId.equals(contact.id)))
              .write(const db.PhonesCompanion(isPrimary: Value(false)));
        }
        final existing = await (_db.select(
          _db.phones,
        )..where((t) => t.contactId.equals(contact.id))).get();
        final newIds = phones.map((p) => p.id).toSet();
        for (final e in existing) {
          if (!newIds.contains(e.id)) {
            await (_db.delete(
              _db.phones,
            )..where((t) => t.id.equals(e.id))).go();
          }
        }
        for (final p in phones) {
          final comp = db.PhonesCompanion(
            id: Value(p.id),
            contactId: Value(contact.id),
            valueRaw: Value(p.valueRaw),
            valueNormalized: Value(p.valueNormalized ?? _normPhone(p.valueRaw)),
            label: Value(p.label),
            isPrimary: Value(p.isPrimary),
            sortOrder: Value(p.sortOrder),
          );
          final exists = existing.any((e) => e.id == p.id);
          if (exists) {
            await (_db.update(
              _db.phones,
            )..where((t) => t.id.equals(p.id))).write(comp);
          } else {
            await _db.into(_db.phones).insert(comp);
          }
        }
        // ensure single primary
        await _ensureSinglePrimaryPhone(contact.id);
      }

      if (emails != null) {
        if (emails.any((e) => e.isPrimary)) {
          await (_db.update(_db.emails)..where((t) => t.contactId.equals(contact.id)))
              .write(const db.EmailsCompanion(isPrimary: Value(false)));
        }
        final existing = await (_db.select(
          _db.emails,
        )..where((t) => t.contactId.equals(contact.id))).get();
        final newIds = emails.map((e) => e.id).toSet();
        for (final e in existing) {
          if (!newIds.contains(e.id)) {
            await (_db.delete(
              _db.emails,
            )..where((t) => t.id.equals(e.id))).go();
          }
        }
        for (final e in emails) {
          final comp = db.EmailsCompanion(
            id: Value(e.id),
            contactId: Value(contact.id),
            value: Value(e.value),
            label: Value(e.label),
            isPrimary: Value(e.isPrimary),
            sortOrder: Value(e.sortOrder),
          );
          final exists = existing.any((x) => x.id == e.id);
          if (exists) {
            await (_db.update(
              _db.emails,
            )..where((t) => t.id.equals(e.id))).write(comp);
          } else {
            await _db.into(_db.emails).insert(comp);
          }
        }
        await _ensureSinglePrimaryEmail(contact.id);
      }

      if (organizations != null) {
        if (organizations.any((o) => o.isPrimary)) {
          await (_db.update(_db.organizations)..where((t) => t.contactId.equals(contact.id)))
              .write(const db.OrganizationsCompanion(isPrimary: Value(false)));
        }
        final existing = await (_db.select(
          _db.organizations,
        )..where((t) => t.contactId.equals(contact.id))).get();
        final newIds = organizations.map((o) => o.id).toSet();
        for (final e in existing) {
          if (!newIds.contains(e.id)) {
            await (_db.delete(
              _db.organizations,
            )..where((t) => t.id.equals(e.id))).go();
          }
        }
        for (final o in organizations) {
          final comp = db.OrganizationsCompanion(
            id: Value(o.id),
            contactId: Value(contact.id),
            company: Value(o.company),
            title: Value(o.title),
            department: Value(o.department),
            website: Value(o.website),
            notes: Value(o.notes),
            isPrimary: Value(o.isPrimary),
            sortOrder: Value(o.sortOrder),
          );
          final exists = existing.any((x) => x.id == o.id);
          if (exists) {
            await (_db.update(
              _db.organizations,
            )..where((t) => t.id.equals(o.id))).write(comp);
          } else {
            await _db.into(_db.organizations).insert(comp);
          }
        }
        await _ensureSinglePrimaryOrg(contact.id);
      }

      if (addresses != null) {
        final existing = await (_db.select(
          _db.addresses,
        )..where((t) => t.contactId.equals(contact.id))).get();
        final newIds = addresses.map((a) => a.id).toSet();
        for (final e in existing) {
          if (!newIds.contains(e.id)) {
            await (_db.delete(
              _db.addresses,
            )..where((t) => t.id.equals(e.id))).go();
          }
        }
        for (final a in addresses) {
          final comp = db.AddressesCompanion(
            id: Value(a.id),
            contactId: Value(contact.id),
            label: Value(a.label),
            street: Value(a.street),
            number: Value(a.number),
            apartment: Value(a.apartment),
            postalCode: Value(a.postalCode),
            city: Value(a.city),
            region: Value(a.region),
            country: Value(a.country),
            latitude: Value(a.latitude),
            longitude: Value(a.longitude),
            sortOrder: Value(a.sortOrder),
          );
          final exists = existing.any((x) => x.id == a.id);
          if (exists) {
            await (_db.update(
              _db.addresses,
            )..where((t) => t.id.equals(a.id))).write(comp);
          } else {
            await _db.into(_db.addresses).insert(comp);
          }
        }
      }

      if (socialLinks != null) {
        final existing = await (_db.select(
          _db.socialLinks,
        )..where((t) => t.contactId.equals(contact.id))).get();
        final newIds = socialLinks.map((s) => s.id).toSet();
        for (final e in existing) {
          if (!newIds.contains(e.id)) {
            await (_db.delete(
              _db.socialLinks,
            )..where((t) => t.id.equals(e.id))).go();
          }
        }
        for (final s in socialLinks) {
          final comp = db.SocialLinksCompanion(
            id: Value(s.id),
            contactId: Value(contact.id),
            type: Value(s.type),
            value: Value(s.value),
            url: Value(s.url),
            label: Value(s.label),
            sortOrder: Value(s.sortOrder),
          );
          final exists = existing.any((x) => x.id == s.id);
          if (exists) {
            await (_db.update(
              _db.socialLinks,
            )..where((t) => t.id.equals(s.id))).write(comp);
          } else {
            await _db.into(_db.socialLinks).insert(comp);
          }
        }
      }

      if (dates != null) {
        final existing = await (_db.select(
          _db.contactDates,
        )..where((t) => t.contactId.equals(contact.id))).get();
        final newIds = dates.map((d) => d.id).toSet();
        for (final e in existing) {
          if (!newIds.contains(e.id)) {
            await (_db.delete(
              _db.contactDates,
            )..where((t) => t.id.equals(e.id))).go();
          }
        }
        for (final d in dates) {
          final comp = db.ContactDatesCompanion(
            id: Value(d.id),
            contactId: Value(contact.id),
            type: Value(d.type),
            label: Value(d.label),
            date: Value(d.date),
            yearUnknown: Value(d.yearUnknown),
            recurrence: Value(d.recurrence),
            sortOrder: Value(d.sortOrder),
          );
          final exists = existing.any((x) => x.id == d.id);
          if (exists) {
            await (_db.update(
              _db.contactDates,
            )..where((t) => t.id.equals(d.id))).write(comp);
          } else {
            await _db.into(_db.contactDates).insert(comp);
          }
        }
      }

      if (notes != null) {
        final existing = await (_db.select(
          _db.notes,
        )..where((t) => t.contactId.equals(contact.id))).get();
        final newIds = notes.map((n) => n.id).toSet();
        for (final e in existing) {
          if (!newIds.contains(e.id)) {
            await (_db.delete(_db.notes)..where((t) => t.id.equals(e.id))).go();
          }
        }
        for (final n in notes) {
          final comp = db.NotesCompanion(
            id: Value(n.id),
            contactId: Value(contact.id),
            content: Value(n.content),
            source: Value(n.source),
            createdAt: Value(n.createdAt),
            updatedAt: Value(n.updatedAt),
          );
          final exists = existing.any((x) => x.id == n.id);
          if (exists) {
            await (_db.update(
              _db.notes,
            )..where((t) => t.id.equals(n.id))).write(comp);
          } else {
            await _db.into(_db.notes).insert(comp);
          }
        }
      }

      if (customFields != null) {
        final existing = await (_db.select(
          _db.customFields,
        )..where((t) => t.contactId.equals(contact.id))).get();
        final newIds = customFields.map((c) => c.id).toSet();
        for (final e in existing) {
          if (!newIds.contains(e.id)) {
            await (_db.delete(
              _db.customFields,
            )..where((t) => t.id.equals(e.id))).go();
          }
        }
        for (final c in customFields) {
          final comp = db.CustomFieldsCompanion(
            id: Value(c.id),
            contactId: Value(contact.id),
            name: Value(c.name),
            type: Value(c.type),
            value: Value(c.value),
            sortOrder: Value(c.sortOrder),
          );
          final exists = existing.any((x) => x.id == c.id);
          if (exists) {
            await (_db.update(
              _db.customFields,
            )..where((t) => t.id.equals(c.id))).write(comp);
          } else {
            await _db.into(_db.customFields).insert(comp);
          }
        }
      }

      await _search?.upsertWithinTransaction(contact.id);
      return contact;
    });
    return contact;
  }
  Future<void> _ensureSinglePrimaryPhone(String contactId) async {
    final rows =
        await (_db.select(_db.phones)..where(
              (t) => t.contactId.equals(contactId) & t.isPrimary.equals(true),
            ))
            .get();
    if (rows.length <= 1) return;
    // keep first, unset others
    bool first = true;
    for (final r in rows) {
      if (first) {
        first = false;
        continue;
      }
      await (_db.update(_db.phones)..where((t) => t.id.equals(r.id))).write(
        const db.PhonesCompanion(isPrimary: Value(false)),
      );
    }
  }

  Future<void> _ensureSinglePrimaryEmail(String contactId) async {
    final rows =
        await (_db.select(_db.emails)..where(
              (t) => t.contactId.equals(contactId) & t.isPrimary.equals(true),
            ))
            .get();
    if (rows.length <= 1) return;
    bool first = true;
    for (final r in rows) {
      if (first) {
        first = false;
        continue;
      }
      await (_db.update(_db.emails)..where((t) => t.id.equals(r.id))).write(
        const db.EmailsCompanion(isPrimary: Value(false)),
      );
    }
  }

  Future<void> _ensureSinglePrimaryOrg(String contactId) async {
    final rows =
        await (_db.select(_db.organizations)..where(
              (t) => t.contactId.equals(contactId) & t.isPrimary.equals(true),
            ))
            .get();
    if (rows.length <= 1) return;
    bool first = true;
    for (final r in rows) {
      if (first) {
        first = false;
        continue;
      }
      await (_db.update(_db.organizations)..where((t) => t.id.equals(r.id)))
          .write(const db.OrganizationsCompanion(isPrimary: Value(false)));
    }
  }

  // ---------- duplicate ----------
  @override
  Future<Contact> duplicateContact(String id) async {
    final cwr = await getContactWithRelations(id);
    if (cwr == null) throw const NotFoundException('Contacto no encontrado');
    final c = cwr.contact;
    final newContact = Contact(
      givenName: c.givenName,
      middleName: c.middleName,
      familyName: c.familyName,
      prefix: c.prefix,
      suffix: c.suffix,
      phoneticGiven: c.phoneticGiven,
      phoneticFamily: c.phoneticFamily,
      nickname: c.nickname,
      photoPath: c.photoPath,
      photoHash: c.photoHash,
      isFavorite: false,
    );
    // copy photo file safely
    String? newPhotoPath;
    String? newPhotoHash;
    if (c.photoPath != null) {
      final file = await _media.resolve(c.photoPath!);
      if (file == null) {
        throw const StorageException('No se encontró la fotografía original');
      }
      final bytes = await file.readAsBytes();
      newPhotoPath = await _media.savePhoto(newContact.id, bytes);
      newPhotoHash = _media.sha256Of(bytes);
    }
    final contactToSave = newContact.copyWith(
      photoPath: newPhotoPath,
      photoHash: newPhotoHash,
    );

    final phones = cwr.phones
        .map(
          (p) => Phone(
            contactId: newContact.id,
            valueRaw: p.valueRaw,
            valueNormalized: p.valueNormalized,
            label: p.label,
            isPrimary: p.isPrimary,
            sortOrder: p.sortOrder,
          ),
        )
        .toList();
    final emails = cwr.emails
        .map(
          (e) => Email(
            contactId: newContact.id,
            value: e.value,
            label: e.label,
            isPrimary: e.isPrimary,
            sortOrder: e.sortOrder,
          ),
        )
        .toList();
    final addresses = cwr.addresses
        .map(
          (a) => Address(
            contactId: newContact.id,
            label: a.label,
            street: a.street,
            number: a.number,
            apartment: a.apartment,
            postalCode: a.postalCode,
            city: a.city,
            region: a.region,
            country: a.country,
            latitude: a.latitude,
            longitude: a.longitude,
            sortOrder: a.sortOrder,
          ),
        )
        .toList();
    final socials = cwr.socialLinks
        .map(
          (s) => SocialLink(
            contactId: newContact.id,
            type: s.type,
            value: s.value,
            url: s.url,
            label: s.label,
            sortOrder: s.sortOrder,
          ),
        )
        .toList();
    final orgs = cwr.organizations
        .map(
          (o) => Organization(
            contactId: newContact.id,
            company: o.company,
            title: o.title,
            department: o.department,
            website: o.website,
            notes: o.notes,
            isPrimary: o.isPrimary,
            sortOrder: o.sortOrder,
          ),
        )
        .toList();
    final dates = cwr.dates
        .map(
          (d) => ContactDate(
            contactId: newContact.id,
            type: d.type,
            label: d.label,
            date: d.date,
            yearUnknown: d.yearUnknown,
            recurrence: d.recurrence,
            sortOrder: d.sortOrder,
          ),
        )
        .toList();
    final notes = cwr.notes
        .map((n) => Note(contactId: newContact.id, content: n.content, source: n.source))
        .toList();
    final customs = cwr.customFields
        .map(
          (c) => CustomField(
            contactId: newContact.id,
            name: c.name,
            type: c.type,
            value: c.value,
            sortOrder: c.sortOrder,
          ),
        )
        .toList();

    try {
      return await createContact(
        contactToSave,
        phones: phones,
        emails: emails,
        addresses: addresses,
        socialLinks: socials,
        organizations: orgs,
        dates: dates,
        notes: notes,
        customFields: customs,
      );
    } catch (e) {
      if (newPhotoPath != null) {
        try {
          await _media.deleteContactFiles(newContact.id);
        } catch (_) {}
      }
      rethrow;
    }
  }

  // ---------- children CRUD ----------
  @override
  Future<Phone> addPhone(Phone phone) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      if (phone.isPrimary) {
        await (_db.update(_db.phones)..where((t) => t.contactId.equals(phone.contactId)))
            .write(const db.PhonesCompanion(isPrimary: Value(false)));
      }
      await _db
          .into(_db.phones)
          .insert(
            db.PhonesCompanion.insert(
              id: phone.id,
              contactId: phone.contactId,
              valueRaw: phone.valueRaw,
              valueNormalized: Value(
                phone.valueNormalized ?? _normPhone(phone.valueRaw),
              ),
              label: Value(phone.label),
              isPrimary: Value(phone.isPrimary),
              sortOrder: Value(phone.sortOrder),
            ),
          );
      if (phone.isPrimary) await _ensureSinglePrimaryPhone(phone.contactId);
      await _search?.upsertWithinTransaction(phone.contactId);
    });
    return phone;
  }

  @override
  Future<void> updatePhone(Phone phone) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      if (phone.isPrimary) {
        await (_db.update(_db.phones)..where((t) => t.contactId.equals(phone.contactId)))
            .write(const db.PhonesCompanion(isPrimary: Value(false)));
      }
      await (_db.update(_db.phones)..where((t) => t.id.equals(phone.id))).write(
        db.PhonesCompanion(
          valueRaw: Value(phone.valueRaw),
          valueNormalized: Value(
            phone.valueNormalized ?? _normPhone(phone.valueRaw),
          ),
          label: Value(phone.label),
          isPrimary: Value(phone.isPrimary),
          sortOrder: Value(phone.sortOrder),
        ),
      );
      if (phone.isPrimary) await _ensureSinglePrimaryPhone(phone.contactId);
      await _search?.upsertWithinTransaction(phone.contactId);
    });
  }

  @override
  Future<void> deletePhone(String id) async {
    await _search?.ensureFtsTable();
    String? contactId;
    await _db.transaction(() async {
      final row = await (_db.select(_db.phones)..where((t) => t.id.equals(id))).getSingleOrNull();
      contactId = row?.contactId;
      await (_db.delete(_db.phones)..where((t) => t.id.equals(id))).go();
      if (contactId != null) await _search?.upsertWithinTransaction(contactId!);
    });
  }

  @override
  Future<void> setPrimaryPhone(String contactId, String phoneId) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.update(_db.phones)..where((t) => t.contactId.equals(contactId)))
          .write(const db.PhonesCompanion(isPrimary: Value(false)));
      await (_db.update(_db.phones)..where((t) => t.id.equals(phoneId))).write(
        const db.PhonesCompanion(isPrimary: Value(true)),
      );
      await _search?.upsertWithinTransaction(contactId);
    });
  }

  @override
  Future<Email> addEmail(Email email) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      if (email.isPrimary) {
        await (_db.update(_db.emails)..where((t) => t.contactId.equals(email.contactId)))
            .write(const db.EmailsCompanion(isPrimary: Value(false)));
      }
      await _db
          .into(_db.emails)
          .insert(
            db.EmailsCompanion.insert(
              id: email.id,
              contactId: email.contactId,
              value: email.value,
              label: Value(email.label),
              isPrimary: Value(email.isPrimary),
              sortOrder: Value(email.sortOrder),
            ),
          );
      if (email.isPrimary) await _ensureSinglePrimaryEmail(email.contactId);
      await _search?.upsertWithinTransaction(email.contactId);
    });
    return email;
  }

  @override
  Future<void> updateEmail(Email email) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      if (email.isPrimary) {
        await (_db.update(_db.emails)..where((t) => t.contactId.equals(email.contactId)))
            .write(const db.EmailsCompanion(isPrimary: Value(false)));
      }
      await (_db.update(_db.emails)..where((t) => t.id.equals(email.id))).write(
        db.EmailsCompanion(
          value: Value(email.value),
          label: Value(email.label),
          isPrimary: Value(email.isPrimary),
          sortOrder: Value(email.sortOrder),
        ),
      );
      if (email.isPrimary) await _ensureSinglePrimaryEmail(email.contactId);
      await _search?.upsertWithinTransaction(email.contactId);
    });
  }

  @override
  Future<void> deleteEmail(String id) async {
    await _search?.ensureFtsTable();
    String? contactId;
    await _db.transaction(() async {
      final row = await (_db.select(_db.emails)..where((t) => t.id.equals(id))).getSingleOrNull();
      contactId = row?.contactId;
      await (_db.delete(_db.emails)..where((t) => t.id.equals(id))).go();
      if (contactId != null) await _search?.upsertWithinTransaction(contactId!);
    });
  }

  @override
  Future<void> setPrimaryEmail(String contactId, String emailId) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.update(_db.emails)..where((t) => t.contactId.equals(contactId)))
          .write(const db.EmailsCompanion(isPrimary: Value(false)));
      await (_db.update(_db.emails)..where((t) => t.id.equals(emailId))).write(
        const db.EmailsCompanion(isPrimary: Value(true)),
      );
      await _search?.upsertWithinTransaction(contactId);
    });
  }

  @override
  Future<Organization> addOrganization(Organization org) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      if (org.isPrimary) {
        await (_db.update(_db.organizations)..where((t) => t.contactId.equals(org.contactId)))
            .write(const db.OrganizationsCompanion(isPrimary: Value(false)));
      }
      await _db
          .into(_db.organizations)
          .insert(
            db.OrganizationsCompanion.insert(
              id: org.id,
              contactId: org.contactId,
              company: Value(org.company),
              title: Value(org.title),
              department: Value(org.department),
              website: Value(org.website),
              notes: Value(org.notes),
              isPrimary: Value(org.isPrimary),
              sortOrder: Value(org.sortOrder),
            ),
          );
      if (org.isPrimary) await _ensureSinglePrimaryOrg(org.contactId);
      await _search?.upsertWithinTransaction(org.contactId);
    });
    return org;
  }

  @override
  Future<void> updateOrganization(Organization org) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      if (org.isPrimary) {
        await (_db.update(_db.organizations)..where((t) => t.contactId.equals(org.contactId)))
            .write(const db.OrganizationsCompanion(isPrimary: Value(false)));
      }
      await (_db.update(
        _db.organizations,
      )..where((t) => t.id.equals(org.id))).write(
        db.OrganizationsCompanion(
          company: Value(org.company),
          title: Value(org.title),
          department: Value(org.department),
          website: Value(org.website),
          notes: Value(org.notes),
          isPrimary: Value(org.isPrimary),
          sortOrder: Value(org.sortOrder),
        ),
      );
      if (org.isPrimary) await _ensureSinglePrimaryOrg(org.contactId);
      await _search?.upsertWithinTransaction(org.contactId);
    });
  }

  @override
  Future<void> deleteOrganization(String id) async {
    await _search?.ensureFtsTable();
    String? contactId;
    await _db.transaction(() async {
      final row = await (_db.select(_db.organizations)..where((t) => t.id.equals(id))).getSingleOrNull();
      contactId = row?.contactId;
      await (_db.delete(_db.organizations)..where((t) => t.id.equals(id))).go();
      if (contactId != null) await _search?.upsertWithinTransaction(contactId!);
    });
  }

  @override
  Future<void> setPrimaryOrganization(String contactId, String orgId) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.update(_db.organizations)..where((t) => t.contactId.equals(contactId)))
          .write(const db.OrganizationsCompanion(isPrimary: Value(false)));
      await (_db.update(_db.organizations)..where((t) => t.id.equals(orgId))).write(
        const db.OrganizationsCompanion(isPrimary: Value(true)),
      );
      await _search?.upsertWithinTransaction(contactId);
    });
  }

  @override
  Future<Address> addAddress(Address address) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await _db
          .into(_db.addresses)
          .insert(
            db.AddressesCompanion.insert(
              id: address.id,
              contactId: address.contactId,
              label: Value(address.label),
              street: Value(address.street),
              number: Value(address.number),
              apartment: Value(address.apartment),
              postalCode: Value(address.postalCode),
              city: Value(address.city),
              region: Value(address.region),
              country: Value(address.country),
              latitude: Value(address.latitude),
              longitude: Value(address.longitude),
              sortOrder: Value(address.sortOrder),
            ),
          );
      await _search?.upsertWithinTransaction(address.contactId);
    });
    return address;
  }

  @override
  Future<void> updateAddress(Address address) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.update(
        _db.addresses,
      )..where((t) => t.id.equals(address.id))).write(
        db.AddressesCompanion(
          label: Value(address.label),
          street: Value(address.street),
          number: Value(address.number),
          apartment: Value(address.apartment),
          postalCode: Value(address.postalCode),
          city: Value(address.city),
          region: Value(address.region),
          country: Value(address.country),
          latitude: Value(address.latitude),
          longitude: Value(address.longitude),
          sortOrder: Value(address.sortOrder),
        ),
      );
      await _search?.upsertWithinTransaction(address.contactId);
    });
  }

  @override
  Future<void> deleteAddress(String id) async {
    await _search?.ensureFtsTable();
    String? contactId;
    await _db.transaction(() async {
      final row = await (_db.select(_db.addresses)..where((t) => t.id.equals(id))).getSingleOrNull();
      contactId = row?.contactId;
      await (_db.delete(_db.addresses)..where((t) => t.id.equals(id))).go();
      if (contactId != null) await _search?.upsertWithinTransaction(contactId!);
    });
  }

  @override
  Future<SocialLink> addSocialLink(SocialLink link) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await _db
          .into(_db.socialLinks)
          .insert(
            db.SocialLinksCompanion.insert(
              id: link.id,
              contactId: link.contactId,
              type: link.type,
              value: link.value,
              url: Value(link.url),
              label: Value(link.label),
              sortOrder: Value(link.sortOrder),
            ),
          );
      await _search?.upsertWithinTransaction(link.contactId);
    });
    return link;
  }

  @override
  Future<void> updateSocialLink(SocialLink link) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.update(
        _db.socialLinks,
      )..where((t) => t.id.equals(link.id))).write(
        db.SocialLinksCompanion(
          type: Value(link.type),
          value: Value(link.value),
          url: Value(link.url),
          label: Value(link.label),
          sortOrder: Value(link.sortOrder),
        ),
      );
      await _search?.upsertWithinTransaction(link.contactId);
    });
  }

  @override
  Future<void> deleteSocialLink(String id) async {
    await _search?.ensureFtsTable();
    String? contactId;
    await _db.transaction(() async {
      final row = await (_db.select(_db.socialLinks)..where((t) => t.id.equals(id))).getSingleOrNull();
      contactId = row?.contactId;
      await (_db.delete(_db.socialLinks)..where((t) => t.id.equals(id))).go();
      if (contactId != null) await _search?.upsertWithinTransaction(contactId!);
    });
  }

  @override
  Future<Note> addNote(Note note) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await _db
          .into(_db.notes)
          .insert(
            db.NotesCompanion.insert(
              id: note.id,
              contactId: note.contactId,
              content: note.content,
              source: Value(note.source),
              createdAt: Value(note.createdAt),
              updatedAt: Value(note.updatedAt),
            ),
          );
      await _search?.upsertWithinTransaction(note.contactId);
    });
    return note;
  }

  @override
  Future<void> updateNote(Note note) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((t) => t.id.equals(note.id))).write(
        db.NotesCompanion(
          content: Value(note.content),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _search?.upsertWithinTransaction(note.contactId);
    });
  }

  @override
  Future<void> deleteNote(String id) async {
    await _search?.ensureFtsTable();
    String? contactId;
    await _db.transaction(() async {
      final row = await (_db.select(_db.notes)..where((t) => t.id.equals(id))).getSingleOrNull();
      contactId = row?.contactId;
      await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
      if (contactId != null) await _search?.upsertWithinTransaction(contactId!);
    });
  }

  @override
  Future<CustomField> addCustomField(CustomField field) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await _db
          .into(_db.customFields)
          .insert(
            db.CustomFieldsCompanion.insert(
              id: field.id,
              contactId: field.contactId,
              name: field.name,
              type: Value(field.type),
              value: Value(field.value),
              sortOrder: Value(field.sortOrder),
            ),
          );
      await _search?.upsertWithinTransaction(field.contactId);
    });
    return field;
  }

  @override
  Future<void> updateCustomField(CustomField field) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.update(
        _db.customFields,
      )..where((t) => t.id.equals(field.id))).write(
        db.CustomFieldsCompanion(
          name: Value(field.name),
          type: Value(field.type),
          value: Value(field.value),
          sortOrder: Value(field.sortOrder),
        ),
      );
      await _search?.upsertWithinTransaction(field.contactId);
    });
  }

  @override
  Future<void> deleteCustomField(String id) async {
    await _search?.ensureFtsTable();
    String? contactId;
    await _db.transaction(() async {
      final row = await (_db.select(_db.customFields)..where((t) => t.id.equals(id))).getSingleOrNull();
      contactId = row?.contactId;
      await (_db.delete(_db.customFields)..where((t) => t.id.equals(id))).go();
      if (contactId != null) await _search?.upsertWithinTransaction(contactId!);
    });
  }

  @override
  Future<ContactDate> addContactDate(ContactDate date) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await _db
          .into(_db.contactDates)
          .insert(
            db.ContactDatesCompanion.insert(
              id: date.id,
              contactId: date.contactId,
              type: Value(date.type),
              label: Value(date.label),
              date: date.date,
              yearUnknown: Value(date.yearUnknown),
              recurrence: Value(date.recurrence),
              sortOrder: Value(date.sortOrder),
            ),
          );
      await _search?.upsertWithinTransaction(date.contactId);
    });
    return date;
  }

  @override
  Future<void> updateContactDate(ContactDate date) async {
    await _search?.ensureFtsTable();
    await _db.transaction(() async {
      await (_db.update(
        _db.contactDates,
      )..where((t) => t.id.equals(date.id))).write(
        db.ContactDatesCompanion(
          type: Value(date.type),
          label: Value(date.label),
          date: Value(date.date),
          yearUnknown: Value(date.yearUnknown),
          recurrence: Value(date.recurrence),
          sortOrder: Value(date.sortOrder),
        ),
      );
      await _search?.upsertWithinTransaction(date.contactId);
    });
  }

  @override
  Future<void> deleteContactDate(String id) async {
    await _search?.ensureFtsTable();
    String? contactId;
    await _db.transaction(() async {
      final row = await (_db.select(_db.contactDates)..where((t) => t.id.equals(id))).getSingleOrNull();
      contactId = row?.contactId;
      await (_db.delete(_db.contactDates)..where((t) => t.id.equals(id))).go();
      if (contactId != null) await _search?.upsertWithinTransaction(contactId!);
    });
  }

  @override
  Future<List<ContactDate>> getContactDates(String contactId) async {
    final rows = await (_db.select(_db.contactDates)..where((t) => t.contactId.equals(contactId))).get();
    return rows.map(_mapDate).toList();
  }

  @override
  Future<List<ContactDate>> getContactDatesByMonthDay(int month, int day) async {
    final rows = await _db.select(_db.contactDates).get();
    return rows.where((r) => r.date.month == month && r.date.day == day).map(_mapDate).toList();
  }

  @override
  Future<void> updateContactPhotoPath(String contactId, String photoPath) async {
    await (_db.update(_db.contacts)..where((t) => t.id.equals(contactId))).write(
      db.ContactsCompanion(
        photoPath: Value(photoPath),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}




