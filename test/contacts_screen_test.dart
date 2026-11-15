import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/database/app_database.dart' as adb;
import 'package:nexo/core/providers/database_provider.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/features/contacts/data/repositories/contact_repository_impl.dart';
import 'package:nexo/features/contacts/data/services/contact_search_service.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/features/contacts/presentation/providers/contact_providers.dart';
import 'package:nexo/features/contacts/presentation/providers/search_providers.dart';
import 'package:nexo/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:nexo/services/media/media_service.dart';

class _FakeSearchService extends ContactSearchService {
  _FakeSearchService() : super(null, forceFallback: true);

  @override
  Future<List<String>> searchIds(String query,
      {bool favoritesOnly = false, String? tagId, String? collectionId}) async {
    return <String>[];
  }
}

void main() {
  group('ContactosScreen - contador de contactos', () {
    late adb.AppDatabase db;
    late ContactRepositoryImpl contacts;

    setUp(() async {
      db = adb.AppDatabase(NativeDatabase.memory());
      contacts = ContactRepositoryImpl(db, MediaService(), ContactSearchService(db));
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('contador con lista completa', (tester) async {
      await contacts.createContact(Contact(givenName: 'Ana', familyName: 'García'));
      await contacts.createContact(Contact(givenName: 'José', familyName: 'López'));
      await contacts.createContact(Contact(givenName: 'María', familyName: 'Pérez'));

      final all = await contacts.getAllContacts();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value(all)),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('3 contactos'), findsOneWidget);
    });

    testWidgets('resultado singular - 1 contacto', (tester) async {
      await contacts.createContact(Contact(givenName: 'Ana', familyName: 'García'));

      final all = await contacts.getAllContacts();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value(all)),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 contacto'), findsOneWidget);
    });

    testWidgets('estado vacío sin contactos', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value(<Contact>[])),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('0 contactos'), findsOneWidget);
      expect(find.text('Sin contactos'), findsOneWidget);
    });

    testWidgets('favoritos contados una vez a pesar de dos posiciones', (tester) async {
      await contacts.createContact(
        Contact(givenName: 'Ana', familyName: 'García', isFavorite: true),
      );
      await contacts.createContact(Contact(givenName: 'José', familyName: 'López'));

      final all = await contacts.getAllContacts();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value(all)),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();

      // 2 contactos únicos aunque Ana aparece en Favoritos y en G (alfabético)
      expect(find.text('2 contactos'), findsOneWidget);
    });

    testWidgets('avatar con iniciales cuando no hay fotografía', (tester) async {
      await contacts.createContact(Contact(givenName: 'Ana', familyName: 'García'));

      final all = await contacts.getAllContacts();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value(all)),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();

      // Avatar muestra iniciales "AG"
      expect(find.text('AG'), findsWidgets);
    });
  });
}
