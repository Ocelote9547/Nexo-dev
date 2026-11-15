abstract class SettingsRepository {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<bool> getBool(String key, {bool defaultValue = false});
  Future<void> setBool(String key, bool value);
  Future<int> getInt(String key, {int defaultValue = 0});
  Future<void> setInt(String key, int value);
  Future<Map<String, String>> getAll();
  Future<void> delete(String key);
}
