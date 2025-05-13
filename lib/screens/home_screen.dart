import 'package:flutter/material.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  final bool openCamera;

  const HomeScreen({Key? key, this.openCamera = false}) : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late VideoPlayerController _controller;
  bool _showCamera = false;
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  bool _isVideoInitialized = false;
  bool _isCameraInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();

    if (widget.openCamera) {
      _openCamera();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    if (_isVideoInitialized) {
      _controller.pause();
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(
        'assets/videos/avatar_video.mp4',
      );
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.play();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      print("\u{1F6A8} خطأ أثناء تهيئة الفيديو: $e");
    }
  }

  Future<void> _openCamera() async {
    if (_isCameraInitializing || _showCamera) return;

    _isCameraInitializing = true;
    final granted = await _checkCameraPermission();
    if (!granted) {
      _isCameraInitializing = false;
      print("\u{1F6A8} إذن الكاميرا غير متاح");
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        print("\u{1F6AB} لا توجد كاميرات متاحة");
        _isCameraInitializing = false;
        return;
      }
      _cameraController?.dispose();
      _controller.pause();
      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.medium,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _showCamera = true;
          _isCameraInitializing = false;
        });
      } else {
        print("\u{1F6A8} الـ mounted غير متاح، الكاميرا لم تظهر");
      }
    } catch (e) {
      print("\u{1F6A8} خطأ أثناء تهيئة الكاميرا: $e");
      _isCameraInitializing = false;
    }
  }

  Future<bool> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  Future<void> openCamera() async {
    await _openCamera();
  }

  @override
  Widget build(BuildContext context) {
    final double avatarSize = 180;
    final double avatarPosition = MediaQuery.of(context).size.height / 2 - 90;

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
            Positioned.fill(child: CameraPreview(_cameraController!)),
          if (!_showCamera) // إظهار الـ Avatar فقط لو الكاميرا مش مفتوحة
            Positioned(
              bottom: avatarPosition,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 255, 254, 254),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child:
                      _isVideoInitialized
                          ? AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          )
                          : const SizedBox(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
