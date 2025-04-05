import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:nabd/screens/main_screen.dart';
import 'package:nabd/screens/signup_screen.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/widgets/avatar.dart';
import 'package:nabd/services/tts_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final TTSService _ttsService = TTSService();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  bool _isBiometricSupported = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
    _ttsService.initialize();
  }

  Future<void> _checkBiometricSupport() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    bool isDeviceSupported = await _localAuth.isDeviceSupported();
    setState(() {
      _isBiometricSupported = canCheckBiometrics && isDeviceSupported;
    });

    if (_isBiometricSupported) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          await _ttsService.speak("ابصم لتسجيل الدخول");
          _authenticate();
        }
      });
    } else {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainScreen()),
          );
        }
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating || !_isBiometricSupported) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to log in',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
      );

      if (!mounted) return;

      if (authenticated) {
        setState(() {
          _isAuthenticated = true;
        });
        await _ttsService.speak("تم");
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
            );
          }
        });
      } else {
        _navigateToSignup();
      }
    } on PlatformException {
      _navigateToSignup();
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _navigateToSignup() async {
    await _ttsService.speak("فشلت المصادقة، سيتم نقلك إلى صفحة التسجيل");
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SignupScreen()),
        );
      }
    });
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
        child: Center(
          child: Avatar(size: 100),
        ),
      ),
    );
  }
}
