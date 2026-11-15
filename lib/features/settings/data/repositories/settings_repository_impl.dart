
import '../../../../database/app_database.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final AppDatabase _db;
  SettingsRepositoryImpl(this._db);

  @override
  Future<String?> getString(String key) async {
    final row = await (_db.select(_db.appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> setString(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));
  }

  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await getString(key);
    if (v == null) return defaultValue;
    return v == 'true';
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await setString(key, value ? 'true' : 'false');
  }

  @override
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final v = await getString(key);
    if (v == null) return defaultValue;
    return int.tryParse(v) ?? defaultValue;
  }

  @override
  Future<void> setInt(String key, int value) async {
    await setString(key, value.toString());
  }

  @override
  Future<Map<String, String>> getAll() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }

  @override
  Future<void> delete(String key) async {
    await (_db.delete(_db.appSettings)..where((t) => t.key.equals(key))).go();
  }
}
