import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:nabd/screens/main_screen.dart';
import 'package:nabd/widgets/avatar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  bool _isBiometricSupported = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  // دالة للتحقق من دعم المصادقة البيومترية
  Future<void> _checkBiometricSupport() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    bool isDeviceSupported = await _localAuth.isDeviceSupported();
    setState(() {
      _isBiometricSupported = canCheckBiometrics && isDeviceSupported;
    });

    // إذا كان الجهاز يدعم المصادقة البيومترية، ابدأ المصادقة تلقائيًا
    if (_isBiometricSupported) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _authenticate();
        }
      });
    } else {
      // إذا ما كان يدعم المصادقة، انقل المستخدم مباشرة إلى الـ MainScreen
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

  // دالة للمصادقة ببصمة الإصبع
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
          useErrorDialogs: false, // تعطيل أي حوارات إضافية من التطبيق
        ),
      );

      if (!mounted) return;

      setState(() {
        _isAuthenticated = authenticated;
      });

      if (authenticated) {
        // الانتقال إلى الـ MainScreen بعد النجاح
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
            );
          }
        });
      } else {
        // إذا فشلت المصادقة، أعد المحاولة تلقائيًا
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _authenticate();
          }
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      // إذا حصل خطأ، أعد المحاولة تلقائيًا
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _authenticate();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
          ),
        ),
        child: Stack(
          children: [
            // الأفاتار في المنتصف
            Center(child: Avatar(size: 100)),
            // شلنا أيقونة البصمة والنص التوضيحي
          ],
        ),
      ),
    );
  }
}
