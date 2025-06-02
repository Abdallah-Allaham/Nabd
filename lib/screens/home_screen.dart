import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image/image.dart' as img;

class HomeScreen extends StatefulWidget {
  final bool openCamera;
  const HomeScreen({Key? key, required this.openCamera}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late VideoPlayerController _avatarController;
  late AnimationController _avatarAnimController;
  late Animation<double> _avatarSizeAnim;
  late Animation<double> _avatarPositionAnim;

  // هذا المتغير يتحكم بإظهار أو إخفاء الأفاتار بعد انتهاء الرسوم
  bool _showAvatar = true;

  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  bool _isProcessing = false;
  bool _showCamera = false;

  int? _lastClassId;
  final double _zoomLevel = 0.5;

  Uint8List? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initAvatar();

    // إذا طلب فتح الكاميرا من الداخل، نشغّل البث بعد الإطار الأول
    if (widget.openCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAndStream());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenHeight = MediaQuery.of(context).size.height;

    // الأفاتار سينتقل من منتصف الشاشة (screenHeight/2 - 90) إلى ما بعد أسفل الشاشة (+100)
    // أثناء تصغيره
    _avatarPositionAnim = Tween<double>(
      begin: screenHeight / 2 - 90,
      end: screenHeight + 100, // يجعله يختفي أسفل الشاشة
    ).animate(
      CurvedAnimation(parent: _avatarAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (!old.openCamera && widget.openCamera) {
      _openAndStream();
    }
  }

  @override
  void dispose() {
    _avatarController.dispose();
    _avatarAnimController.dispose();
    _cameraController?.dispose();
    _channelSub?.cancel();
    _channel?.sink.close();
    _ttsService.stop();
    _sttService.stopListening();
    super.dispose();
  }

  Future<void> _initAvatar() async {
    _avatarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _avatarSizeAnim = Tween<double>(begin: 180, end: 80).animate(
      CurvedAnimation(parent: _avatarAnimController, curve: Curves.easeInOut),
    );

    // نحدد قيمة أولية مؤقتة، ثم ستُحدَّث في didChangeDependencies
    _avatarPositionAnim = Tween<double>(begin: 0, end: 0).animate(_avatarAnimController);

    _avatarController = VideoPlayerController.asset('assets/videos/avatar_video.mp4');
    await _avatarController.initialize();
    _avatarController.setLooping(true);
    _avatarController.play();

    // عندما تنتهي رسوم الأفاتار، نخفيه تمامًا
    _avatarAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showAvatar = false);
      }
    });

    setState(() {});
  }

  Future<void> _openAndStream() async {
    await _sttService.stopListening();
    await _ttsService.stop();

    // نشغّل الأنيميشن الذي يصغر الأفاتار ويحركه للأسفل
    await _avatarAnimController.forward();
    await _ttsService.speak("تم فتح الكاميرا");

    if (!await Permission.camera.request().isGranted) return;

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _cameraController = CameraController(_cameras.first, ResolutionPreset.medium);
    await _cameraController!.initialize();
    await _cameraController!.setZoomLevel(_zoomLevel);

    setState(() {
      _showCamera = true;
      // نوقف الفيديو عند فتح الكاميرا
      _avatarController.pause();
    });

    _channel = IOWebSocketChannel.connect(
      Uri.parse('ws://192.168.137.1:8000/process_realtime_classify/'),
    );
    _channelSub = _channel!.stream.listen(_onMessage, onError: (e) {
      // يمكن إضافة معالجة الأخطاء هنا إن أردت
    });

    _cameraController!.startImageStream((camImg) async {
      if (_isProcessing) return;
      _isProcessing = true;

      final params = {
        'planes': [
          camImg.planes[0].bytes,
          camImg.planes[1].bytes,
          camImg.planes[2].bytes,
        ],
        'width': camImg.width,
        'height': camImg.height,
        'rowStride': camImg.planes[1].bytesPerRow,
        'pixStride': camImg.planes[1].bytesPerPixel ?? 1,
        'yRowStride': camImg.planes[0].bytesPerRow,
      };

      final Uint8List? jpegBytes = await compute(_convertYUV420ToJpeg, params);
      if (jpegBytes != null && _channel != null) {
        _channel!.sink.add(jpegBytes);
      }

      _isProcessing = false;
    });
  }

  void _onMessage(dynamic raw) {
    final data = json.decode(raw as String);
    if (data['status'] == 'interval') {
      final id = data['most_common_class_id'] as int;
      setState(() => _lastClassId = id);

      String directive;
      switch (id) {
        case 1:
        case 0:
          directive = "حرك الكاميرا إلى اليسار أعلى قليلاً";
          break;
        case 2:
        case 3:
          directive = "حرك الكاميرا إلى اليمين أعلى قليلاً";
          break;
        case 4:
          directive = "ارفع الكاميرا قليلاً";
          break;
        case 5:
          directive = "ثبت الكاميرا";
          _ttsService.speak(directive);
          _capturePhotoAndStop();
          return;
        default:
          directive = "وجه الكاميرا نحو النص";
      }
      _ttsService.speak(directive);
    }
  }

  Future<void> _capturePhotoAndStop() async {
    if (_cameraController?.value.isInitialized == true) {
      try {
        final XFile file = await _cameraController!.takePicture();
        final bytes = await file.readAsBytes();
        setState(() {
          _showCamera = false;
          _capturedImage = bytes;
        });
      } catch (_) {
        // تجاهل الأخطاء هنا
      }
    }

    _cameraController?.stopImageStream();
    await _channel?.sink.close();
    _channelSub?.cancel();
    _cameraController?.dispose();
    _cameraController = null;
  }

  static Future<Uint8List> _convertYUV420ToJpeg(Map<String, dynamic> params) async {
    final List<Uint8List> planes = params['planes'];
    final int w = params['width'], h = params['height'];
    final int rowStride = params['rowStride'];
    final int pixStride = params['pixStride'];
    final int yRowStride = params['yRowStride'];

    final buffer = List<int>.filled(w * h * 3, 0);
    int idx = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int uvIndex = pixStride * (x >> 1) + rowStride * (y >> 1);
        final int yp = planes[0][y * yRowStride + x];
        final int up = planes[1][uvIndex];
        final int vp = planes[2][uvIndex];
        final int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        final int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        final int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        buffer[idx++] = r;
        buffer[idx++] = g;
        buffer[idx++] = b;
      }
    }

    final imgDst = img.Image(width: w, height: h);
    idx = 0;
    for (int yy = 0; yy < h; yy++) {
      for (int xx = 0; xx < w; xx++) {
        imgDst.setPixelRgb(xx, yy, buffer[idx], buffer[idx + 1], buffer[idx + 2]);
        idx += 3;
      }
    }
    return Uint8List.fromList(img.encodeJpg(imgDst, quality: 85));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [ConstValue.color1, ConstValue.color2],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_showCamera && _cameraController?.value.isInitialized == true)
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
          if (_lastClassId != null)
            Positioned(
              top: 50, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Class: $_lastClassId',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            ),
          if (_showAvatar)
            Positioned(
              top: _avatarPositionAnim.value,
              child: AnimatedBuilder(
                animation: _avatarAnimController,
                builder: (context, child) {
                  return Container(
                    width: _avatarSizeAnim.value,
                    height: _avatarSizeAnim.value,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: _avatarController.value.isInitialized
                          ? VideoPlayer(_avatarController)
                          : Container(color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          if (_capturedImage != null)
            Positioned.fill(
              child: Image.memory(
                _capturedImage!,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }
}
