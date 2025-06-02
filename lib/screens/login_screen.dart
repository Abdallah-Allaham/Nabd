import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nabd/screens/main_screen.dart';
import 'package:nabd/screens/signup_screen.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/utils/audio_helper.dart';
import 'package:nabd/widgets/avatar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isBiometricSupported = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final canCheckBiometrics = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    setState(() {
      _isBiometricSupported = canCheckBiometrics && isDeviceSupported;
    });

    if (_isBiometricSupported) {
  Future.delayed(const Duration(milliseconds: 500), () async {
    if (!mounted) return;
    // تشغيل صوت التنبيه
    await AudioHelper.playAssetSound('assets/sounds/FingerPrint.mp3');
    // ثم تابع المصادقة
    _authenticate();
  });
}
 else {
      // إذا لم يدعم الجهاز البيومتري، انتقل مباشرة
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'من فضلك استخدم بصمة الدخول',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
      );

      if (!mounted) return;

      if (didAuthenticate) {
        // تشغيل صوت النجاح
        final player = await AudioHelper.playAssetSound('assets/sounds/AuthSuccess.mp3');
        await player.onPlayerComplete.first;  // ينتظر حتى يكمل الملف
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        });
      } else {
        _navigateToSignup();
      }
    } on PlatformException {
      _navigateToSignup();
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _navigateToSignup() async {
    // تشغيل صوت الفشل ثم الانتقال
final player = await AudioHelper.playAssetSound('assets/sounds/AuthFailure.mp3');
await player.onPlayerComplete.first;    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignupScreen()),
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ConstValue.color1, ConstValue.color2],
          ),
        ),
        child: const Center(
          child: Avatar(size: 100),
        ),
      ),
    );
  }
}
