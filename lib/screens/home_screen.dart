import 'package:flutter/material.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:video_player/video_player.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/services/assistant_service.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomePageState();
}

class _HomePageState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late VideoPlayerController _controller;
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final AssistantService _assistantService = AssistantService();
  bool _isListening = false;
  bool _showCamera = false;
  late AnimationController _avatarAnimController;
  late Animation<double> _avatarSizeAnim;
  late Animation<double> _avatarPositionAnim;
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  double _zoomLevel = 0.5; // قيمة التصغير الافتراضية (0.0 إلى 1.0)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
    _initializeServices();
    _avatarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _avatarSizeAnim = Tween<double>(begin: 180, end: 80).animate(
      CurvedAnimation(parent: _avatarAnimController, curve: Curves.easeInOut),
    );
    _avatarPositionAnim = Tween<double>(
      begin:
      MediaQueryData
          .fromWindow(
        WidgetsBinding.instance.window,
      )
          .size
          .height /
          2 -
          90,
      end: 30,
    ).animate(
      CurvedAnimation(parent: _avatarAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _sttService.stopListening();
    _ttsService.stop();
    _avatarAnimController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.resumed ) {
      print("⛔️ التطبيق في الخلفية، سيتم إيقاف المساعد");
      _ttsService.stop();
      _sttService.stopListening();
      setState(() => _isListening = false);
    } else if (state == AppLifecycleState.resumed) {
      print("✅ عاد التطبيق إلى الواجهة، سيتم إعادة التشغيل");
      _initializeServices();
    }
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset('assets/videos/avatar_video.mp4');
    await _controller.initialize();
    _controller.setLooping(true);
    _controller.play();
    if (mounted) setState(() {});
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.initSpeech();
    await _ttsService.speak("جاهز للمساعدة");
    await Future.delayed(const Duration(milliseconds: 600));
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_isListening && mounted && !_showCamera) {
      setState(() {
        _isListening = true;
      });
      await _sttService.startListening();
      _checkForCommand();
    }
  }

  void _checkForCommand() {
    Future.delayed(const Duration(seconds: 6), () async {
      if (_showCamera) return;

      if (_sttService.lastWords.isNotEmpty && mounted) {
        String command = _sttService.lastWords;
        print("\u{1F4AC} سيتم إرسال الأمر إلى المساعد: $command");

        _sttService.clearLastWords();
        await _sttService.stopListening();
        if (mounted) setState(() => _isListening = false);

        try {
          String response = await _assistantService.sendMessageToAssistant(
            command,
          );
          print("\u{1F916} الرد من المساعد: $response");

          String cleaned =
          response.replaceAll(RegExp(r'[^\w\sء-ي]'), '').trim();

          if (cleaned == "أعد الكلام") {
            await _ttsService.speak("أعد الكلام");
            await Future.delayed(const Duration(milliseconds: 600));
            await _startListening();
          } else if (cleaned.contains("تم التنفيذ")) {
            await _ttsService.speak("تم التنفيذ");
            await _runAvatarAndOpenCamera();
          } else {
            await _ttsService.speak(response);
            await Future.delayed(const Duration(milliseconds: 600));
            await _startListening();
          }
        } catch (e) {
          print("\u{1F6A8} خطأ أثناء التواصل مع المساعد: $e");
          await _ttsService.speak("حدث خطأ، حاول مرة أخرى");
          await Future.delayed(const Duration(milliseconds: 600));
          await _startListening();
        }
      } else if (mounted && _isListening && _sttService.lastWords.isEmpty) {
        print("⛔️ لم يتم التقاط أي كلام من المستخدم");

        await _sttService.stopListening();
        if (mounted) setState(() => _isListening = false);

        await _ttsService.speak("لم أسمع شيئًا");
        await Future.delayed(const Duration(seconds: 1));
        await _startListening();
      }
    });
  }

  Future<void> _runAvatarAndOpenCamera() async {
    if (mounted) await _avatarAnimController.forward();

    final granted = await _checkCameraPermission();
    if (!granted) {
      await _ttsService.speak("لا يمكن فتح الكاميرا، لم يتم منح الإذن");
      return;
    }

    await _initializeCamera();

    if (mounted &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      setState(() {
        _showCamera = true;
      });
    }
  }

  Future<bool> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        print("\u{1F6AB} لا توجد كاميرات متاحة");
        return;
      }
      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.medium,
      );
      await _cameraController!.initialize();
      if (_cameraController!.value.isInitialized) {
        await _cameraController!.setZoomLevel(_zoomLevel); // ضبط التصغير
      }
    } catch (e) {
      print("\u{1F6A8} خطأ أثناء تهيئة الكاميرا: $e");
    }
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_showCamera &&
              _cameraController != null &&
              _cameraController!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: _avatarAnimController,
            builder: (context, child) {
              return Positioned(
                bottom: _avatarPositionAnim.value,
                child: Container(
                  width: _avatarSizeAnim.value,
                  height: _avatarSizeAnim.value,
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 255, 254, 254),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child:
                    _controller.value.isInitialized
                        ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                        : const CircularProgressIndicator(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}