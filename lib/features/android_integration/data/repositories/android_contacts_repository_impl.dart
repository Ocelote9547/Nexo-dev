import 'dart:typed_data';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image/image.dart' as img;

import '../../../../core/errors/nexo_exception.dart';
import '../../domain/entities/android_contact.dart';
import '../../domain/repositories/android_contacts_repository.dart';

/// Implementation of [AndroidContactsRepository] using the flutter_contacts
/// plugin, which wraps Android Contacts Provider.
///
/// All operations are explicit and user-initiated. No automatic
/// synchronization or background operations are performed.
class AndroidContactsRepositoryImpl implements AndroidContactsRepository {
  // ---------- Permissions ----------

  @override
  Future<bool> hasReadPermission() async {
    try {
      return await FlutterContacts.permissions.has(PermissionType.read);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestReadPermission() async {
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      return status == PermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasWritePermission() async {
    try {
      return await FlutterContacts.permissions.has(PermissionType.write);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestWritePermission() async {
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.write);
      return status == PermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  // ---------- Accounts ----------

  @override
  Future<List<AndroidAccount>> getAccounts() async {
    try {
      final accounts = await FlutterContacts.accounts.getAll();
      return accounts
          .map((a) => AndroidAccount(name: a.name, type: a.type))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------- Contacts (read) ----------

  @override
  Future<List<AndroidContact>> getContacts({
    AndroidAccount? account,
    String? query,
  }) async {
    try {
      ContactFilter? filter;
      if (query != null && query.isNotEmpty) {
        filter = ContactFilter.name(query);
      }

      final flutterContacts = await FlutterContacts.getAll(
        properties: ContactProperties.all,
        filter: filter,
        account: account != null
            ? Account(id: '', name: account.name, type: account.type)
            : null,
      );

      return flutterContacts
          .map((fc) => _mapFlutterContactToAndroid(fc))
          .toList();
    } catch (e) {
      throw DatabaseException('Failed to read Android contacts: $e');
    }
  }

  @override
  Future<AndroidContact?> getContactById(String androidContactId) async {
    try {
      final fc = await FlutterContacts.get(
        androidContactId,
        properties: ContactProperties.all,
      );
      if (fc == null) return null;

      return _mapFlutterContactToAndroid(fc);
    } catch (e) {
      throw DatabaseException(
        'Failed to read Android contact $androidContactId: $e',
      );
    }
  }

  // ---------- Contacts (write/export) ----------

  @override
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
    List<int>? photoBytes,
    String? photoMimeType,
  }) async {
    try {
      final hasWrite = await requestWritePermission();
      if (!hasWrite) {
        return AndroidExportResult(
          nexoContactId: nexoContactId,
          errors: ['WRITE_CONTACTS permission denied'],
        );
      }

      Photo? contactPhoto;
      if (photoBytes != null && photoBytes.isNotEmpty) {
        try {
          final decoded = img.decodeImage(Uint8List.fromList(photoBytes));
          if (decoded != null) {
            final resized = img.copyResize(decoded, width: 512);
            final encoded = img.encodeJpg(resized, quality: 85);
            contactPhoto =
                Photo(thumbnail: Uint8List.fromList(encoded as List<int>));
          }
        } catch (_) {
          // Photo processing failed; continue without photo
        }
      }

      final contact = Contact(
        displayName: displayName,
        photo: contactPhoto,
        name: Name(
          first: givenName,
          last: familyName,
          middle: null,
          prefix: null,
          suffix: null,
          phoneticFirst: null,
          phoneticMiddle: null,
          phoneticLast: null,
          nickname: null,
        ),
        phones: phone != null
            ? [
                Phone(
                  number: phone,
                  isPrimary: true,
                  label: const Label(PhoneLabel.mobile),
                )
              ]
            : [],
        emails: email != null
            ? [
                Email(
                  address: email,
                  isPrimary: true,
                  label: const Label(EmailLabel.home),
                )
              ]
            : [],
        organizations: company != null || title != null
            ? [
                Organization(
                  name: company,
                  jobTitle: title,
                  departmentName: null,
                )
              ]
            : [],
        notes: notes != null ? [Note(note: notes)] : [],
      );

      final flutterAccount = account != null
          ? Account(id: '', name: account.name, type: account.type)
          : null;
      final androidId = await FlutterContacts.create(contact, account: flutterAccount);

      return AndroidExportResult(
        nexoContactId: nexoContactId,
        androidContactId: androidId,
        created: true,
      );
    } catch (e) {
      return AndroidExportResult(
        nexoContactId: nexoContactId,
        errors: ['Failed to export to Android: $e'],
      );
    }
  }

  @override
  Future<List<AndroidExportResult>> exportContacts({
    required List<Map<String, dynamic>> contacts,
    AndroidAccount? account,
  }) async {
    final results = <AndroidExportResult>[];
    for (final c in contacts) {
      final result = await exportContact(
        nexoContactId: c['nexoContactId'] as String,
        displayName: c['displayName'] as String,
        givenName: c['givenName'] as String?,
        familyName: c['familyName'] as String?,
        phone: c['phone'] as String?,
        phoneLabel: c['phoneLabel'] as String?,
        email: c['email'] as String?,
        emailLabel: c['emailLabel'] as String?,
        company: c['company'] as String?,
        title: c['title'] as String?,
        notes: c['notes'] as String?,
        account: account,
        photoBytes: c['photoBytes'] as List<int>?,
        photoMimeType: c['photoMimeType'] as String?,
      );
      results.add(result);
    }
    return results;
  }

  @override
  Future<List<String>> findDuplicates({
    String? phone,
    String? email,
  }) async {
    try {
      final matches = <String>{};
      if (phone != null && phone.isNotEmpty) {
        final byPhone = await FlutterContacts.getAll(
          properties: ContactProperties.all,
          filter: ContactFilter.phone(phone),
        );
        for (final c in byPhone) {
          matches.add(c.id!);
        }
      }
      if (email != null && email.isNotEmpty) {
        final byEmail = await FlutterContacts.getAll(
          properties: ContactProperties.all,
          filter: ContactFilter.email(email),
        );
        for (final c in byEmail) {
          matches.add(c.id!);
        }
      }
      return matches.toList();
    } catch (_) {
      return [];
    }
  }

  // ---------- Private helpers ----------

  AndroidContact _mapFlutterContactToAndroid(Contact fc) {
    String? primaryPhone;
    String? primaryEmail;
    String? company;
    String? title;

    for (final p in fc.phones) {
      primaryPhone ??= p.number;
    }
    for (final e in fc.emails) {
      primaryEmail ??= e.address;
    }
    for (final o in fc.organizations) {
      company ??= o.name;
      title ??= o.jobTitle;
    }

    // Build raw contacts from Android identifiers
    final rawContacts = <AndroidRawContact>[];
    if (fc.android?.identifiers != null) {
      for (final rc in fc.android!.identifiers!.rawContacts) {
        rawContacts.add(AndroidRawContact(
          id: rc.rawContactId ?? '',
          contactId: fc.id!,
          accountName: rc.account?.name ?? '',
          accountType: rc.account?.type ?? '',
          sourceId: rc.sourceId,
        ));
      }
    }

    return AndroidContact(
      id: fc.id!,
      displayName: fc.displayName ?? '',
      givenName: fc.name?.first,
      familyName: fc.name?.last,
      middleName: fc.name?.middle,
      prefix: fc.name?.prefix,
      suffix: fc.name?.suffix,
      phoneticGiven: fc.name?.phoneticFirst,
      phoneticFamily: fc.name?.phoneticLast,
      nickname: fc.name?.nickname,
      phone: primaryPhone,
      email: primaryEmail,
      company: company,
      title: title,
      isStarred: fc.android?.isFavorite ?? false,
      rawContacts: rawContacts,
    );
  }
}
