// lib/utils/shared_preferences_helper.dart

import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  static final SharedPreferencesHelper instance =
      SharedPreferencesHelper._internal();
  SharedPreferences? _prefs;

  SharedPreferencesHelper._internal();

  factory SharedPreferencesHelper() {
    return instance;
  }

  /// يجب استدعاء init مرة واحدة في main قبل استخدام أيّ دوال أخرى
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// حفظ قيمة بوليانية
  Future<void> savePrefBool({
    required String key,
    required bool value,
  }) async {
    await _prefs?.setBool(key, value);
  }

  /// الحصول على قيمة بوليانية أو false افتراضيًا
  bool getPrefBool({
    required String key,
    required bool defaultValue,
  }) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  /// حذف قيمة
  Future<void> remove({required String key}) async {
    await _prefs?.remove(key);
  }

  // ================================
  // دوال مخصّصة لقيمة "hasLoggedIn"
  // ================================

  /// تخزين أن المستخدم سجّل دخولًا ناجحًا بالفعل
  Future<void> setHasLoggedIn(bool value) async {
    await savePrefBool(key: 'hasLoggedIn', value: value);
  }

  /// الحصول على حالة تسجيل الدخول (إفتراضية false)
  bool getHasLoggedIn() {
    return getPrefBool(key: 'hasLoggedIn', defaultValue: false);
  }
}
