import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nabd/screens/splash_screen.dart';
import 'package:nabd/utils/shared_preferences_helper.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesHelper().init();
  await dotenv.load(fileName: ".env");
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
    requestBatteryIgnorePermission();
    requestOverlayPermission();
    checkAccessibilityPermission();
    requestMicrophonePermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      stopService();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      startService();
    }
  }

  Future<void> startService() async {
    try {
      await platform.invokeMethod('startService');
    } catch (e) {
      print("Error starting service: $e");
    }
  }

  Future<void> stopService() async {
    try {
      await platform.invokeMethod('stopService');
    } catch (e) {
      print("Error stopping service: $e");
    }
  }

  Future<void> requestBatteryIgnorePermission() async {
    try {
      await platform.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      print("Error requesting battery ignore permission: $e");
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      final bool isEnabled = await platform.invokeMethod('isOverlayEnabled');
      if (!isEnabled) {
        await platform.invokeMethod('requestOverlayPermission');
      }
    } catch (e) {
      print("Error requesting overlay permission: $e");
    }
  }

  Future<void> checkAccessibilityPermission() async {
    try {
      final bool isEnabled = await platform.invokeMethod('isAccessibilityEnabled');
      if (!isEnabled) {
        const intent = AndroidIntent(
          action: 'android.settings.ACCESSIBILITY_SETTINGS',
        );
        await intent.launch();
      }
    } catch (e) {
      print("Error checking accessibility permission: $e");
    }
  }

  Future<void> requestMicrophonePermission() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        await Permission.microphone.request();
      }

      status = await Permission.microphone.status;
      if (!status.isGranted) {
        print("Microphone permission not granted, opening app settings...");
        await openAppSettings();
      }
    } catch (e) {
      print("Error requesting microphone permission: $e");
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
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}