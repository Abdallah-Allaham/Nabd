import 'package:flutter/material.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';

class HomeScreen extends StatefulWidget {
  final bool openCamera;

  const HomeScreen({Key? key, required this.openCamera}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomePageState();
}

class _HomePageState extends State<HomeScreen> with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  bool _showCamera = false;
  late AnimationController _avatarAnimController;
  late Animation<double> _avatarSizeAnim;
  late Animation<double> _avatarPositionAnim;
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  final double _zoomLevel = 0.5;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeVideo();
    _avatarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _avatarSizeAnim = Tween<double>(begin: 180, end: 80).animate(
      CurvedAnimation(parent: _avatarAnimController, curve: Curves.easeInOut),
    );
    _avatarPositionAnim = Tween<double>(
      begin: MediaQueryData.fromWindow(WidgetsBinding.instance.window).size.height / 2 - 90,
      end: 30,
    ).animate(
      CurvedAnimation(parent: _avatarAnimController, curve: Curves.easeInOut),
    );

    if (widget.openCamera) {
      _runAvatarAndOpenCamera();
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openCamera != oldWidget.openCamera && widget.openCamera) {
      _runAvatarAndOpenCamera();
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    _avatarAnimController.dispose();
    _cameraController?.dispose();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.stopListening();
    await _ttsService.stop();
    await _ttsService.speak("انتقلت إلى الصفحة الرئيسية");
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset('assets/videos/avatar_video.mp4');
    await _controller.initialize();
    _controller.setLooping(true);
    _controller.play();
    if (mounted) setState(() {});
  }

  Future<void> _runAvatarAndOpenCamera() async {
    print("📷 محاولة فتح الكاميرا...");
    if (mounted) await _avatarAnimController.forward();

    final granted = await _checkCameraPermission();
    if (!granted) {
      print("❌ لا يوجد إذن للكاميرا!");
      await _sttService.stopListening();
      await _ttsService.stop();
      await _ttsService.speak("لا يمكن فتح الكاميرا، لم يتم منح الإذن");
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        print("❌ لا توجد كاميرات متاحة!");
        await _sttService.stopListening();
        await _ttsService.stop();
        await _ttsService.speak("لا توجد كاميرا متاحة");
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }
      _cameraController = CameraController(_cameras.first, ResolutionPreset.medium);
      await _cameraController!.initialize();
      if (_cameraController!.value.isInitialized) {
        await _cameraController!.setZoomLevel(_zoomLevel);
        if (mounted) {
          setState(() {
            _showCamera = true;
          });
          await _sttService.stopListening();
          await _ttsService.stop();
          await _ttsService.speak("تم فتح الكاميرا");
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } else {
        print("❌ فشل تهيئة الكاميرا!");
        await _sttService.stopListening();
        await _ttsService.stop();
        await _ttsService.speak("فشل فتح الكاميرا، حاول مرة أخرى");
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print("🚨 خطأ أثناء فتح الكاميرا: $e");
      await _sttService.stopListening();
      await _ttsService.stop();
      await _ttsService.speak("حدث خطأ أثناء فتح الكاميرا، حاول مرة أخرى");
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<bool> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
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
          if (_showCamera && _cameraController != null && _cameraController!.value.isInitialized)
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
                    child: _controller.value.isInitialized
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