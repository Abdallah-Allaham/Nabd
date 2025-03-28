
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  static final SharedPreferencesHelper instance =
  SharedPreferencesHelper._internal();
  SharedPreferences? _prefs;

  SharedPreferencesHelper._internal();

  factory SharedPreferencesHelper() {
    return instance;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Remove item from storage
  Future<void> remove({required String key}) async {
    await _prefs?.remove(key);
  }

  // Save methods for different data types
  Future<void> savePrefString({
    required String key,
    required String value,
  }) async {
    await _prefs?.setString(key, value);
  }

  Future<void> savePrefInt({required String key, required int value}) async {
    await _prefs?.setInt(key, value);
  }

  Future<void> savePrefBool({required String key, required bool value}) async {
    await _prefs?.setBool(key, value);
  }

  Future<void> savePrefDouble({
    required String key,
    required double value,
  }) async {
    await _prefs?.setDouble(key, value);
  }

  Future<void> savePrefStringList({
    required String key,
    required List<String> value,
  }) async {
    await _prefs?.setStringList(key, value);
  }

  // Get methods for different data types
  String getPrefString({required String key, required String defaultValue}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  int getPrefInt({required String key, required int defaultValue}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  bool getPrefBool({required String key, required bool defaultValue}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  Future<double> getPrefDouble({
    required String key,
    required double defaultValue,
  }) async {
    return _prefs?.getDouble(key) ?? defaultValue;
  }

  Future<List<String>> getPrefStringList({
    required String key,
    required List<String> defaultValue,
  }) async {
    return _prefs?.getStringList(key) ?? defaultValue;
  }
}

