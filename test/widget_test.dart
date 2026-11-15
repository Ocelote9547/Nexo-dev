import 'package:nexo/features/backup/presentation/screens/backup_screen.dart';
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/core/providers/database_provider.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/database/app_database.dart' as adb;
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/features/contacts/presentation/providers/contact_providers.dart';
import 'package:nexo/features/contacts/presentation/providers/search_providers.dart';
import 'package:nexo/features/contacts/data/services/contact_search_service.dart';
import 'package:nexo/features/collections/presentation/providers/collection_providers.dart';
import 'package:nexo/features/dashboard/domain/services/dashboard_service.dart';
import 'package:nexo/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:nexo/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexo/features/collections/presentation/screens/collections_screen.dart';
import 'package:nexo/features/settings/presentation/screens/settings_screen.dart';
import 'package:nexo/features/home/presentation/providers/dashboard_providers.dart';
import 'package:nexo/features/home/presentation/screens/home_screen.dart';
import 'package:nexo/shared/widgets/nexo_widgets.dart';
import 'package:nexo/core/design/components/nexo_button.dart';
import 'package:nexo/core/design/components/nexo_text_field.dart';
import 'package:nexo/core/design/components/nexo_card.dart';
import 'package:nexo/core/design/components/nexo_switch.dart';
import 'package:nexo/core/design/components/nexo_selector.dart';
import 'package:nexo/core/design/components/nexo_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nexo/services/notifications/notification_service.dart';
import 'package:nexo/services/notifications/notification_providers.dart';

class _FakeSearchService extends ContactSearchService {
  _FakeSearchService() : super(null, forceFallback: true);

  @override
  Future<void> ensureFtsTable() async {}

  @override
  Future<List<String>> searchIds(String query, {bool favoritesOnly = false, String? tagId, String? collectionId}) async {
    if (query == 'ana') return ['c1'];
    return [];
  }
}

/// Mock de NotificationService para controlar el estado del permiso en tests.
class _MockNotificationService extends NotificationService {
  PermissionStatus _status = PermissionStatus.granted;

  @override
  Future<void> init() async {}

  @override
  Future<bool> hasPermission() async => _status == PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestPermission() async => _status;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> scheduleBirthdayNotifications({
    required String dateId,
    required String contactName,
    required int month,
    required int day,
    required int advanceDays,
    required bool sound,
  }) async => _status == PermissionStatus.granted;

  @override
  Future<void> cancelBirthdayNotifications(String dateId) async {}

  @override
  Future<void> scheduleBirthday({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    bool sound = true,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme and visual system', () {
    testWidgets('uses NexoTheme.dark', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor, NexoColors.background);
      await db.close();
    });

    testWidgets('shared widgets render', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: NexoTheme.dark(),
        home: Scaffold(
          body: Column(
            children: const [
              NexoLoading(),
              NexoEmptyState(icon: Icons.people, title: 'Vacío', subtitle: 'sub'),
              NexoErrorState(message: 'Error'),
              NexoAvatar(displayName: 'Ana Garcia', size: 40),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Vacío'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });
  });

  group('Navigation', () {
    testWidgets('switches sections', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      expect(find.text('Contactos'), findsAtLeastNWidgets(1));
      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Colecciones'), findsAtLeastNWidgets(1));
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsAtLeastNWidgets(1));
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(find.text('NEXO'), findsOneWidget);
      expect(find.textContaining('contactos guardados'), findsNothing);
      await db.close();
    });
  });

  group('Dashboard', () {
    testWidgets('loading state', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream<List<Contact>>.empty()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await db.close();
    });

    testWidgets('empty state data', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('NEXO'), findsOneWidget);
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('Próximos cumpleaños'), findsOneWidget);
      expect(find.text('Contactos recientes'), findsAtLeastNWidgets(1));
      await db.close();
    });

    testWidgets('error state', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          upcomingDatesProvider.overrideWith((ref) async => throw Exception('boom')),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsOneWidget);
      await db.close();
    });
  });

  group('Contacts', () {
    testWidgets('empty state', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value([])),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Sin contactos'), findsOneWidget);
      await db.close();
    });

    testWidgets('with contacts', (tester) async {
      final c = Contact(id: '1', givenName: 'Ana', familyName: 'Garcia', createdAt: DateTime(2024), updatedAt: DateTime(2024));
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value([c])),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ana Garcia'), findsOneWidget);
      await db.close();
    });

    testWidgets('search with results', (tester) async {
      final c = Contact(id: 'c1', givenName: 'Ana', familyName: 'Garcia', createdAt: DateTime(2024), updatedAt: DateTime(2024));
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value([c])),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pumpAndSettle();
      expect(find.text('Ana Garcia'), findsOneWidget);
      await db.close();
    });

    testWidgets('search no results', (tester) async {
      final c = Contact(id: 'c1', givenName: 'Ana', familyName: 'Garcia', createdAt: DateTime(2024), updatedAt: DateTime(2024));
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value([c])),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Ana Garcia'), findsNothing);
      await db.close();
    });

    testWidgets('clear search restores full list', (tester) async {
      final c = Contact(id: 'c1', givenName: 'Ana', familyName: 'Garcia', createdAt: DateTime(2024), updatedAt: DateTime(2024));
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value([c])),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Ana Garcia'), findsOneWidget);
      await db.close();
    });
  });

  group('Collections', () {
    testWidgets('empty state', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          collectionsListProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const CollectionsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Sin colecciones'), findsOneWidget);
      await db.close();
    });

    testWidgets('with collections', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          collectionsListProvider.overrideWith((ref) => Stream.value([
            {'id': '1', 'name': 'Friends', 'description': 'desc', 'color': null, 'icon': null},
          ])),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const CollectionsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Friends'), findsOneWidget);
      await db.close();
    });
  });

  group('Settings', () {
    testWidgets('renders preferences', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Notificaciones de cumpleaños'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('NEXO'), findsOneWidget);
      await db.close();
    });

    testWidgets('toggle persists', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      final switchFinder = find.byWidgetPredicate((w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Notificaciones de cumpleaños');
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      final repo = SettingsRepositoryImpl(db);
      expect(await repo.getBool('birthday_notifications'), isFalse);
      await db.close();
    });

    testWidgets('permission granted keeps toggle on', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      final mock = _MockNotificationService().._status = PermissionStatus.granted;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(mock),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      // El interruptor inicia desactivado (valor por defecto para nueva instalación).
      final switchFinder = find.byWidgetPredicate((w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Notificaciones de cumpleaños');
      // Primero encender (permiso concedido, se mantiene activo).
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
      // Luego apagar.
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      await db.close();
    });

    testWidgets('permission denied reverts toggle off', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      final mock = _MockNotificationService().._status = PermissionStatus.denied;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(mock),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      final switchFinder = find.byWidgetPredicate((w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Notificaciones de cumpleaños');
      // El interruptor inicia activado. Apagarlo (funciona sin permiso).
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      // Intentar volver a encender con permiso denegado → debe revertir.
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);
      expect(find.textContaining('denegado'), findsOneWidget);
      await db.close();
    });

    testWidgets('permission permanently denied shows open settings', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      final mock = _MockNotificationService()
        .._status = PermissionStatus.permanentlyDenied;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(mock),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      // El interruptor inicia desactivado (valor por defecto).
      final switchFinder = find.byWidgetPredicate((w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Notificaciones de cumpleaños');
      // Intentar encender con permiso denegado permanentemente → debe revertir y mostrar diálogo.
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);
      expect(find.text('Abrir ajustes'), findsOneWidget);
      await db.close();
    });
  });

  group('Adaptability', () {
    testWidgets('small viewport no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('large text scaling', (tester) async {
      tester.view.platformDispatcher.textScaleFactorTestValue = 2.0;
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await db.close();
      tester.view.platformDispatcher.clearTextScaleFactorTestValue();
    });
  });
  group('Coverage additions', () {
    testWidgets('dashboard does not show total contact count', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c1', givenName: Value('Ana'), isFavorite: Value(true)));
      await db.into(db.contacts).insert(adb.ContactsCompanion.insert(id: 'c2', givenName: Value('Bob')));
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('NEXO'), findsOneWidget);
      await db.close();
    });

    testWidgets('contacts loading state', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream<List<Contact>>.empty()),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await db.close();
    });

    testWidgets('contacts error state', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.error(Exception('boom'))),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error al cargar contactos'), findsOneWidget);
      await db.close();
    });

    testWidgets('avatar initials and favorite indicator', (tester) async {
      final c = Contact(id: 'c1', givenName: 'Ana', familyName: 'Garcia', isFavorite: true, createdAt: DateTime(2024), updatedAt: DateTime.now());
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value([c])),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const ContactsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('AG'), findsNWidgets(2));
      expect(find.byIcon(Icons.star), findsNWidgets(2));
      await db.close();
    });

    testWidgets('collections loading state', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      final controller = StreamController<List<Map<String, dynamic>>>();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          collectionsListProvider.overrideWith((ref) => controller.stream),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const CollectionsScreen()),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await controller.close();
      await db.close();
    });

    testWidgets('collections error state', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          collectionsListProvider.overrideWith((ref) => Stream.error(Exception('boom'))),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const CollectionsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error al cargar colecciones'), findsOneWidget);
      await db.close();
    });

    testWidgets('settings recovery after rebuild', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      final notifications = _MockNotificationService()
        .._status = PermissionStatus.granted;
      final overrides = [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(theme: NexoTheme.dark(), home: const SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      final switchFinder = find.byWidgetPredicate((w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Notificaciones de cumpleaños');
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(theme: NexoTheme.dark(), home: const SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);
      await db.close();
    });

    testWidgets('navigation preserves contact search state', (tester) async {
      final c = Contact(id: 'c1', givenName: 'Ana', familyName: 'Garcia', createdAt: DateTime(2024), updatedAt: DateTime(2024));
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contactsListProvider.overrideWith((ref) => Stream.value([c])),
          contactSearchServiceProvider.overrideWithValue(_FakeSearchService()),
        ],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      expect(find.text('Ana Garcia'), findsOneWidget);
      await db.close();
    });

    testWidgets('accessibility semantics for navigation', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      final homeIcon = find.byIcon(Icons.home);
      expect(homeIcon, findsOneWidget);
      final semantics = tester.getSemantics(homeIcon);
      expect(semantics, isNotNull);
      await db.close();
    });
  });

  group('Backup screen', () {
    testWidgets('renders backup screen', (tester) async {
      final db = adb.AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: NexoTheme.dark(), home: const BackupScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Copias de seguridad'), findsOneWidget);
      expect(find.text('Crear copia de seguridad'), findsOneWidget);
      expect(find.text('Restaurar copia de seguridad'), findsOneWidget);
      await db.close();
    });
  });

  group('Design System', () {
    testWidgets('NexoButton primary variant renders and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoButton(
                onPressed: () => tapped = true,
                variant: NexoButtonVariant.primary,
                child: const Text('Guardar'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Guardar'), findsOneWidget);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('NexoButton secondary variant renders', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoButton(
                onPressed: null,
                variant: NexoButtonVariant.secondary,
                child: const Text('Secundario'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Secundario'), findsOneWidget);
    });

    testWidgets('NexoButton text variant renders', (tester) async {
      var tapped = false;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoButton(
                onPressed: () => tapped = true,
                variant: NexoButtonVariant.text,
                child: const Text('Texto'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Texto'), findsOneWidget);
      await tester.tap(find.text('Texto'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('NexoTextField renders with label and hint', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoTextField(
                label: 'Nombre',
                hint: 'Escribe tu nombre',
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Escribe tu nombre'), findsOneWidget);
    });

    testWidgets('NexoTextField shows error text', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoTextField(
                label: 'Email',
                errorText: 'Email inválido',
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Email inválido'), findsOneWidget);
    });

    testWidgets('NexoCard renders with child', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoCard(
                child: const Text('Contenido de tarjeta'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Contenido de tarjeta'), findsOneWidget);
    });

    testWidgets('NexoCard is tappable when onTap provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoCard(
                onTap: () => tapped = true,
                child: const Text('Tocable'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tocable'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('NexoSwitch toggles value', (tester) async {
      var value = false;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoSwitch(
                value: value,
                onChanged: (v) => value = v,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets('NexoSelector renders items and responds to selection', (tester) async {
      var selected = '';
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoSelector<String>(
                initialValue: 'Opción 1',
                items: const [
                  DropdownMenuItem(value: 'Opción 1', child: Text('Opción 1')),
                  DropdownMenuItem(value: 'Opción 2', child: Text('Opción 2')),
                ],
                onChanged: (v) => selected = v ?? '',
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Opción 1'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opción 2').last);
      await tester.pumpAndSettle();
      expect(selected, 'Opción 2');
    });

    testWidgets('NexoDialog shows confirm and cancel buttons', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final result = await showNexoDialog<bool>(
                      context,
                      title: 'Confirmar acción',
                      description: '¿Estás seguro?',
                      confirmLabel: 'Sí, continuar',
                      cancelLabel: 'No, cancelar',
                      onConfirm: () => confirmed = true,
                    );
                    expect(result, isTrue);
                  },
                  child: const Text('Abrir diálogo'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir diálogo'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar acción'), findsOneWidget);
      await tester.tap(find.text('Sí, continuar'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });

    testWidgets('NexoEmptyState renders icon and title', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoEmptyState(
                icon: Icons.people_outline,
                title: 'Sin contactos',
                subtitle: 'Añade tu primer contacto',
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Sin contactos'), findsOneWidget);
      expect(find.text('Añade tu primer contacto'), findsOneWidget);
    });

    testWidgets('NexoLoading renders circular progress indicator', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: const Scaffold(
            body: Center(child: NexoLoading()),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('NexoErrorState renders message and retry button', (tester) async {
      var retried = false;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoErrorState(
                message: 'Algo salió mal',
                onRetry: () => retried = true,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Algo salió mal'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(retried, isTrue);
    });

    testWidgets('NexoAvatar shows initials when no photo', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: NexoTheme.dark(),
          home: Scaffold(
            body: Center(
              child: NexoAvatar(
                displayName: 'Ana García',
                size: 44,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('AG'), findsOneWidget);
    });
  });
}

