import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/widgets/avatar.dart';
import 'package:nabd/utils/audio_helper.dart';  // تأكد من تعديل المسار إذا اختلف
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isExiting = false;
  bool _showAnimation = false;

  @override
  void initState() {
    super.initState();

    // شغّل الصوت من الأصول (غيّر المسار حسب الملف)
    AudioHelper.playAssetSound('assets/sounds/Welcome.mp3');

    // شغّل الأنيميشن بعد الإطار الأول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _showAnimation = true);
    });

    // بعد 3 ثواني، ابدأ أنيميشن الخروج ثم الانتقال
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => _isExiting = true);
      Future.delayed(const Duration(milliseconds: 1000), () {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    // نظّف مشغّل الصوت
    
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

              // نص "NABD" مع أنيميشن الدخول والخروج
              if (_showAnimation)
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
