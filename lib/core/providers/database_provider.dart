import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../database/app_database.dart';

/// Contador de instancias de AppDatabase activas creadas por este provider.
/// Se incrementa al crearse y se decrementa al desecharse.
/// Usado para diagnosticar la advertencia de Drift sobre múltiples instancias concurrentes.
int _appDatabaseProviderActiveCount = 0;

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  _appDatabaseProviderActiveCount++;
  if (_appDatabaseProviderActiveCount > 1) {
    // ignore: avoid_print
    print('''
╔═════════════════════════════════════════════════════════════════════════════════
║  DRIFT WARNING: appDatabaseProvider has $_appDatabaseProviderActiveCount active instances
║  Multiple AppDatabase instances may cause race conditions.
║  Stack trace:
${StackTrace.current}
╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
''');
  }
  final db = AppDatabase(_openConnection());
  ref.onDispose(() {
    _appDatabaseProviderActiveCount--;
    db.close();
  });
  return db;
});

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = p.join(dir.path, 'nexo.sqlite');
    return NativeDatabase(File(file));
  });
}

/// Checks whether FTS5 is available in the bundled SQLite.
final fts5AvailableProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  try {
    await db
        .customSelect('SELECT sqlite_compileoption_used(\'ENABLE_FTS5\')')
        .getSingle();
    final row = await db
        .customSelect('SELECT sqlite_compileoption_used(\'ENABLE_FTS5\') AS v')
        .getSingle();
    final v = row.read<int?>('v');
    return v == 1;
  } catch (_) {
    return false;
  }
});
