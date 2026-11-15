import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:nexo/database/app_database.dart';

class V1Database extends AppDatabase {
  V1Database(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexo_migration');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('fresh install creates schema version 2 with indexes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 2);
    final idx = await db.customSelect("SELECT name FROM sqlite_master WHERE type='index'").get();
    final names = idx.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('uq_phones_primary'));
    expect(names, contains('uq_emails_primary'));
    expect(names, contains('uq_organizations_primary'));
    await db.close();
  });

  test('migration v1->v2 consistent data', () async {
    final file = File(p.join(tempDir.path, 'v1_consistent.db'));
    if (await file.exists()) await file.delete();
    final uuid = const Uuid();
    final cid = uuid.v4();
    final v1 = V1Database(NativeDatabase(file));
    await v1.into(v1.contacts).insert(ContactsCompanion.insert(id: cid, givenName: Value('Ana')));
    final pid = uuid.v4();
    await v1.into(v1.phones).insert(PhonesCompanion.insert(id: pid, contactId: cid, valueRaw: '111', isPrimary: Value(true)));
    final eid = uuid.v4();
    await v1.into(v1.emails).insert(EmailsCompanion.insert(id: eid, contactId: cid, value: 'a@b.com', isPrimary: Value(true)));
    final oid = uuid.v4();
    await v1.into(v1.organizations).insert(OrganizationsCompanion.insert(id: oid, contactId: cid, company: Value('ACME'), isPrimary: Value(true)));
    await v1.close();

    final v2 = AppDatabase(NativeDatabase(file));
    expect(v2.schemaVersion, 2);
    final idx = await v2.customSelect("SELECT name FROM sqlite_master WHERE type='index'").get();
    final names = idx.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('uq_phones_primary'));
    expect(names, contains('uq_emails_primary'));
    expect(names, contains('uq_organizations_primary'));
    final contact = await v2.select(v2.contacts).getSingle();
    expect(contact.id, cid);
    final phones = await v2.select(v2.phones).get();
    expect(phones.length, 1);
    expect(phones.first.isPrimary, isTrue);
    await v2.close();
  });

  test('migration v1->v2 inconsistent data normalizes primaries', () async {
    final file = File(p.join(tempDir.path, 'v1_inconsistent.db'));
    if (await file.exists()) await file.delete();
    final uuid = const Uuid();
    final cid = uuid.v4();
    final v1 = V1Database(NativeDatabase(file));
    await v1.into(v1.contacts).insert(ContactsCompanion.insert(id: cid, givenName: Value('Ana')));
    final p1 = uuid.v4();
    final p2 = uuid.v4();
    await v1.into(v1.phones).insert(PhonesCompanion.insert(id: p1, contactId: cid, valueRaw: '111', isPrimary: Value(true), sortOrder: Value(2)));
    await v1.into(v1.phones).insert(PhonesCompanion.insert(id: p2, contactId: cid, valueRaw: '222', isPrimary: Value(true), sortOrder: Value(1)));
    final e1 = uuid.v4();
    final e2 = uuid.v4();
    await v1.into(v1.emails).insert(EmailsCompanion.insert(id: e1, contactId: cid, value: 'a@b.com', isPrimary: Value(true), sortOrder: Value(2)));
    await v1.into(v1.emails).insert(EmailsCompanion.insert(id: e2, contactId: cid, value: 'c@d.com', isPrimary: Value(true), sortOrder: Value(1)));
    final o1 = uuid.v4();
    final o2 = uuid.v4();
    await v1.into(v1.organizations).insert(OrganizationsCompanion.insert(id: o1, contactId: cid, company: Value('A'), isPrimary: Value(true), sortOrder: Value(2)));
    await v1.into(v1.organizations).insert(OrganizationsCompanion.insert(id: o2, contactId: cid, company: Value('B'), isPrimary: Value(true), sortOrder: Value(1)));
    await v1.close();

    final v2 = AppDatabase(NativeDatabase(file));
    expect(v2.schemaVersion, 2);
    final phones = await v2.select(v2.phones).get();
    expect(phones.length, 2);
    expect(phones.where((p) => p.isPrimary).length, 1);
    expect(phones.firstWhere((p) => p.isPrimary).id, p2);
    final emails = await v2.select(v2.emails).get();
    expect(emails.length, 2);
    expect(emails.where((e) => e.isPrimary).length, 1);
    expect(emails.firstWhere((e) => e.isPrimary).id, e2);
    final orgs = await v2.select(v2.organizations).get();
    expect(orgs.length, 2);
    expect(orgs.where((o) => o.isPrimary).length, 1);
    expect(orgs.firstWhere((o) => o.isPrimary).id, o2);
    final idx = await v2.customSelect("SELECT name FROM sqlite_master WHERE type='index'").get();
    final names = idx.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('uq_phones_primary'));
    await v2.close();
  });
}
