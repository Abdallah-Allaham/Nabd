import 'package:flutter/material.dart';
import 'package:nabd/screens/login_screen.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/widgets/avatar.dart';
import 'package:flutter/services.dart';

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
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  static const voiceIdChannel = MethodChannel('nabd/voiceid');

  String _phoneNumber = '';
  String _name = '';
  String _guardianPhoneNumber = '';
  String _voiceIdStatus = ''; // لتخزين حالة تسجيل الصوت
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
        await _ttsService.speak('يرجى إدخال رقم هاتفك');
        await Future.delayed(const Duration(milliseconds: 150));
        await _listenForPhoneNumber();
        break;
      case 1:
        await _ttsService.speak('يرجى إدخال اسمك');
        await Future.delayed(const Duration(milliseconds: 150));
        await _listenForName();
        break;
      case 2:
        await _ttsService.speak('يرجى إدخال رقم هاتف المسؤول عنك');
        await Future.delayed(const Duration(milliseconds: 150));
        await _listenForGuardianPhoneNumber();
        break;
      case 3:
        await _ttsService.speak('يرجى تسجيل صوتك، تحدث لمدة 5 ثانية');
        await Future.delayed(const Duration(milliseconds: 150));
        await _enrollVoice();
        break;
    }
  }

  Future<void> _listenForPhoneNumber() async {
    _phoneNumber = await _waitForSpeechResult();
    if (_phoneNumber.isNotEmpty) {
      _startStep(1);
    } else {
      await _ttsService.speak('لم أسمع رقم الهاتف، حاول مرة أخرى');
      await _listenForPhoneNumber();
    }
  }

  Future<void> _listenForName() async {
    _name = await _waitForSpeechResult();
    if (_name.isNotEmpty) {
      _startStep(2);
    } else {
      await _ttsService.speak('لم أسمع الاسم، حاول مرة أخرى');
      await _listenForName();
    }
  }

  Future<void> _listenForGuardianPhoneNumber() async {
    _guardianPhoneNumber = await _waitForSpeechResult();
    if (_guardianPhoneNumber.isNotEmpty) {
      _startStep(3);
    } else {
      await _ttsService.speak('لم أسمع رقم هاتف المسؤول، حاول مرة أخرى');
      await _listenForGuardianPhoneNumber();
    }
  }

  Future<void> _enrollVoice() async {
    setState(() {
      _voiceIdStatus = 'جاري تسجيل الصوت...';
    });

    try {
      final String result = await voiceIdChannel.invokeMethod('enrollVoice');
      if (result == "Voice enrolled successfully") {
        setState(() {
          _voiceIdStatus = 'تم تسجيل الصوت بنجاح';
        });
        await _ttsService.speak('تم تسجيل الصوت بنجاح');
        _completeRegistration();
      } else if (result == "Voice already enrolled") {
        setState(() {
          _voiceIdStatus = 'الصوت مسجل مسبقًا';
        });
        await _ttsService.speak('الصوت مسجل مسبقًا');
        _completeRegistration();
      } else {
        setState(() {
          _voiceIdStatus = 'فشل التسجيل، حاول مرة أخرى';
        });
        await _ttsService.speak('فشل التسجيل، حاول مرة أخرى');
        await _enrollVoice(); // إعادة المحاولة
      }
    } catch (e) {
      setState(() {
        _voiceIdStatus = 'خطأ: $e';
      });
      await _ttsService.speak('حدث خطأ، حاول مرة أخرى');
      await _enrollVoice();
    }
  }

  Future<void> _completeRegistration() async {
    await _ttsService.speak('تم التسجيل بنجاح');
    setState(() {
      _registrationCompleted = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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
    return Column(
      children: [
        Stepper(
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
              title: const Text('رقم الهاتف', style: TextStyle(color: Colors.white)),
              content: Text(
                _phoneNumber.isEmpty ? 'في انتظار الرقم...' : _phoneNumber,
                style: const TextStyle(color: Colors.white),
              ),
              isActive: _currentStep >= 0,
              state: _phoneNumber.isNotEmpty ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('الاسم', style: TextStyle(color: Colors.white)),
              content: Text(
                _name.isEmpty ? 'في انتظار الاسم...' : _name,
                style: const TextStyle(color: Colors.white),
              ),
              isActive: _currentStep >= 1,
              state: _name.isNotEmpty ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('رقم هاتف المسؤول', style: TextStyle(color: Colors.white)),
              content: Text(
                _guardianPhoneNumber.isEmpty ? 'في انتظار الرقم...' : _guardianPhoneNumber,
                style: const TextStyle(color: Colors.white),
              ),
              isActive: _currentStep >= 2,
              state: _guardianPhoneNumber.isNotEmpty ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('تسجيل الصوت', style: TextStyle(color: Colors.white)),
              content: Text(
                _voiceIdStatus.isEmpty ? 'في انتظار التسجيل...' : _voiceIdStatus,
                style: const TextStyle(color: Colors.white),
              ),
              isActive: _currentStep >= 3,
              state: _voiceIdStatus == 'تم تسجيل الصوت بنجاح' || _voiceIdStatus == 'الصوت مسجل مسبقًا' ? StepState.complete : StepState.indexed,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_phoneNumber.isNotEmpty)
                Text("رقم الهاتف: $_phoneNumber", style: const TextStyle(color: Colors.white)),
              if (_name.isNotEmpty)
                Text("الاسم: $_name", style: const TextStyle(color: Colors.white)),
              if (_guardianPhoneNumber.isNotEmpty)
                Text("رقم المسؤول: $_guardianPhoneNumber", style: const TextStyle(color: Colors.white)),
              if (_voiceIdStatus.isNotEmpty)
                Text("حالة الصوت: $_voiceIdStatus", style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}