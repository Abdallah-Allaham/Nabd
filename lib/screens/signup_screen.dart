import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nabd/screens/login_screen.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/screens/main_screen.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/widgets/avatar.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RegistrationSteps(),
              Avatar(size: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class RegistrationSteps extends StatefulWidget {
  const RegistrationSteps({super.key});

  @override
  State<RegistrationSteps> createState() => _RegistrationStepsState();
}

class _RegistrationStepsState extends State<RegistrationSteps> {
  int _currentStep = 0;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();

  bool _isFingerprintAuthenticated = false;
  String _phoneNumber = '';
  String _name = '';
  String _guardianPhoneNumber = '';
  bool _registrationCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.initSpeech();
    _startStep(0);
  }

  Future<void> _startStep(int stepIndex) async {
    setState(() {
      _currentStep = stepIndex;
    });

    if (_registrationCompleted) return;

    _sttService.clearLastWords();

    switch (stepIndex) {
      case 0:
        await _ttsService.speak('يرجى وضع إصبعك لتسجيل بصمة الإصبع');
        await Future.delayed(const Duration(milliseconds: 150));
        _authenticateWithFingerprint();
        break;
      case 1:
        await _ttsService.speak('يرجى إدخال رقم هاتفك');
        await Future.delayed(const Duration(milliseconds: 150));
        await _listenForPhoneNumber();
        break;
      case 2:
        await _ttsService.speak('يرجى إدخال اسمك');
        await Future.delayed(const Duration(milliseconds: 150));
        await _listenForName();
        break;
      case 3:
        await _ttsService.speak('يرجى إدخال رقم هاتف المسؤول عنك');
        await Future.delayed(const Duration(milliseconds: 150));
        await _listenForGuardianPhoneNumber();
        break;
    }
  }

  Future<void> _authenticateWithFingerprint() async {
    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        await _ttsService.speak('جهازك لا يدعم بصمة الإصبع');
        return;
      }

      bool isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        await _ttsService.speak('البصمة غير مدعومة أو تم تعطيلها');
        return;
      }

      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'يرجى وضع إصبعك لتسجيل بصمة الإصبع',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        setState(() {
          _isFingerprintAuthenticated = true;
        });
        await _ttsService.speak('تم تسجيل بصمة الإصبع بنجاح');
        _startStep(1);
      } else {
        await _ttsService.speak('فشل تسجيل بصمة الإصبع، حاول مرة أخرى');
      }
    } catch (e) {
      print('Error in fingerprint authentication: $e');
      await _ttsService.speak('حدث خطأ في المصادقة، يرجى المحاولة لاحقًا');
    }
  }

  Future<void> _listenForPhoneNumber() async {
    _phoneNumber = await _waitForSpeechResult();
    if (_phoneNumber.isNotEmpty) {
      _startStep(2);
    } else {
      await _ttsService.speak('لم أسمع رقم الهاتف، يرجى المحاولة مرة أخرى');
      await _listenForPhoneNumber();
    }
  }

  Future<void> _listenForName() async {
    _name = await _waitForSpeechResult();
    if (_name.isNotEmpty) {
      _startStep(3);
    } else {
      await _ttsService.speak('لم أسمع الاسم، يرجى المحاولة مرة أخرى');
      await _listenForName();
    }
  }

  Future<void> _listenForGuardianPhoneNumber() async {
    _guardianPhoneNumber = await _waitForSpeechResult();
    if (_guardianPhoneNumber.isNotEmpty) {
      await _ttsService.speak(
        'تم التسجيل بنجاح',
      );
      setState(() {
        _registrationCompleted = true;
      });
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      await _ttsService.speak(
        'لم أسمع رقم هاتف المسؤول، يرجى المحاولة مرة أخرى',
      );
      await _listenForGuardianPhoneNumber();
    }
  }

  Future<String> _waitForSpeechResult() async {
    const maxDuration = Duration(seconds: 10);
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
    _sttService.stopListening();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stepper(
      currentStep: _currentStep,
      onStepTapped: (index) {
        if (_registrationCompleted) {
          setState(() {
            _currentStep = index;
          });
        }
      },
      steps: <Step>[
        Step(
          title: const Text(
            'بصمة الإصبع',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            _isFingerprintAuthenticated
                ? 'تم التسجيل بنجاح'
                : 'في انتظار التسجيل...',
            style: const TextStyle(color: Colors.white),
          ),
          isActive: _currentStep >= 0,
          state:
          _isFingerprintAuthenticated
              ? StepState.complete
              : StepState.indexed,
        ),
        Step(
          title: const Text(
            'رقم الهاتف',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            _phoneNumber.isEmpty ? 'في انتظار الرقم...' : _phoneNumber,
            style: const TextStyle(color: Colors.white),
          ),
          isActive: _currentStep >= 1,
          state:
          _phoneNumber.isNotEmpty ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('الاسم', style: TextStyle(color: Colors.white)),
          content: Text(
            _name.isEmpty ? 'في انتظار الاسم...' : _name,
            style: const TextStyle(color: Colors.white),
          ),
          isActive: _currentStep >= 2,
          state: _name.isNotEmpty ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text(
            'رقم هاتف المسؤول',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            _guardianPhoneNumber.isEmpty
                ? 'في انتظار الرقم...'
                : _guardianPhoneNumber,
            style: const TextStyle(color: Colors.white),
          ),
          isActive: _currentStep >= 3,
          state:
          _guardianPhoneNumber.isNotEmpty
              ? StepState.complete
              : StepState.indexed,
        ),
      ],
    );
  }
}
