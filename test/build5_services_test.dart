import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/database/app_database.dart' as adb;
import 'package:nexo/features/birthdays/domain/services/birthday_service.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/features/dashboard/domain/services/dashboard_service.dart';
import 'package:nexo/features/privacy/domain/services/privacy_service.dart';
import 'package:path/path.dart' as p;
import 'package:nexo/features/quick_actions/domain/services/quick_actions_service.dart';
import 'package:nexo/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexo/features/settings/domain/repositories/settings_repository.dart';
import 'package:nexo/services/media/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late adb.AppDatabase db;
  late MediaService media;
  late Directory tempDir;

  setUp(() async {
    db = adb.AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('nexo_b5');
    media = MediaService(baseDirectory: tempDir);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('SettingsRepository', () {
    late SettingsRepository repo;
    setUp(() { repo = SettingsRepositoryImpl(db); });

    test('string round-trip', () async {
      await repo.setString('key', 'value');
      expect(await repo.getString('key'), 'value');
    });

    test('bool round-trip', () async {
      await repo.setBool('flag', true);
      expect(await repo.getBool('flag'), isTrue);
      await repo.setBool('flag', false);
      expect(await repo.getBool('flag'), isFalse);
    });

    test('int round-trip', () async {
      await repo.setInt('count', 42);
      expect(await repo.getInt('count'), 42);
    });

    test('defaults', () async {
      expect(await repo.getString('missing'), isNull);
      expect(await repo.getBool('missing'), isFalse);
      expect(await repo.getInt('missing'), 0);
      expect(await repo.getBool('missing', defaultValue: true), isTrue);
      expect(await repo.getInt('missing', defaultValue: 7), 7);
    });

    test('update existing', () async {
      await repo.setString('key', 'v1');
      await repo.setString('key', 'v2');
      expect(await repo.getString('key'), 'v2');
    });

    test('delete', () async {
      await repo.setString('key', 'value');
      await repo.delete('key');
      expect(await repo.getString('key'), isNull);
    });

    test('getAll', () async {
      await repo.setString('a', '1');
      await repo.setBool('b', true);
      final all = await repo.getAll();
      expect(all['a'], '1');
      expect(all['b'], 'true');
    });
  });

  group('BirthdayService', () {
    late BirthdayService service;
    setUp(() { service = BirthdayService(db); });

    test('annual recurrence next year when past', () async {
      final now = DateTime(2024, 6, 1);
      final d = ContactDate(id: '1', contactId: 'c', date: DateTime(2020, 3, 15), recurrence: 'yearly');
      final next = service.nextOccurrence(d, now);
      expect(next, DateTime(2025, 3, 15));
    });

    test('annual recurrence same year when future', () async {
      final now = DateTime(2024, 1, 1);
      final d = ContactDate(id: '1', contactId: 'c', date: DateTime(2020, 6, 15), recurrence: 'yearly');
      final next = service.nextOccurrence(d, now);
      expect(next, DateTime(2024, 6, 15));
    });

    test('feb 29 non-leap uses feb 28', () async {
      final now = DateTime(2023, 1, 1);
      final d = ContactDate(id: '1', contactId: 'c', date: DateTime(2020, 2, 29), recurrence: 'yearly');
      final next = service.nextOccurrence(d, now);
      expect(next, DateTime(2023, 2, 28)); // 2023 is non-leap, so Feb 28
    });

    test('feb 29 non-leap year uses feb 28', () async {
      final now = DateTime(2025, 1, 1);
      final d = ContactDate(id: '1', contactId: 'c', date: DateTime(2020, 2, 29), recurrence: 'yearly');
      final next = service.nextOccurrence(d, now);
      expect(next, DateTime(2025, 2, 28)); // 2025 is non-leap, so Feb 28
    });

    test('monthly recurrence', () async {
      final now = DateTime(2024, 1, 15);
      final d = ContactDate(id: '1', contactId: 'c', date: DateTime(2024, 1, 10), recurrence: 'monthly');
      final next = service.nextOccurrence(d, now);
      expect(next.month, 2);
      expect(next.day, 10);
    });

    test('weekly recurrence', () async {
      final now = DateTime(2024, 1, 15); // Monday
      final d = ContactDate(id: '1', contactId: 'c', date: DateTime(2024, 1, 10), recurrence: 'weekly'); // Wednesday
      final next = service.nextOccurrence(d, now);
      expect(next.weekday, DateTime.wednesday);
    });

    test('none recurrence returns original date', () async {
      final now = DateTime(2024, 6, 1);
      final d = ContactDate(id: '1', contactId: 'c', date: DateTime(2020, 3, 15), recurrence: 'none');
      final next = service.nextOccurrence(d, now);
      expect(next, DateTime(2020, 3, 15));
    });

    test('getUpcomingDates with controlled now', () async {
      final cid = 'c1';
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: cid, givenName: Value('Ana')));
      await db.into(db.contactDates).insert(adb.ContactDatesCompanion.insert(
        id: 'd1', contactId: cid, type: Value('birthday'),
        date: DateTime(2024, 1, 20), recurrence: Value('yearly'),
      ));
      final upcoming = await service.getUpcomingDates(days: 30, now: DateTime(2024, 1, 1));
      expect(upcoming.length, 1);
      expect(upcoming.first.daysUntil, 19);
    });

    test('getUpcomingDates excludes past dates', () async {
      final cid = 'c1';
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: cid, givenName: Value('Ana')));
      await db.into(db.contactDates).insert(adb.ContactDatesCompanion.insert(
        id: 'd1', contactId: cid, type: Value('birthday'),
        date: DateTime(2023, 12, 1), recurrence: Value('yearly'),
      ));
      final upcoming = await service.getUpcomingDates(days: 30, now: DateTime(2024, 6, 1));
      // Dec 1 is far in the future (next Dec), not within 30 days
      expect(upcoming.length, 0);
    });
  });

  group('DashboardService', () {
    late DashboardService service;
    setUp(() { service = DashboardService(db); });

    test('empty database', () async {
      final summary = await service.getSummary();
      expect(summary.totalContacts, 0);
      expect(summary.favoriteContacts, 0);
      expect(summary.recentContacts, 0);
      expect(summary.totalCollections, 0);
      expect(summary.totalTags, 0);
      expect(summary.contactsWithoutPhoto, 0);
      expect(summary.contactsWithoutPhone, 0);
    });

    test('counts contacts correctly', () async {
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c1', givenName: Value('Ana'), isFavorite: Value(true)));
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c2', givenName: Value('Bob')));
      final summary = await service.getSummary();
      expect(summary.totalContacts, 2);
      expect(summary.favoriteContacts, 1);
      expect(summary.contactsWithoutPhoto, 2);
      expect(summary.contactsWithoutPhone, 2);
    });

    test('collections and tags counted', () async {
      await db.into(db.collections).insert(adb.CollectionsCompanion.insert(id: 'col1', name: 'Friends'));
      await db.into(db.tags).insert(adb.TagsCompanion.insert(id: 't1', name: 'Work'));
      final summary = await service.getSummary();
      expect(summary.totalCollections, 1);
      expect(summary.totalTags, 1);
    });

    test('no duplicate counts from one-to-many', () async {
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c1', givenName: Value('Ana')));
      await db.into(db.phones).insert(adb.PhonesCompanion.insert(id: 'p1', contactId: 'c1', valueRaw: '123'));
      await db.into(db.phones).insert(adb.PhonesCompanion.insert(id: 'p2', contactId: 'c1', valueRaw: '456'));
      final summary = await service.getSummary();
      expect(summary.totalContacts, 1);
      expect(summary.contactsWithoutPhone, 0);
    });
  });

  group('PrivacyService', () {
    late PrivacyService service;
    setUp(() { service = PrivacyService(db, media); });

    test('rejects without confirmation', () async {
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c1', givenName: Value('Ana')));
      expect(() => service.deleteAllData(confirmed: false), throwsA(isA<StateError>()));
      final contacts = await db.select(db.contacts).get();
      expect(contacts.length, 1);
    });

    test('deletes all data with confirmation', () async {
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c1', givenName: Value('Ana')));
      await db.into(db.appSettings).insert(adb.AppSettingsCompanion.insert(key: 'k', value: 'v'));
      await service.deleteAllData(confirmed: true);
      final contacts = await db.select(db.contacts).get();
      expect(contacts, isEmpty);
      final settings = await db.select(db.appSettings).get();
      expect(settings, isEmpty);
    });

    test('getDataSummary returns counts', () async {
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c1', givenName: Value('Ana')));
      final summary = await service.getDataSummary();
      expect(summary['contacts'], 1);
    });
  });

  group('QuickActionsService', () {
    late QuickActionsService service;
    setUp(() { service = QuickActionsService(); });

    test('call URI', () {
      final uri = service.buildCallUri('600123456');
      expect(uri.scheme, 'tel');
      expect(uri.path, '600123456');
    });

    test('SMS URI', () {
      final uri = service.buildSmsUri('600123456');
      expect(uri.scheme, 'sms');
      expect(uri.path, '600123456');
    });

    test('email URI', () {
      final uri = service.buildEmailUri('test@example.com', subject: 'Hello', body: 'World');
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'test@example.com');
      expect(uri.queryParameters['subject'], 'Hello');
      expect(uri.queryParameters['body'], 'World');
    });

    test('map URI encodes address', () {
      final uri = service.buildMapUri('Calle Mayor 1, Madrid');
      expect(uri.toString(), contains('Calle%20Mayor'));
      expect(uri.toString(), contains('maps'));
    });

    test('URL URI', () {
      final uri = service.buildUrlUri('https://example.com');
      expect(uri.toString(), 'https://example.com');
    });

    test('WhatsApp URI', () {
      final uri = service.buildWhatsAppUri('600123456');
      expect(uri.toString(), contains('wa.me'));
      expect(uri.toString(), contains('600123456'));
    });

    test('Unicode in email subject', () {
      final uri = service.buildEmailUri('test@example.com', subject: 'Hola José');
      expect(uri.queryParameters['subject'], 'Hola José');
    });
  });
  group('SettingsRepository persistence', () {
    test('persists after reopen', () async {
      final dir = await Directory.systemTemp.createTemp('nexo_settings');
      final path = p.join(dir.path, 'settings.db');
      var db = adb.AppDatabase(NativeDatabase(File(path)));
      var repo = SettingsRepositoryImpl(db);
      await repo.setString('key', 'value');
      await repo.setBool('flag', true);
      await repo.setInt('count', 7);
      await db.close();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      db = adb.AppDatabase(NativeDatabase(File(path)));
      repo = SettingsRepositoryImpl(db);
      expect(await repo.getString('key'), 'value');
      expect(await repo.getBool('flag'), isTrue);
      expect(await repo.getInt('count'), 7);
      await db.close();
      await dir.delete(recursive: true);
    });
  });

  group('BirthdayService monthly day 31 policy', () {
    test('clamps to last day of month', () async {
      final service = BirthdayService(db);
      final now = DateTime(2024, 2, 1);
      final d = ContactDate(id: '1', contactId: 'c', date: DateTime(2024, 1, 31), recurrence: 'monthly');
      final next = service.nextOccurrence(d, now);
      expect(next.month, 2);
      expect(next.day, 29);
    });
  });

  group('PrivacyService failures', () {
    test('media failure leaves DB state and throws', () async {
      final media = MediaService(baseDirectory: tempDir);
      final service = PrivacyService(db, media);
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c1', givenName: Value('Ana')));
      await tempDir.delete(recursive: true);
      await tempDir.create();
      final file = File(p.join(tempDir.path, 'media'));
      await file.writeAsString('block');
      expect(() => service.deleteAllData(confirmed: true), throwsA(isA<Exception>()));
      final contacts = await db.select(db.contacts).get();
      expect(contacts.length, 1);
    });

    test('repeat after success', () async {
      final media = MediaService(baseDirectory: tempDir);
      final service = PrivacyService(db, media);
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c1', givenName: Value('Ana')));
      await service.deleteAllData(confirmed: true);
      await service.deleteAllData(confirmed: true);
      final contacts = await db.select(db.contacts).get();
      expect(contacts, isEmpty);
    });
  });

  group('QuickActionsService invalid data', () {
    test('launch failure returns false', () async {
      final service = QuickActionsService(launcher: (uri) async => false);
      final result = await service.call('600123456');
      expect(result, isFalse);
    });

    test('launcher throws propagates', () async {
      final service = QuickActionsService(launcher: (uri) async => throw Exception('no app'));
      expect(() => service.call('600123456'), throwsA(isA<Exception>()));
    });

    test('empty phone still builds URI', () {
      final service = QuickActionsService();
      final uri = service.buildCallUri('');
      expect(uri.scheme, 'tel');
      expect(uri.path, '');
    });
  });
}
