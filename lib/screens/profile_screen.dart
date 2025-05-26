import 'package:flutter/material.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.stopListening();
    await _ttsService.stop();
    await _ttsService.speak("أنتقلت إلى الملف الشخصي");
    await Future.delayed(const Duration(milliseconds: 500)); // تأخير قصير
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
      ),
    );
  }
}