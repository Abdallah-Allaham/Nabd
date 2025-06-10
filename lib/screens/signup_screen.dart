import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nabd/screens/login_screen.dart';
import 'package:nabd/screens/main_screen.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/utils/audio_helper.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/widgets/avatar.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  static const MethodChannel _voiceIdChannel = MethodChannel('nabd/voiceid');

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _stepIndex = 0;
  bool _registrationComplete = false;

  String _phoneNumber = '';
  String _name = '';
  String _guardianPhoneNumber = '';
  String _voiceIdStatus = '';
  String? _verificationId;
  int _resendAttempts = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.initSpeech();
    _askHasAccount();
  }

  String _convertArabicNumbers(String input) {
    const map = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };
    map.forEach((arab, lat) {
      input = input.replaceAll(arab, lat);
    });
    return input;
  }

  Future<void> _askHasAccount() async {
    setState(() => _stepIndex = 0);
final player = await AudioHelper.playAssetSound('assets/sounds/Welcome to the registration page.mp3');
      await player.onPlayerComplete.first;

final p2 = await AudioHelper.playAssetSound('assets/sounds/Do you have a registered account in the Nabd app.mp3');
    await p2.onPlayerComplete.first;
    String ans = (await _waitForSpeechResult()).toLowerCase();
    if (ans.contains('نعم') || ans.contains('عندي')|| ans.contains('يوجد')|| ans.contains('yes')) {
final player = await AudioHelper.playAssetSound('assets/sounds/Okay I willl take you to the login screen.mp3');
      await player.onPlayerComplete.first;
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
final player = await AudioHelper.playAssetSound('assets/sounds/Okay we willl start by entering your personal information.mp3');
      await player.onPlayerComplete.first;
       _askForPhone();
    }
  }

  Future<void> _askForPhone() async {
    setState(() => _stepIndex = 0);
final player = await AudioHelper.playAssetSound('assets/sounds/PleaseEnterYourPhoneNumber.mp3');
      await player.onPlayerComplete.first;
    String spoken = (await _waitForSpeechResult()).replaceAll(' ', '').trim();
    spoken = _convertArabicNumbers(spoken);

    if (!_validatePhoneFormat(spoken)) {
      final p = await AudioHelper.playAssetSound('assets/sounds/The number you entered is incorrect Make sure it starts with 079077or 078 and consists of 10 digits.mp3');
      await p.onPlayerComplete.first;
      return _askForPhone();
    }
    _phoneNumber = spoken.replaceFirst(RegExp(r'^0'), '+962');
    _confirmPhone();
  }

  bool _validatePhoneFormat(String phone) {
    final regex = RegExp(r'^07[789]\d{7}$');
    return regex.hasMatch(phone);
  }

  Future<void> _confirmPhone() async {
    setState(() => _stepIndex = 0);
final p1 = await AudioHelper.playAssetSound('assets/sounds/YouSaid.mp3');
await p1.onPlayerComplete.first;
await _ttsService.speak(_phoneNumber);
final p2 = await AudioHelper.playAssetSound('assets/sounds/IsThisYourCorrectNumber.mp3');
await p2.onPlayerComplete.first;
    String ans = (await _waitForSpeechResult()).toLowerCase();
    if (ans.contains('نعم')|| ans.contains('عندي')|| ans.contains('يوجد')|| ans.contains('yes')) {
      _checkPhoneExists();
    } else {
final player = await AudioHelper.playAssetSound('assets/sounds/Okay please re-enter your phone number.mp3');
      await player.onPlayerComplete.first;
      _askForPhone();
    }
  }

  Future<void> _checkPhoneExists() async {
    setState(() => _stepIndex = 0);
    try {
      final q = await _firestore
          .collection('users')
          .where('phone', isEqualTo: _phoneNumber)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final player = await AudioHelper.playAssetSound('assets/sounds/There is an account with this number you will be transferred to log in.mp3');
      await player.onPlayerComplete.first;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else {
final player = await AudioHelper.playAssetSound('assets/sounds/New number Authentication code will be sent.mp3');
      await player.onPlayerComplete.first;
      _startOtpFlow();
      }
    } catch (_) {
final p = await AudioHelper.playAssetSound('assets/sounds/Sorry but I didnt understand you well Could you repeat that.mp3');
      await p.onPlayerComplete.first;
       _askForPhone();
    }
  }

  Future<void> _startOtpFlow() async {
    _resendAttempts = 0;
    _auth.verifyPhoneNumber(
      phoneNumber: _phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        await _auth.signInWithCredential(cred);
        _onOtpVerified();
      },
      verificationFailed: (e) async {
        print('OTP Error: ${e.message}');
        _resendAttempts++;
final player = await AudioHelper.playAssetSound('assets/sounds/Failed to send code Please try again later.mp3');
      await player.onPlayerComplete.first;

      if (_resendAttempts < 3) _startOtpFlow();
        else _askForPhone();
      },
      codeSent: (verId, _) async {
        _verificationId = verId;
final player = await AudioHelper.playAssetSound('assets/sounds/Verification code has been sent Please wait a moment.mp3');
      await player.onPlayerComplete.first;
      await Future.delayed(const Duration(seconds: 4));
        _askForOtpManualEntry();
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _askForOtpManualEntry() async {
final player = await AudioHelper.playAssetSound('assets/sounds/Now enter the voice verification code.mp3');
      await player.onPlayerComplete.first;
       String code = (await _waitForSpeechResult()).replaceAll(' ', '').trim();
    if (code.length != 6) {
final player = await AudioHelper.playAssetSound('assets/sounds/The code must consist of 6 numbers.mp3');
      await player.onPlayerComplete.first;
      return _askForOtpManualEntry();
    }
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: code);
      await _auth.signInWithCredential(cred);
      _onOtpVerified();
    } catch (_) {
final player = await AudioHelper.playAssetSound('assets/sounds/This code is incorrect or expired Please try again later.mp3');
      await player.onPlayerComplete.first;
      _askForPhone();
    }
  }

  Future<void> _onOtpVerified() async {
    await _firestore
        .collection('users')
        .doc(_phoneNumber)
        .set({'phone': _phoneNumber});
final player = await AudioHelper.playAssetSound('assets/sounds/Verified successfully.mp3');
      await player.onPlayerComplete.first;
      _askForName();
  }

  Future<void> _askForName() async {
    setState(() => _stepIndex = 1);
final player = await AudioHelper.playAssetSound('assets/sounds/EnterPleaseYourName.mp3');
          await player.onPlayerComplete.first;
          _name = (await _waitForSpeechResult()).trim();
    await _firestore
        .collection('users')
        .doc(_phoneNumber)
        .update({'name': _name});
    _askGuardianPhoneOption();
  }

  Future<void> _askGuardianPhoneOption() async {
    setState(() => _stepIndex = 2);
   final player = await AudioHelper.playAssetSound('assets/sounds/Do you want to use the default 911 number or the official spokesperson number.mp3');
      await player.onPlayerComplete.first;
    String ans = (await _waitForSpeechResult()).toLowerCase();
    if (ans.contains('افتراضي') || ans.contains('٩١١')) {
      _guardianPhoneNumber = '911';
    } else {
 final player = await AudioHelper.playAssetSound('assets/sounds/EnterYourSupervisorsPhoneNumber.mp3');
          await player.onPlayerComplete.first;
          String sp = (await _waitForSpeechResult())
          .replaceAll(' ', '')
          .trim();
      if (!_validatePhoneFormat(sp)) return _askGuardianPhoneOption();
      _guardianPhoneNumber = '+962${sp.substring(1)}';
    }
    await _firestore
        .collection('users')
        .doc(_phoneNumber)
        .update({'guardian_phone': _guardianPhoneNumber});
    _askForVoiceId();
  }

Future<void> _askForVoiceId() async {
  setState(() => _stepIndex = 3);
  final player = await AudioHelper.playAssetSound('assets/sounds/RecordYourVoiceID.mp3');
  await player.onPlayerComplete.first;

  try {
    String res = await _voiceIdChannel.invokeMethod('enrollVoice');
    if (res == 'Voice enrolled successfully') {
      _voiceIdStatus = 'تم تسجيل الصوت بنجاح';
      final player = await AudioHelper.playAssetSound('assets/sounds/YourVoiceHasBeenSuccessfullyRecorded.mp3');
      await player.onPlayerComplete.first;
    } else if (res == 'Voice already enrolled') {
      _voiceIdStatus = 'الصوت مسجل مسبقًا';
      final player = await AudioHelper.playAssetSound('assets/sounds/YourVoiceIsPre-Recorded.mp3');
      await player.onPlayerComplete.first;
    } else {
      _voiceIdStatus = 'فشل التسجيل';
      final player = await AudioHelper.playAssetSound('assets/sounds/RegistrationFailed.mp3');
      await player.onPlayerComplete.first;
    }
    //  هنا يتم حفظ حالة الصوت في قاعدة البيانات
    await _firestore
        .collection('users')
        .doc(_phoneNumber)
        .update({'voice_id_status': _voiceIdStatus});

    await _ttsService.speak(_voiceIdStatus);
    _finishRegistration();
  } catch (e) {
    _voiceIdStatus = 'خطأ أثناء التسجيل';
    final player = await AudioHelper.playAssetSound('assets/sounds/AnErrorOccurred.mp3');
    await player.onPlayerComplete.first;
    _askForVoiceId();
  }
}

  Future<void> _finishRegistration() async {
    final player = await AudioHelper.playAssetSound('assets/sounds/RegistrationHasBeenCompletedSuccessfully.mp3',);
    await player.onPlayerComplete.first;
    setState(() => _registrationComplete = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  Future<String> _waitForSpeechResult() async {
    const maxDur = Duration(seconds: 8);
    const interval = Duration(milliseconds: 150);
    final start = DateTime.now();
    String last = '';
    await _sttService.startListening();
    while (DateTime.now().difference(start) < maxDur) {
      if (_sttService.lastWords.isNotEmpty) last = _sttService.lastWords;
      await Future.delayed(interval);
    }
    await _sttService.stopListening();
    return last;
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.person_add_alt_1, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Create a new account",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),


                Stepper(
                  currentStep: _stepIndex.clamp(0, 3),
                  steps: [
                    Step(
                      title: const Text('التحقق من رقم الهاتف',
                          style: TextStyle(color: Colors.white)),
                      content: Text(
                          _phoneNumber.isEmpty ? '...' : _phoneNumber,
                          style: const TextStyle(color: Colors.white)),
                      state: _stepIndex > 0
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: const Text('اسم المستخدم',
                          style: TextStyle(color: Colors.white)),
                      content:
                          Text(_name.isEmpty ? '...' : _name,
                              style: const TextStyle(color: Colors.white)),
                      state: _stepIndex > 1
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: const Text('رقم المسؤول',
                          style: TextStyle(color: Colors.white)),
                      content: Text(
                          _guardianPhoneNumber.isEmpty
                              ? '...' : _guardianPhoneNumber,
                          style: const TextStyle(color: Colors.white)),
                      state: _stepIndex > 2
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: const Text('تسجيل الصوت',
                          style: TextStyle(color: Colors.white)),
                      content: Text(
                          _voiceIdStatus.isEmpty
                              ? 'جارٍ التسجيل...' : _voiceIdStatus,
                          style: const TextStyle(color: Colors.white)),
                      state: _voiceIdStatus.contains('تم')
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                  ],
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
