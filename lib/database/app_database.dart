import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Contador de instancias de AppDatabase creadas directamente (fuera del provider).
/// Usado para diagnosticar la advertencia de Drift sobre múltiples instancias.
int _appDatabaseDirectActiveCount = 0;

@DriftDatabase(
  tables: [
    Contacts,
    Phones,
    Emails,
    Addresses,
    SocialLinks,
    Organizations,
    ContactDates,
    Notes,
    CustomFields,
    Tags,
    ContactTags,
    Collections,
    CollectionContacts,
    AppSettings,
    ContactExtras,
    ImportProvenances,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e) {
    _appDatabaseDirectActiveCount++;
    if (_appDatabaseDirectActiveCount > 1) {
      // ignore: avoid_print
      print('''
╔═════════════════════════════════════════════════════════════════════════════════
║  DRIFT WARNING: AppDatabase direct active instance #$_appDatabaseDirectActiveCount created
║  OUTSIDE appDatabaseProvider - this may cause race conditions.
║  Stack trace:
${StackTrace.current}
╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
''');
    }
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
          // Solo las bases recién creadas reciben el estado pendiente.
          // Las instalaciones existentes no ejecutan onCreate y no verán onboarding.
          await into(appSettings).insert(
            AppSettingsCompanion.insert(
              key: 'onboarding_status',
              value: 'pending',
            ),
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _createIndexes();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  Future<void> _createIndexes() async {
    // Normalize duplicate primary flags before creating partial unique indexes.
    // Rule: among primary items for a contact, keep the one with lowest sortOrder,
    // then lowest id; set the rest to non-primary.
    await customStatement('''
      UPDATE phones
      SET is_primary = 0
      WHERE is_primary = 1
        AND id NOT IN (
          SELECT id FROM (
            SELECT id,
                   ROW_NUMBER() OVER (
                     PARTITION BY contact_id
                     ORDER BY sort_order ASC, id ASC
                   ) AS rn
            FROM phones
            WHERE is_primary = 1
          ) WHERE rn = 1
        );
    ''');
    await customStatement('''
      UPDATE emails
      SET is_primary = 0
      WHERE is_primary = 1
        AND id NOT IN (
          SELECT id FROM (
            SELECT id,
                   ROW_NUMBER() OVER (
                     PARTITION BY contact_id
                     ORDER BY sort_order ASC, id ASC
                   ) AS rn
            FROM emails
            WHERE is_primary = 1
          ) WHERE rn = 1
        );
    ''');
    await customStatement('''
      UPDATE organizations
      SET is_primary = 0
      WHERE is_primary = 1
        AND id NOT IN (
          SELECT id FROM (
            SELECT id,
                   ROW_NUMBER() OVER (
                     PARTITION BY contact_id
                     ORDER BY sort_order ASC, id ASC
                   ) AS rn
            FROM organizations
            WHERE is_primary = 1
          ) WHERE rn = 1
        );
    ''');

    await customStatement('CREATE INDEX IF NOT EXISTS idx_phones_contact ON phones(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_emails_contact ON emails(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_addresses_contact ON addresses(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_social_links_contact ON social_links(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_organizations_contact ON organizations(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_contact_dates_contact ON contact_dates(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_notes_contact ON notes(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_custom_fields_contact ON custom_fields(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_contact_tags_tag ON contact_tags(tag_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_collection_contacts_contact ON collection_contacts(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_contact_extras_contact ON contact_extras(contact_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_import_provenances_contact ON import_provenances(contact_id);');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS uq_phones_primary ON phones(contact_id) WHERE is_primary = 1;');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS uq_emails_primary ON emails(contact_id) WHERE is_primary = 1;');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS uq_organizations_primary ON organizations(contact_id) WHERE is_primary = 1;');
  }
}