import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:nabd/screens/splash_screen.dart';
import 'package:nabd/utils/shared_preferences_helper.dart';
import 'package:nabd/screens/login_screen.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ————————————————
  // 1) تحميل متغيرات البيئة (dotenv)، إذا كنت تستخدم ملف .env
  await dotenv.load(fileName: ".env");

  // ————————————————
  // 2) تهيئة SharedPreferencesHelper (مرّة واحدة)
  await SharedPreferencesHelper.instance.init();

  // ————————————————
  // 3) تهيئة Firebase (الحقيقة)
  await Firebase.initializeApp();

  // (اختياري) 4) تفعيل Firebase App Check للأندرويد
  // إذا لم ترد استخدام App Check، يمكنك حذف السطرين التاليي
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    // لاحظ: في الإصدارات الإنتاجية استبدل Debug بـ PlayIntegrity أو SafetyNet
  );

  // ————————————————
  // 5) تشغيل التطبيق
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const platform = MethodChannel('nabd/foreground');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // عند بدء التطبيق، نفعل الصلاحيات والخدمات الأساسية
    _requestBatteryIgnorePermission();
    _requestOverlayPermission();
    _checkAccessibilityPermission();
    _requestMicrophonePermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _stopService();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _startService();
    }
  }

  // ————————————————
  // خدمات Foreground Service (Native Android)
  Future<void> _startService() async {
    try {
      await platform.invokeMethod('startService');
    } catch (e) {
      debugPrint("Error starting service: $e");
    }
  }

  Future<void> _stopService() async {
    try {
      await platform.invokeMethod('stopService');
    } catch (e) {
      debugPrint("Error stopping service: $e");
    }
  }

  // ————————————————
  // طلب تجاوز تحسينات البطاريّة (Battery Optimization)
  Future<void> _requestBatteryIgnorePermission() async {
    try {
      await platform.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint("Error requesting battery ignore permission: $e");
    }
  }

  // ————————————————
  // طلب صلاحية Overlay (للرُسوم العائمة إن استخدمتها)
  Future<void> _requestOverlayPermission() async {
    try {
      final bool isEnabled = await platform.invokeMethod('isOverlayEnabled');
      if (!isEnabled) {
        await platform.invokeMethod('requestOverlayPermission');
      }
    } catch (e) {
      debugPrint("Error requesting overlay permission: $e");
    }
  }

  // ————————————————
  // التحقق من صلاحية الوصول إلى Accessibility (إن استخدمت خدمة إمكانية الوصول)
  Future<void> _checkAccessibilityPermission() async {
    try {
      final bool isEnabled = await platform.invokeMethod('isAccessibilityEnabled');
      if (!isEnabled) {
        const intent = AndroidIntent(
          action: 'android.settings.ACCESSIBILITY_SETTINGS',
        );
        await intent.launch();
      }
    } catch (e) {
      debugPrint("Error checking accessibility permission: $e");
    }
  }

  // ————————————————
  // طلب صلاحية استخدام الميكروفون (STT)
  Future<void> _requestMicrophonePermission() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        await Permission.microphone.request();
      }

      status = await Permission.microphone.status;
      if (!status.isGranted) {
        debugPrint("Microphone permission not granted, opening app settings...");
        await openAppSettings();
      }
    } catch (e) {
      debugPrint("Error requesting microphone permission: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ————————————————
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nabd',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(),

    );
  }
}
