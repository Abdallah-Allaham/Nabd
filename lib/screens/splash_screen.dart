import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/widgets/avatar.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isExiting = false;
  bool _showAnimation = false; // متغير للتحكم في الأنيميشن

  TTSService _ttsService = TTSService();

  @override
  void initState() {
    super.initState();
    initializeTTS();
    // تشغيل الأنيميشن بعد تحميل الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _showAnimation = true;
      });
    });

    // الانتقال إلى صفحة الـ login بعد 3 ثواني
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isExiting = true;
      });

      // الانتظار حتى تنتهي أنيميشن الخروج ثم الانتقال
      Future.delayed(const Duration(milliseconds: 1000), () {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    });
  }

  Future<void> initializeTTS() async {
    await _ttsService.initialize();
    await _ttsService.speak('مرحبا بك في نبضْ');
  }

  @override
  void dispose() {
    _ttsService.stop();
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              // الأفاتار مع أنيميشن الخروج
              FadeOut(
                animate: _isExiting,
                duration: const Duration(milliseconds: 1000),
                child: const Avatar(size: 250),
              ),
              const SizedBox(height: 100),
              // النص مع أنيميشن الدخول والخروج
              if (_showAnimation) // التأكد من تشغيل الأنيميشن
                SlideInUp(
                  duration: const Duration(seconds: 2),
                  child: FadeOutRight(
                    animate: _isExiting,
                    duration: const Duration(milliseconds: 1000),
                    child: const Text(
                      'NABD',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.white54,
                            blurRadius: 10,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
