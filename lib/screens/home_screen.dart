import 'package:flutter/material.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:video_player/video_player.dart';
import 'package:nabd/services/tts_service.dart'; // مسار TTSService
import 'package:nabd/services/stt_service.dart'; // مسار STTService
import 'package:nabd/services/assistant_service.dart'; // مسار AssistantService

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomePageState();
}

class _HomePageState extends State<HomeScreen> {
  late VideoPlayerController _controller;
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final AssistantService _assistantService = AssistantService();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/avatar_video.mp4')
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.play();
        setState(() {});
      });
    _initializeServices();
  }

  // تهيئة الخدمات وتشغيل الصوت وفتح المايك
  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.initSpeech();

    // تشغيل "جاهز للمساعدة" وفتح المايك
    await _ttsService.speak("جاهز للمساعدة");
    _startListening();
  }

  // بدء الاستماع للأوامر
  Future<void> _startListening() async {
    if (!_isListening) {
      setState(() {
        _isListening = true;
      });
      await _sttService.startListening();
      _checkForCommand(); // مراقبة الأوامر
    }
  }

  // مراقبة الأوامر من المايك
  void _checkForCommand() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (_sttService.lastWords.isNotEmpty && mounted) {
        String command = _sttService.lastWords;
        _sttService.clearLastWords(); // مسح الكلام القديم
        await _sttService.stopListening(); // إيقاف المايك مؤقتًا
        setState(() {
          _isListening = false;
        });

        // إرسال الأمر للـ Assistant وتشغيل الرد صوتيًا
        try {
          String response = await _assistantService.sendMessageToAssistant(command);
          await _ttsService.speak(response); // تشغيل الرد بشكل صوتي
        } catch (e) {
          await _ttsService.speak("حدث خطأ، حاول مرة أخرى");
        }

        // إعادة فتح المايك بعد الرد
        if (mounted) {
          _startListening();
        }
      } else if (mounted && _isListening) {
        _checkForCommand(); // استمر في المراقبة إذا لسة ما في أمر
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _sttService.stopListening();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ConstValue.color1, ConstValue.color2],
        ),
      ),
      child: Center(
        child: Container(
          width: 180,
          height: 180,
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 255, 254, 254),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: _controller.value.isInitialized
                ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
                : const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}