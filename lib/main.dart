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
  await dotenv.load(fileName: ".env");
  await SharedPreferencesHelper.instance.init();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

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

  Future<void> _requestBatteryIgnorePermission() async {
    try {
      await platform.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint("Error requesting battery ignore permission: $e");
    }
  }

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
