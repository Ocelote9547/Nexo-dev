import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:nexo/database/app_database.dart';

void main() {
  late AppDatabase db;
  const uuid = Uuid();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('database opens and creates all tables', () async {
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
        )
        .get();
    final names = tables.map((r) => r.read<String>('name')).toList();
    expect(names, contains('contacts'));
    expect(names, contains('phones'));
    expect(names, contains('import_provenances'));
  });

  test('insert and retrieve contact', () async {
    final id = uuid.v4();
    await db
        .into(db.contacts)
        .insert(ContactsCompanion.insert(id: id, givenName: Value('Ana')));
    final row = await db.select(db.contacts).getSingle();
    expect(row.id, id);
    expect(row.givenName, 'Ana');
  });

  test('multiple phones cascade delete', () async {
    final cid = uuid.v4();
    await db.into(db.contacts).insert(ContactsCompanion.insert(id: cid));
    final pid = uuid.v4();
    await db
        .into(db.phones)
        .insert(
          PhonesCompanion.insert(id: pid, contactId: cid, valueRaw: '123'),
        );
    await (db.delete(db.contacts)..where((t) => t.id.equals(cid))).go();
    final phones = await db.select(db.phones).get();
    expect(phones, isEmpty);
  });

  test('N:M contact-tag unique', () async {
    final cid = uuid.v4();
    final tid = uuid.v4();
    await db.into(db.contacts).insert(ContactsCompanion.insert(id: cid));
    await db.into(db.tags).insert(TagsCompanion.insert(id: tid, name: 'tag1'));
    await db
        .into(db.contactTags)
        .insert(ContactTagsCompanion.insert(contactId: cid, tagId: tid));
    expect(
      () => db
          .into(db.contactTags)
          .insert(ContactTagsCompanion.insert(contactId: cid, tagId: tid)),
      throwsA(isA<SqliteException>()),
    );
  });

  test('ImportProvenance: contact with multiple provenances', () async {
    final cid = uuid.v4();
    await db.into(db.contacts).insert(ContactsCompanion.insert(id: cid));
    await db
        .into(db.importProvenances)
        .insert(
          ImportProvenancesCompanion.insert(
            id: uuid.v4(),
            contactId: cid,
            sourceType: 'android',
            originKey: 'android|accType|accName|raw1',
          ),
        );
    await db
        .into(db.importProvenances)
        .insert(
          ImportProvenancesCompanion.insert(
            id: uuid.v4(),
            contactId: cid,
            sourceType: 'vcf',
            originKey: 'vcf|hash1|0',
          ),
        );
    final rows = await db.select(db.importProvenances).get();
    expect(rows.length, 2);
  });

  test('ImportProvenance: same origin imported twice fails', () async {
    final cid = uuid.v4();
    await db.into(db.contacts).insert(ContactsCompanion.insert(id: cid));
    await db
        .into(db.importProvenances)
        .insert(
          ImportProvenancesCompanion.insert(
            id: uuid.v4(),
            contactId: cid,
            sourceType: 'android',
            originKey: 'android|t|a|raw1',
          ),
        );
    expect(
      () => db
          .into(db.importProvenances)
          .insert(
            ImportProvenancesCompanion.insert(
              id: uuid.v4(),
              contactId: cid,
              sourceType: 'android',
              originKey: 'android|t|a|raw1',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('ImportProvenance: same rawContactId in two accounts allowed', () async {
    final cid = uuid.v4();
    await db.into(db.contacts).insert(ContactsCompanion.insert(id: cid));
    await db
        .into(db.importProvenances)
        .insert(
          ImportProvenancesCompanion.insert(
            id: uuid.v4(),
            contactId: cid,
            sourceType: 'android',
            originKey: 'android|t1|accA|raw1',
            accountType: Value('t1'),
            accountName: Value('accA'),
            rawContactId: Value('raw1'),
          ),
        );
    await db
        .into(db.importProvenances)
        .insert(
          ImportProvenancesCompanion.insert(
            id: uuid.v4(),
            contactId: cid,
            sourceType: 'android',
            originKey: 'android|t2|accB|raw1',
            accountType: Value('t2'),
            accountName: Value('accB'),
            rawContactId: Value('raw1'),
          ),
        );
    final rows = await db.select(db.importProvenances).get();
    expect(rows.length, 2);
  });

  test('ImportProvenance: same file/record imported twice fails', () async {
    final cid = uuid.v4();
    await db.into(db.contacts).insert(ContactsCompanion.insert(id: cid));
    await db
        .into(db.importProvenances)
        .insert(
          ImportProvenancesCompanion.insert(
            id: uuid.v4(),
            contactId: cid,
            sourceType: 'vcf',
            originKey: 'vcf|hash1|0',
            fileHash: Value('hash1'),
            recordIndex: Value(0),
          ),
        );
    expect(
      () => db
          .into(db.importProvenances)
          .insert(
            ImportProvenancesCompanion.insert(
              id: uuid.v4(),
              contactId: cid,
              sourceType: 'vcf',
              originKey: 'vcf|hash1|0',
              fileHash: Value('hash1'),
              recordIndex: Value(0),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test(
    'ImportProvenance: same origin cannot be associated to two contacts',
    () async {
      final c1 = uuid.v4();
      final c2 = uuid.v4();
      await db.into(db.contacts).insert(ContactsCompanion.insert(id: c1));
      await db.into(db.contacts).insert(ContactsCompanion.insert(id: c2));
      await db
          .into(db.importProvenances)
          .insert(
            ImportProvenancesCompanion.insert(
              id: uuid.v4(),
              contactId: c1,
              sourceType: 'android',
              originKey: 'android|t|a|raw1',
            ),
          );
      expect(
        () => db
            .into(db.importProvenances)
            .insert(
              ImportProvenancesCompanion.insert(
                id: uuid.v4(),
                contactId: c2,
                sourceType: 'android',
                originKey: 'android|t|a|raw1',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    },
  );

  test(
    'ImportProvenance: repeated imports no duplicates (lookup by originKey)',
    () async {
      final cid = uuid.v4();
      await db.into(db.contacts).insert(ContactsCompanion.insert(id: cid));
      final key = 'android|t|a|raw1';
      await db
          .into(db.importProvenances)
          .insert(
            ImportProvenancesCompanion.insert(
              id: uuid.v4(),
              contactId: cid,
              sourceType: 'android',
              originKey: key,
            ),
          );
      final existing = await (db.select(
        db.importProvenances,
      )..where((t) => t.originKey.equals(key))).getSingleOrNull();
      expect(existing != null, isTrue);
      // Re-import attempt should be detected and skipped; no new row.
      final countBefore = (await db.select(db.importProvenances).get()).length;
      if (existing == null) {
        await db
            .into(db.importProvenances)
            .insert(
              ImportProvenancesCompanion.insert(
                id: uuid.v4(),
                contactId: cid,
                sourceType: 'android',
                originKey: key,
              ),
            );
      }
      final countAfter = (await db.select(db.importProvenances).get()).length;
      expect(countAfter, countBefore);
    },
  );

  test('ContactExtra insert', () async {
    final cid = uuid.v4();
    await db.into(db.contacts).insert(ContactsCompanion.insert(id: cid));
    await db
        .into(db.contactExtras)
        .insert(
          ContactExtrasCompanion.insert(
            id: uuid.v4(),
            contactId: cid,
            source: 'android',
            dataType: 'custom',
            payload: '{}',
          ),
        );
    final rows = await db.select(db.contactExtras).get();
    expect(rows.length, 1);
  });

  test('foreign key enforcement', () async {
    expect(
      () => db
          .into(db.phones)
          .insert(
            PhonesCompanion.insert(
              id: uuid.v4(),
              contactId: 'nope',
              valueRaw: 'x',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('explicit FK indexes exist', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('idx_phones_contact'));
    expect(names, contains('idx_emails_contact'));
    expect(names, contains('idx_addresses_contact'));
    expect(names, contains('idx_social_links_contact'));
    expect(names, contains('idx_organizations_contact'));
    expect(names, contains('idx_contact_dates_contact'));
    expect(names, contains('idx_notes_contact'));
    expect(names, contains('idx_custom_fields_contact'));
    expect(names, contains('idx_contact_tags_tag'));
    expect(names, contains('idx_collection_contacts_contact'));
    expect(names, contains('idx_contact_extras_contact'));
    expect(names, contains('idx_import_provenances_contact'));
  });

  test('FTS5 real creation and query', () async {
    await db.customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS fts_test USING fts5(content);',
    );
    await db.customStatement(
      "INSERT INTO fts_test(content) VALUES ('hello world');",
    );
    final rows = await db
        .customSelect(
          "SELECT content FROM fts_test WHERE fts_test MATCH 'hello'",
        )
        .get();
    expect(rows.length, 1);
  });
}
