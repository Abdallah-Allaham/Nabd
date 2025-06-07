import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nabd/screens/login_screen.dart';
import 'package:nabd/screens/main_screen.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/services/tts_service.dart';
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

  // **Firebase Instances**
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- State Variables ---
  int _stepIndex = 0;
  bool _registrationComplete = false;

  // بيانات المستخدم
  String _phoneNumber = '';
  String _name = '';
  String _guardianPhoneNumber = '911'; // القيمة الافتراضية إذا رفض إضافة رقم طوارئ
  String _voiceIdStatus = '';

  // بيانات OTP
  String? _verificationId;
  int _resendAttempts = 0;
  bool _otpSent = false;

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

  /// خطوة 1: نخبر المستخدم أننا في شاشة التسجيل ثم نسأله: "هل لديك حساب؟"
  Future<void> _askHasAccount() async {
    setState(() => _stepIndex = 0);

    await _ttsService.speak("أنت الآن في شاشة التسجيل.");
    await _ttsService.speak("هل لديك حساب بالفعل؟");

    await Future.delayed(const Duration(milliseconds: 200));
    _listenForHasAccountAnswer();
  }

  Future<void> _listenForHasAccountAnswer() async {
    String answer = await _waitForSpeechResult();
    answer = answer.trim().toLowerCase();

    if (answer.contains('نعم') || answer.contains('عندي')) {
      await _ttsService.speak("حسنًا، سأنقلك إلى شاشة تسجيل الدخول.");
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (answer.contains('لا') || answer.contains('ما عندي')) {
      await _ttsService.speak("حسنًا، سنبدأ بإدخال بياناتك.");
      _askForPhone();
    } else {
      await _ttsService.speak("عذرًا، لم أفهمك. هل يمكنك الإعادة؟");
      _askHasAccount();
    }
  }

  /// خطوة 2: نطلب رقم الهاتف صوتياً
  Future<void> _askForPhone() async {
    setState(() => _stepIndex = 1);

    await _ttsService.speak("من فضلك أدخل رقم هاتفك صوتيًا، يبدأ بصفر سبعة.");
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForPhone();
  }

  Future<void> _listenForPhone() async {
    String spoken = await _waitForSpeechResult();
    spoken = spoken.replaceAll(' ', '').trim();
    _phoneNumber = spoken;

    if (!_validatePhoneFormat(_phoneNumber)) {
      await _ttsService.speak(
        "هذا الرقم غير صحيح. تأكد أنه يبدأ بصفر سبعة تسعة أو صفر سبعة سبعة أو صفر سبعة ثمانية ويتكون من عشرة أرقام.",
      );
      _askForPhone();
      return;
    }

    _confirmPhone();
  }

  bool _validatePhoneFormat(String phone) {
    final regex = RegExp(r'^(07(9|7|8)\d{7})$');
    return regex.hasMatch(phone);
  }

  /// خطوة 3: نعيد قراءة الرقم للمستخدم ونسأله إن كان صحيحًا
  Future<void> _confirmPhone() async {
    setState(() => _stepIndex = 2);

    await _ttsService.speak("قلت: $_phoneNumber. هل هذا رقمك الصحيح؟");
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForPhoneConfirmation();
  }

  Future<void> _listenForPhoneConfirmation() async {
    String answer = await _waitForSpeechResult();
    answer = answer.trim().toLowerCase();

    if (answer.contains('نعم')) {
      _checkPhoneExists();
    } else if (answer.contains('لا')) {
      await _ttsService.speak("حسنًا، أعد إدخال رقم هاتفك.");
      _askForPhone();
    } else {
      await _ttsService.speak("عذرًا، لم أفهمك. هل يمكنك الإجابة بنعم أو لا؟");
      _confirmPhone();
    }
  }

  /// خطوة 4: نتحقق من وجود الرقم في قاعدة Firestore
  Future<void> _checkPhoneExists() async {
    setState(() => _stepIndex = 3);

    try {
      final query = await _firestore
          .collection('users')
          .where('phone', isEqualTo: _phoneNumber)
          .limit(1)
          .get();
      final exists = query.docs.isNotEmpty;

      if (exists) {
        // إذا وجد حساباً سابقاً
        await _ttsService.speak("تم العثور على حساب بهذا الرقم. هل تريد تسجيل الدخول الآن؟");
        await Future.delayed(const Duration(milliseconds: 200));
        _listenForExistingAccount();
      } else {
        // إذا لم يكن موجوداً
        await _ttsService.speak("هذا رقم جديد. سأرسل رمز التحقق الآن.");
        _startOtpFlow();
      }
    } catch (e) {
      await _ttsService.speak("حدث خطأ في الاتصال. سأعيد إدخال رقم الهاتف.");
      _askForPhone();
    }
  }

  Future<void> _listenForExistingAccount() async {
    String answer = await _waitForSpeechResult();
    answer = answer.trim().toLowerCase();

    if (answer.contains('نعم')) {
      await _ttsService.speak("حسنًا، سأفتح صفحة تسجيل الدخول.");
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (answer.contains('لا')) {
      await _ttsService.speak("حسنًا، أعد إدخال رقم هاتفك.");
      _askForPhone();
    } else {
      await _ttsService.speak("عذرًا، لم أفهمك. هل يمكنك الإجابة بنعم أو لا؟");
      _listenForExistingAccount();
    }
  }

  /// خطوة 5: نبدأ تدفّق الـ OTP عبر FirebaseAuth
  Future<void> _startOtpFlow() async {
    setState(() {
      _stepIndex = 4;
      _resendAttempts = 0;
      _otpSent = false;
    });
    _sendOtp();
  }

  void _sendOtp() {
    if (_resendAttempts >= 3) {
      _ttsService
          .speak(
            "عذرًا، لم نتمكن من إرسال الرمز بعد ثلاث محاولات. سنعيد إدخال رقم الهاتف.",
          )
          .then((_) => _askForPhone());
      return;
    }

    _auth.verifyPhoneNumber(
      phoneNumber: _phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: (_resendAttempts == 0 ? null : _resendAttempts),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // في حال تمّ التحقّق التلقائي
        await _auth.signInWithCredential(credential);
        _onOtpVerified();
      },
      verificationFailed: (FirebaseAuthException e) async {
        _resendAttempts++;
        if (_resendAttempts < 3) {
          await _ttsService.speak("فشل إرسال رمز التحقق، سأعيد المحاولة.");
          _sendOtp();
        } else {
          await _ttsService.speak(
            "عذرًا، لم نتمكن من إرسال الرمز بعد ثلاث محاولات. سنعيد إدخال رقم الهاتف.",
          );
          _askForPhone();
        }
      },
      codeSent: (String verificationId, int? resendToken) async {
        _verificationId = verificationId;
        _otpSent = true;
        _resendAttempts++;
        await _ttsService
            .speak(
              "تم إرسال رمز التحقق إلى رقم هاتفك. في حال لم تستلمه خلال ستون ثانية سأعيد الإرسال.",
            )
            .then((_) => _waitForAutoFillOrManual());
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // عند انتهاء مهلة الاسترجاع التلقائي
        if (_resendAttempts < 3) {
          _sendOtp();
        }
      },
    );
  }

  Future<void> _waitForAutoFillOrManual() async {
    // ننتظر قليلًا (مثلاً 5 ثوانٍ) لإمكانية auto-fill،
    // إن لم يحدث نصغي لإدخال الرمز صوتياً بشكل يدوي
    await Future.delayed(const Duration(seconds: 5));
    if (_otpSent) {
      _askForOtpManualEntry();
    }
  }

  /// خطوة 5b: نطلب من المستخدم إدخال الرمز صوتياً
  Future<void> _askForOtpManualEntry() async {
    await _ttsService.speak("من فضلك أدخل رمز التحقق صوتيًا.");
    await Future.delayed(const Duration(milliseconds: 200));
    String spokenOtp = await _waitForSpeechResult();
    spokenOtp = spokenOtp.replaceAll(' ', '').trim();

    if (spokenOtp.length != 6) {
      await _ttsService.speak("رمز التحقق يجب أن يتكون من ستة أرقام. حاول مرة أخرى.");
      _askForOtpManualEntry();
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: spokenOtp,
      );
      await _auth.signInWithCredential(credential);
      _onOtpVerified();
    } catch (e) {
      await _ttsService.speak("رمز التحقق غير صحيح أو انتهت صلاحيته. سأعيد إدخال رقم الهاتف.");
      _askForPhone();
    }
  }

  /// عند النجاح في التحقّق من OTP
  Future<void> _onOtpVerified() async {
    // نحفظ رقم الهاتف أولاً في Firestore
    await _firestore.collection('users').doc(_phoneNumber).set({
      'phone': _phoneNumber,
      'guardian_phone': '911', // القيمة الافتراضية، قد تتغيّر لاحقاً
    });

    await _ttsService.speak("تم التحقق من الرمز بنجاح.");
    _askForName();
  }

  /// خطوة 6: نطلب من المستخدم إدخال اسمه صوتياً
  Future<void> _askForName() async {
    setState(() => _stepIndex = 5);

    await _ttsService.speak("الآن رجاءً أدخل اسمك صوتيًا.");
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForName();
  }

  Future<void> _listenForName() async {
    String spoken = await _waitForSpeechResult();
    spoken = spoken.trim();
    _name = spoken;

    if (_name.isEmpty) {
      await _ttsService.speak("لم أسمع اسمك، حاول مرة أخرى.");
      _askForName();
      return;
    }

    await _ttsService.speak("قلت: $_name. هل هذا اسمك الصحيح؟");
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForNameConfirmation();
  }

  Future<void> _listenForNameConfirmation() async {
    String answer = await _waitForSpeechResult();
    answer = answer.trim().toLowerCase();

    if (answer.contains('نعم')) {
      await _firestore.collection('users').doc(_phoneNumber).update({
        'name': _name,
      });
      _askForGuardianDecision();
    } else if (answer.contains('لا')) {
      await _ttsService.speak("حسنًا، أعد إدخال اسمك.");
      _askForName();
    } else {
      await _ttsService.speak("عذرًا، لم أفهمك. هل يمكنك الإجابة بنعم أو لا؟");
      _listenForNameConfirmation();
    }
  }

  /// خطوة 7: نسأل المستخدم إذا يود إضافة رقم طوارئ/مسؤول
  Future<void> _askForGuardianDecision() async {
    setState(() => _stepIndex = 6);

    await _ttsService.speak("هل تريد إضافة رقم طوارئ أو رقم المسؤول عنك؟");
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForGuardianDecision();
  }

  Future<void> _listenForGuardianDecision() async {
    String answer = await _waitForSpeechResult();
    answer = answer.trim().toLowerCase();

    if (answer.contains('نعم')) {
      _askForGuardianPhone();
    } else if (answer.contains('لا')) {
      // إذا رفض، نستخدم الرقم الافتراضي 911
      _guardianPhoneNumber = '911';
      await _firestore.collection('users').doc(_phoneNumber).update({
        'guardian_phone': _guardianPhoneNumber,
      });
      await _ttsService.speak("تم استخدام الرقم الافتراضي ٩١١.");
      _askForVoiceId();
    } else {
      await _ttsService.speak("عذرًا، لم أفهمك. هل يمكنك الإجابة بنعم أو لا؟");
      _askForGuardianDecision();
    }
  }

  /// خطوة 7b: إذا أراد المستخدم إضافة رقم الطوارئ
  Future<void> _askForGuardianPhone() async {
    setState(() => _stepIndex = 7);

    await _ttsService.speak("من فضلك أدخل رقم الطوارئ صوتيًا، يبدأ بصفر سبعة.");
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForGuardianPhone();
  }

  Future<void> _listenForGuardianPhone() async {
    String spoken = await _waitForSpeechResult();
    spoken = spoken.replaceAll(' ', '').trim();
    _guardianPhoneNumber = spoken;

    if (!_validatePhoneFormat(_guardianPhoneNumber)) {
      await _ttsService.speak(
        "هذا الرقم غير صحيح. تأكد أنه يبدأ بصفر سبعة تسعة أو صفر سبعة سبعة أو صفر سبعة ثمانية ويتكون من عشرة أرقام.",
      );
      _askForGuardianPhone();
      return;
    }

    await _ttsService.speak("قلت: $_guardianPhoneNumber. هل هذا رقم الطوارئ الصحيح؟");
    await Future.delayed(const Duration(milliseconds: 200));
    _listenForGuardianConfirmation();
  }

  Future<void> _listenForGuardianConfirmation() async {
    String answer = await _waitForSpeechResult();
    answer = answer.trim().toLowerCase();

    if (answer.contains('نعم')) {
      await _firestore.collection('users').doc(_phoneNumber).update({
        'guardian_phone': _guardianPhoneNumber,
      });
      _askForVoiceId();
    } else if (answer.contains('لا')) {
      await _ttsService.speak("حسنًا، أعد إدخال رقم الطوارئ.");
      _askForGuardianPhone();
    } else {
      await _ttsService.speak("عذرًا، لم أفهمك. هل يمكنك الإجابة بنعم أو لا؟");
      _listenForGuardianConfirmation();
    }
  }

  /// خطوة 8: تسجيل بصمة الصوت (Voice ID)
  Future<void> _askForVoiceId() async {
    setState(() => _stepIndex = 8);

    await _ttsService.speak("الآن سنسجل بصمة صوتك. تحدث لمدة سبع ثوانٍ بثقة.");
    await Future.delayed(const Duration(milliseconds: 200));
    _recordVoiceId();
  }

  Future<void> _recordVoiceId() async {
    setState(() => _voiceIdStatus = 'جاري تسجيل الصوت...');

    try {
      final String result = await _voiceIdChannel.invokeMethod('enrollVoice');
      if (result == "Voice enrolled successfully") {
        setState(() => _voiceIdStatus = 'تم تسجيل الصوت بنجاح');
        await _ttsService.speak("تم تسجيل بصمة صوتك بنجاح.");
        _finishRegistration();
      } else if (result == "Voice already enrolled") {
        setState(() => _voiceIdStatus = 'الصوت مسجل مسبقًا');
        await _ttsService.speak("لقد سبق تسجيل بصمة صوتك.");
        _finishRegistration();
      } else {
        setState(() => _voiceIdStatus = 'فشل التسجيل، حاول مرة أخرى');
        await _ttsService.speak("فشل تسجيل بصمة الصوت، سأعيد المحاولة.");
        _recordVoiceId();
      }
    } catch (e) {
      setState(() => _voiceIdStatus = 'خطأ: $e');
      await _ttsService.speak("حدث خطأ أثناء تسجيل بصمة الصوت، سأعيد المحاولة.");
      _recordVoiceId();
    }
  }

  Future<void> _finishRegistration() async {
    setState(() => _registrationComplete = true);

    await Future.delayed(const Duration(seconds: 2));
    await _ttsService.speak("تم التسجيل بنجاح. جاري نقلك إلى الصفحة الرئيسية.");
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  /// دالة مساعدة لاستقبال الكلام عبر STT (مدة الاستماع 8 ثواني)
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ConstValue.color1, ConstValue.color2],
          ),
        ),
        child: Center(
          child: _registrationComplete
              // بعد الانتهاء نعرض الأفاتار لثواني ثم يُفتح الـ MainScreen
              ? const Avatar(size: 100)
              // أثناء الخطوات الصوتية نعرض مؤشر تحميل
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
