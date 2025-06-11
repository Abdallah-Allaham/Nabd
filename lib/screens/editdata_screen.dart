import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nabd/screens/profile_screen.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/utils/audio_helper.dart';
import 'package:nabd/utils/const_value.dart';

class EditDataScreen extends StatefulWidget {
  final String currentPhone;
  final String currentName;
  final String currentGuardianPhone;
  final String currentVoiceIdStatus;

  const EditDataScreen({
    Key? key,
    required this.currentPhone,
    required this.currentName,
    required this.currentGuardianPhone,
    required this.currentVoiceIdStatus,
  }) : super(key: key);

  @override
  State<EditDataScreen> createState() => _EditDataScreenState();
}

class _EditDataScreenState extends State<EditDataScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  static const MethodChannel _voiceIdChannel = MethodChannel('nabd/voiceid');

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _stepIndex = 0;
  bool _editingComplete = false;

  String _phoneNumber = '';
  String _name = '';
  String _guardianPhoneNumber = '';
  String _voiceIdStatus = '';
  String? _verificationId;
  int _resendAttempts = 0;

  @override
  void initState() {
    super.initState();
    _phoneNumber = widget.currentPhone;
    _name = widget.currentName;
    _guardianPhoneNumber = widget.currentGuardianPhone;
    _voiceIdStatus = widget.currentVoiceIdStatus;
    _initializeServices().catchError((e) {
      print('Init error: $e');
      _handleError('خطأ أثناء التهيئة');
    });
  }

  Future<void> _initializeServices() async {
    try {
      await _ttsService.initialize();
      await _sttService.initSpeech();
      final player = await AudioHelper.playAssetSound('assets/sounds/Welcome to the edit profile page.mp3');
      await player.onPlayerComplete.first;
      _askWhatToEdit();
    } catch (e) {
      print('Service init error: $e');
      _handleError('فشل في تهيئة الخدمات');
    }
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

  Future<void> _askWhatToEdit() async {
  setState(() => _stepIndex = 0);
  try {
    final player = await AudioHelper.playAssetSound('assets/sounds/Welcome to the personal information editing page.mp3')
        .catchError((e) {
      print('Failed to play welcome sound: $e');
      return Future.value(null);
    });
    await player?.onPlayerComplete.first;

    final p2 = await AudioHelper.playAssetSound('assets/sounds/What would you like to edit.mp3')
        .catchError((e) {
      print('Failed to play what to edit sound: $e');
      return Future.value(null);
    });
    await p2?.onPlayerComplete.first;

    String ans = (await _waitForSpeechResult()).toLowerCase();

    if (ans.contains('رقم') || ans.contains('هاتف') || ans.contains('phone')) {
      _askForPhone();
    } else if (ans.contains('اسم') || ans.contains('name')) {
      _askForName();
    } else if (ans.contains('مسؤول') || ans.contains('guardian') || ans.contains('ولي')) {
      _askGuardianPhoneOption();
    } else if (ans.contains('صوت') || ans.contains('voice')) {
      _askForVoiceId();
    } else {
      final p = await AudioHelper.playAssetSound('assets/sounds/Sorry but I didnt understand you well Could you repeat that.mp3')
          .catchError((e) {
        print('Failed to play repeat sound: $e');
        return Future.value(null);
      });
      await p?.onPlayerComplete.first;
      _askWhatToEdit();
    }
  } catch (e) {
    print('Ask what to edit error: $e');
    _handleError('فشل في فهم الطلب');
  }
}

  Future<void> _askForPhone() async {
    setState(() => _stepIndex = 0);
    try {
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
    } catch (e) {
      print('Ask for phone error: $e');
      _handleError('خطأ أثناء إدخال الرقم');
    }
  }

  bool _validatePhoneFormat(String phone) {
    final regex = RegExp(r'^07[789]\d{7}$');
    return regex.hasMatch(phone);
  }

  Future<void> _confirmPhone() async {
    setState(() => _stepIndex = 0);
    try {
      final p1 = await AudioHelper.playAssetSound('assets/sounds/YouSaid.mp3');
      await p1.onPlayerComplete.first;
      await _ttsService.speak(_phoneNumber);
      final p2 = await AudioHelper.playAssetSound('assets/sounds/IsThisYourCorrectNumber.mp3');
      await p2.onPlayerComplete.first;
      String ans = (await _waitForSpeechResult()).toLowerCase();
      if (ans.contains('نعم') || ans.contains('عندي') || ans.contains('يوجد') || ans.contains('yes')) {
        _checkPhoneExists();
      } else {
        final player = await AudioHelper.playAssetSound('assets/sounds/Okay please re-enter your phone number.mp3');
        await player.onPlayerComplete.first;
        _askForPhone();
      }
    } catch (e) {
      print('Confirm phone error: $e');
      _handleError('خطأ أثناء تأكيد الرقم');
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
      if (q.docs.isNotEmpty && _phoneNumber != widget.currentPhone) {
        final player = await AudioHelper.playAssetSound('assets/sounds/There is an account with this number you will be transferred to log in.mp3');
        await player.onPlayerComplete.first;
        _askForPhone();
      } else {
        final player = await AudioHelper.playAssetSound('assets/sounds/New number Authentication code will be sent.mp3');
        await player.onPlayerComplete.first;
        _startOtpFlow();
      }
    } catch (e) {
      print('Check phone exists error: $e');
      _handleError('خطأ أثناء التحقق من الرقم');
    }
  }

  Future<void> _startOtpFlow() async {
    _resendAttempts = 0;
    try {
      await _auth.verifyPhoneNumber(
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
    } catch (e) {
      print('Start OTP flow error: $e');
      _handleError('فشل في إرسال رمز التحقق');
    }
  }

  Future<void> _askForOtpManualEntry() async {
    try {
      final player = await AudioHelper.playAssetSound('assets/sounds/Now enter the voice verification code.mp3');
      await player.onPlayerComplete.first;
      String code = (await _waitForSpeechResult()).replaceAll(' ', '').trim();
      if (code.length != 6) {
        final player = await AudioHelper.playAssetSound('assets/sounds/The code must consist of 6 numbers.mp3');
        await player.onPlayerComplete.first;
        return _askForOtpManualEntry();
      }
      final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: code);
      await _auth.signInWithCredential(cred);
      _onOtpVerified();
    } catch (e) {
      print('OTP entry error: $e');
      _handleError('خطأ في إدخال رمز التحقق');
    }
  }

  Future<void> _onOtpVerified() async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.currentPhone)
          .update({'phone': _phoneNumber});
      final player = await AudioHelper.playAssetSound('assets/sounds/Verified successfully.mp3');
      await player.onPlayerComplete.first;
      _finishEditing();
    } catch (e) {
      print('OTP verified error: $e');
      _handleError('خطأ أثناء التحقق');
    }
  }

  Future<void> _askForName() async {
    setState(() => _stepIndex = 1);
    try {
      final player = await AudioHelper.playAssetSound('assets/sounds/EnterPleaseYourName.mp3');
      await player.onPlayerComplete.first;
      _name = (await _waitForSpeechResult()).trim();
      await _firestore
          .collection('users')
          .doc(widget.currentPhone)
          .update({'name': _name});
      _finishEditing();
    } catch (e) {
      print('Ask for name error: $e');
      _handleError('خطأ أثناء إدخال الاسم');
    }
  }

  Future<void> _askGuardianPhoneOption() async {
    setState(() => _stepIndex = 2);
    try {
      final player = await AudioHelper.playAssetSound('assets/sounds/Do you want to use the default 911 number or the official spokesperson number.mp3');
      await player.onPlayerComplete.first;
      String ans = (await _waitForSpeechResult()).toLowerCase();
      if (ans.contains('افتراضي') || ans.contains('٩١١')) {
        _guardianPhoneNumber = '911';
      } else {
        final p = await AudioHelper.playAssetSound('assets/sounds/EnterYourSupervisorsPhoneNumber.mp3');
        await p.onPlayerComplete.first;
        String sp = (await _waitForSpeechResult()).replaceAll(' ', '').trim();
        if (!_validatePhoneFormat(sp)) return _askGuardianPhoneOption();
        _guardianPhoneNumber = '+962${sp.substring(1)}';
      }
      await _firestore
          .collection('users')
          .doc(widget.currentPhone)
          .update({'guardian_phone': _guardianPhoneNumber});
      _finishEditing();
    } catch (e) {
      print('Ask guardian phone error: $e');
      _handleError('خطأ أثناء إدخال رقم المسؤول');
    }
  }

  Future<void> _askForVoiceId() async {
    setState(() => _stepIndex = 3);
    try {
      if (widget.currentVoiceIdStatus.contains('تم') || widget.currentVoiceIdStatus.contains('مسجل')) {
        final player = await AudioHelper.playAssetSound('assets/sounds/YourVoiceIsPre-Recorded.mp3');
        await player.onPlayerComplete.first;
        final p2 = await AudioHelper.playAssetSound('assets/sounds/Voice ID cannot be changed.mp3');
        await p2.onPlayerComplete.first;
        _finishEditing();
        return;
      }

      final player = await AudioHelper.playAssetSound('assets/sounds/RecordYourVoiceID.mp3');
      await player.onPlayerComplete.first;

      String res = await _voiceIdChannel.invokeMethod('enrollVoice');
      if (res == 'Voice enrolled successfully') {
        _voiceIdStatus = 'تم تسجيل الصوت بنجاح';
        final p = await AudioHelper.playAssetSound('assets/sounds/YourVoiceHasBeenSuccessfullyRecorded.mp3');
        await p.onPlayerComplete.first;
      } else if (res == 'Voice already enrolled') {
        _voiceIdStatus = 'الصوت مسجل مسبقًا';
        final p = await AudioHelper.playAssetSound('assets/sounds/YourVoiceIsPre-Recorded.mp3');
        await p.onPlayerComplete.first;
      } else {
        _voiceIdStatus = 'فشل التسجيل';
        final p = await AudioHelper.playAssetSound('assets/sounds/RegistrationFailed.mp3');
        await p.onPlayerComplete.first;
      }

      await _firestore
          .collection('users')
          .doc(widget.currentPhone)
          .update({'voice_id_status': _voiceIdStatus});
      await _ttsService.speak(_voiceIdStatus);
      _finishEditing();
    } catch (e) {
      print('Voice ID error: $e');
      _voiceIdStatus = 'خطأ أثناء التسجيل';
      final p = await AudioHelper.playAssetSound('assets/sounds/AnErrorOccurred.mp3');
      await p.onPlayerComplete.first;
      _askForVoiceId();
    }
  }

  Future<void> _finishEditing() async {
    try {
      final player = await AudioHelper.playAssetSound('assets/sounds/RegistrationHasBeenCompletedSuccessfully.mp3');
      await player.onPlayerComplete.first;
      setState(() => _editingComplete = true);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    } catch (e) {
      print('Finish editing error: $e');
      _handleError('خطأ أثناء حفظ التعديلات');
    }
  }

  Future<String> _waitForSpeechResult() async {
    try {
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
    } catch (e) {
      print('Speech result error: $e');
      return '';
    }
  }

  void _handleError(String message) {
    AudioHelper.playAssetSound('assets/sounds/AnErrorOccurred.mp3').then((player) async {
      await player.onPlayerComplete.first;
      _askWhatToEdit(); // إعادة المحاولة بعد الخطأ
    }).catchError((e) {
      print('Error playing error sound: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ConstValue.color1, ConstValue.color2],
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
                        Icon(Icons.edit, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Text(
                          "Edit Profile Information",
                          style: TextStyle(
                            fontSize: 24,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Current Information:",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildCurrentInfoRow("Phone:", _phoneNumber),
                        _buildCurrentInfoRow("Name:", _name),
                        _buildCurrentInfoRow("Guardian Phone:", _guardianPhoneNumber),
                        _buildCurrentInfoRow("Voice ID:", _voiceIdStatus),
                      ],
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

  Widget _buildCurrentInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'لا يوجد معلومات',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}