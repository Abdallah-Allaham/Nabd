import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nabd/screens/signup_screen.dart';
import 'package:nabd/screens/main_screen.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/utils/shared_preferences_helper.dart';
import 'package:nabd/utils/audio_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _askingHasAccount = false;
  bool _askingPhone = false;
  bool _confirmingPhone = false;
  bool _askingCreateAccount = false;

  String _rawPhoneInput = '';
  String _validatedPhone = '';

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyLoggedIn();
  }

  Future<void> _checkIfAlreadyLoggedIn() async {
    final hasLogged = SharedPreferencesHelper.instance.getHasLoggedIn();
    if (hasLogged) {
      _authenticateBiometric();
    } else {
      _initializeServices();
    }
  }

  Future<void> _authenticateBiometric() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();

    if (!mounted) return;

    if (canCheck && isSupported) {
      try {
        final didAuth = await _localAuth.authenticate(
          localizedReason: 'من فضلك استخدم بصمة الدخول',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: false,
          ),
        );
        if (didAuth && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        } else if (mounted) {
          final failSound = await AudioHelper.playAssetSound(
            'assets/sounds/Fingerprint authentication failed.mp3',
          );
          await failSound.onPlayerComplete.first;
          _initializeServices();
        }
      } catch (e) {
        if (mounted) {
          final errSound = await AudioHelper.playAssetSound(
            'assets/sounds/Fingerprint authentication error occurred.mp3',
          );
          await errSound.onPlayerComplete.first;
          _initializeServices();
        }
      }
    } else {
      if (mounted) {
        final noBio = await AudioHelper.playAssetSound(
          'assets/sounds/Your phone does not support fingerprint authentication.mp3',
        );
        await noBio.onPlayerComplete.first;
        _initializeServices();
      }
    }
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.initSpeech();
    _askHasAccount();
  }

  Future<void> _askHasAccount() async {
    setState(() {
      _askingHasAccount = true;
      _askingPhone = false;
      _confirmingPhone = false;
      _askingCreateAccount = false;
    });

    final p1 = await AudioHelper.playAssetSound('assets/sounds/You are now on the login page.mp3');
    await p1.onPlayerComplete.first;
    final p2 = await AudioHelper.playAssetSound('assets/sounds/Do you have a registered account in the Nabd app.mp3');
    await p2.onPlayerComplete.first;
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForHasAccountAnswer();
  }

  Future<void> _listenForHasAccountAnswer() async {
    String answer = await _waitForSpeechResult();
    answer = answer.trim().toLowerCase();

    if (answer.contains('نعم') || answer.contains('عندي') || answer.contains('يوجد')) {
      _askForPhoneNumber();
    } else if (answer.contains('لا') || answer.contains('ما عندي') || answer.contains('لا يوجد')) {
      final p = await AudioHelper.playAssetSound('assets/sounds/Now I will move to the account creation page.mp3');
      await p.onPlayerComplete.first;
      _navigateToSignup();
    } else {
      final p = await AudioHelper.playAssetSound('assets/sounds/Sorry but I didnt understand you well Could you repeat that.mp3');
      await p.onPlayerComplete.first;
      _askHasAccount();
    }
  }

  Future<void> _askForPhoneNumber() async {
    setState(() {
      _askingHasAccount = false;
      _askingPhone = true;
      _confirmingPhone = false;
      _askingCreateAccount = false;
    });

    final p = await AudioHelper.playAssetSound('assets/sounds/Enter your phone number by voice it must start with 07.mp3');
    await p.onPlayerComplete.first;
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForPhoneNumber();
  }

  Future<void> _listenForPhoneNumber() async {
    String spoken = await _waitForSpeechResult();
    spoken = spoken.replaceAll(' ', '').trim();
    _rawPhoneInput = spoken;

    final isValid = _validatePhoneFormat(_rawPhoneInput);
    if (!isValid) {
      final p = await AudioHelper.playAssetSound('assets/sounds/The number you entered is incorrect Make sure it starts with 079077or 078 and consists of 10 digits.mp3');
      await p.onPlayerComplete.first;
      _askForPhoneNumber();
      return;
    }

    _validatedPhone = _rawPhoneInput.replaceFirst(RegExp(r'^0'), '+962');
    _confirmPhoneWithUser();
  }

  bool _validatePhoneFormat(String phone) {
    final regex = RegExp(r'^(07[789]\d{7})$');
    return regex.hasMatch(phone);
  }

  Future<void> _confirmPhoneWithUser() async {
    setState(() {
      _askingPhone = false;
      _confirmingPhone = true;
    });

final p1 = await AudioHelper.playAssetSound('assets/sounds/YouSaid.mp3');
await p1.onPlayerComplete.first;

await _ttsService.speak(_rawPhoneInput);
final p2 = await AudioHelper.playAssetSound('assets/sounds/IsThisYourCorrectNumber.mp3');
await p2.onPlayerComplete.first;
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForPhoneConfirmation();
  }

  Future<void> _listenForPhoneConfirmation() async {
    String answer = await _waitForSpeechResult();
    answer = answer.trim().toLowerCase();

    if (answer.contains('نعم')|| answer.contains('عندي')|| answer.contains('يوجد')|| answer.contains('yes')) {
      _checkPhoneInFirestore();
  } else if (answer.contains('لا')|| answer.contains('ما عندي')|| answer.contains('لا يوجد')|| answer.contains('no')) {
      final p = await AudioHelper.playAssetSound('assets/sounds/Please re-enter your phone number again.mp3');
      await p.onPlayerComplete.first;
      _askForPhoneNumber();
    } else {
      final p = await AudioHelper.playAssetSound('assets/sounds/I didnt understand you well Can you repeat.mp3');
      await p.onPlayerComplete.first;
      _confirmPhoneWithUser();
    }
  }

  Future<void> _checkPhoneInFirestore() async {
    setState(() => _confirmingPhone = false);

    try {
      final query = await _firestore
          .collection('users')
          .where('phone', isEqualTo: _validatedPhone)
          .limit(1)
          .get();
      final exists = query.docs.isNotEmpty;

      if (!exists) {
        final p = await AudioHelper.playAssetSound('assets/sounds/But I did not find an account registered with this number.mp3');
        await p.onPlayerComplete.first;
        _askCreateAccount();
      } else {
        final p = await AudioHelper.playAssetSound('assets/sounds/The account has been found A verification code will be sent now.mp3');
        await p.onPlayerComplete.first;
        await _sendOTPAndVerify();
      }
    } catch (e) {
      final p = await AudioHelper.playAssetSound('assets/sounds/AnErrorOccurred.mp3');
      await p.onPlayerComplete.first;
      _askHasAccount();
    }
  }

  Future<void> _sendOTPAndVerify() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _validatedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await SharedPreferencesHelper.instance.setHasLoggedIn(true);
        _navigateToMain();
      },
      verificationFailed: (FirebaseAuthException e) async {
final player = await AudioHelper.playAssetSound('assets/sounds/Failed to send code Please try again later.mp3');
      await player.onPlayerComplete.first;
      _askForPhoneNumber();
      },
      codeSent: (String verificationId, int? resendToken) async {
final player = await AudioHelper.playAssetSound('assets/sounds/Verification code has been sent Please enter it now.mp3');
      await player.onPlayerComplete.first;
      String code = await _waitForSpeechResult();
        code = code.replaceAll(' ', '').trim();

        try {
          PhoneAuthCredential credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: code,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
          await SharedPreferencesHelper.instance.setHasLoggedIn(true);
          _navigateToMain();
        } catch (e) {
final player = await AudioHelper.playAssetSound('assets/sounds/The code is incorrect Please try again.mp3');
      await player.onPlayerComplete.first;
       _sendOTPAndVerify();
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) async {
final player = await AudioHelper.playAssetSound('assets/sounds/The code has timed out Please try again later.mp3');
      await player.onPlayerComplete.first;
      },
    );
  }

  Future<void> _askCreateAccount() async {
    setState(() => _askingCreateAccount = true);

    final p = await AudioHelper.playAssetSound('assets/sounds/Do you want to create a new account.mp3');
    await p.onPlayerComplete.first;
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForCreateAccountAnswer();
  }

  Future<void> _listenForCreateAccountAnswer() async {
    String answer = await _waitForSpeechResult();
    answer = answer.trim().toLowerCase();

    if (answer.contains('نعم')|| answer.contains('عندي')|| answer.contains('يوجد')|| answer.contains('yes')) {
      final p = await AudioHelper.playAssetSound('assets/sounds/Now I will open the account creation page.mp3');
      await p.onPlayerComplete.first;
      _navigateToSignup();
    } else if (answer.contains('لا')|| answer.contains('ما عندي')|| answer.contains('لا يوجد')|| answer.contains('no')) {
      final p = await AudioHelper.playAssetSound('assets/sounds/Let is re-enter the number.mp3');
      await p.onPlayerComplete.first;
      _askForPhoneNumber();
    } else {
      final p = await AudioHelper.playAssetSound('assets/sounds/I didnt understand you well Can you repeat.mp3');
      await p.onPlayerComplete.first;
      _askCreateAccount();
    }
  }

  void _navigateToSignup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  void _navigateToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  Future<String> _waitForSpeechResult() async {
    const maxDuration = Duration(seconds: 8);
    const checkInterval = Duration(milliseconds: 150);
    final startTime = DateTime.now();
    String lastResult = '';

    await _sttService.startListening();
    while (DateTime.now().difference(startTime) < maxDuration) {
      if (_sttService.lastWords.isNotEmpty) {
        lastResult = _sttService.lastWords;
      }
      await Future.delayed(checkInterval);
    }
    await _sttService.stopListening();
    return lastResult;
  }

  @override
  void dispose() {
    _ttsService.stop();
    _sttService.stopListening();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A286D), // ConstValue.color1
            Color(0xFF151922), // ConstValue.color2
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // شعار رمزي
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.hearing, // أيقونة قابلة للتبديل
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                Text(
                  'تطبيق نبض',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // جملة ترحيبية
                Text(
                  'مساعدك الصوتي الذكي للمكفوفين',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // أنيميشن تحميل
                CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 40),

                Text(
                  'جارٍ التحقق من الحساب...',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
