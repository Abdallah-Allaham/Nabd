import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // مطلوب لـ compute
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/utils/audio_helper.dart';
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
  /// Avatar video & animation controllers
  late VideoPlayerController _avatarController;
  late AnimationController    _avatarAnimController;
  late Animation<double>      _avatarSizeAnim;
  late Animation<double>      _avatarPositionAnim;

  /// TTS / STT services
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();

  /// Camera & WebSocket
  CameraController?      _cameraController;
  List<CameraDescription> _cameras = [];
  WebSocketChannel?      _channel;
  StreamSubscription?    _channelSub;
  bool                   _isProcessing = false;
  bool                   _showCamera   = false;

  /// Last received class ID from server
  int?                   _lastClassId;

  /// Zoom level for camera
  final double           _zoomLevel    = 0.5;

  @override
  void initState() {
    super.initState();
    _initAvatar();
    if (widget.openCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAndStream());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenHeight = MediaQuery.of(context).size.height;
    _avatarPositionAnim = Tween<double>(
      begin: screenHeight / 2 - 90,
      end: 30,
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
    // إعداد الأفتار والأنيميشن
    _avatarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _avatarSizeAnim = Tween<double>(begin: 180, end: 80).animate(
      CurvedAnimation(parent: _avatarAnimController, curve: Curves.easeInOut),
    );
    _avatarPositionAnim = Tween<double>(begin: 0, end: 0).animate(_avatarAnimController);

    _avatarController = VideoPlayerController.asset('assets/videos/avatar_video.mp4');
    await _avatarController.initialize();
    _avatarController.setLooping(true);
    _avatarController.play();
    setState(() {});
  }

  Future<void> _openAndStream() async {
    // 1) إيقاف الاستماع والـ TTS فورًا
    await _sttService.stopListening();
    await _ttsService.stop();

final player = await AudioHelper.playAssetSound('assets/sounds/IWentToTheHomePage.mp3');
        await player.onPlayerComplete.first;
        await Future.delayed(const Duration(milliseconds: 500));
  }

    // 2) أنيميشن الأفتار ثم نطق تأكيد فتح الكاميرا
    await _avatarAnimController.forward();
    await _ttsService.speak("تم فتح الكاميرا");

    // 3) طلب إذن الكاميرا
    if (!await Permission.camera.request().isGranted) return;

    // 4) تهيئة الكاميرا بدقة متوسطة (لتقليل حجم الصورة)
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _cameraController = CameraController(_cameras.first, ResolutionPreset.medium);
    await _cameraController!.initialize();
    await _cameraController!.setZoomLevel(_zoomLevel);

    setState(() {
      _showCamera = true;
      _avatarController.pause();
    });

    // 5) فتح WebSocket
    _channel = IOWebSocketChannel.connect(
      Uri.parse('ws://192.168.137.1:8000/process_realtime_classify/'),
    );
    _channelSub = _channel!.stream.listen(_onMessage, onError: (e) {
      // في حال خطأ في WebSocket
      // يمكن إضافة معالجة الخطأ هنا إذا لزم الأمر
    });

    // 6) بدء بث الصور: كل فريم يُمرَّر إلى Isolate عبر compute للتحويل
    _cameraController!.startImageStream((camImg) async {
      if (_isProcessing) return;
      _isProcessing = true;

      // تجهيز البيانات لتمريرها إلى Isolate
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

      // التحويل داخل Isolate عبر compute
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
      // حفظ آخر قيمة كلاس للاستعلام عنها في الواجهة
      setState(() => _lastClassId = id);

      // تعيين التوجيه الصوتي بناءً على رقم الكلاس
      String directive;
      switch (id) {
        case 1:
          directive = "حرك الكاميرا إلى اليسار اعلى قليلاً";
          break;
        case 2:
          directive = "حرك الكاميرا إلى اليمين اعلى قليلاً";
          break;
        case 3:
          directive = "حرك الكاميرا إلى اليمين اعلى قليلاً";
          break;
        case 0:
          directive = "حرك الكاميرا إلى اليسار اعلى قليلاً";
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

  /// يلتقط صورة نهائية ثم يوقف السترِيم والـ WebSocket، ويعرض الصورة الثابتة
  Future<void> _capturePhotoAndStop() async {
    if (_cameraController?.value.isInitialized == true) {
      try {
        final XFile file = await _cameraController!.takePicture();
        final bytes = await file.readAsBytes();
        // مخزنٌ للاستخدام إن أردنا عرضه لاحقًا
        setState(() {
          _showCamera = false;
          _capturedImage = bytes;
        });
      } catch (_) {
        // تجاهل الخطأ إن حصل
      }

  Future<void> _runAvatarAndOpenCamera() async {
    print("📷 محاولة فتح الكاميرا...");
    if (mounted) await _avatarAnimController.forward();

    final granted = await _checkCameraPermission();
    if (!granted) {
      print("❌ لا يوجد إذن للكاميرا!");
      await _sttService.stopListening();
      await _ttsService.stop();
final player = await AudioHelper.playAssetSound('assets/sounds/TheCameraCannotBeOpenedDueToLackOfPermission.mp3');
        await player.onPlayerComplete.first;
        await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        print("❌ لا توجد كاميرات متاحة!");
        await _sttService.stopListening();
        await _ttsService.stop();
final player = await AudioHelper.playAssetSound('assets/sounds/CameraIsNotAvailable.mp3');
        await player.onPlayerComplete.first;
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
final player = await AudioHelper.playAssetSound('assets/sounds/TheCameraIsOpened.mp3');
        await player.onPlayerComplete.first;
        await Future.delayed(const Duration(milliseconds: 500));
        }
      } else {
        print("❌ فشل تهيئة الكاميرا!");
        await _sttService.stopListening();
        await _ttsService.stop();
final player = await AudioHelper.playAssetSound('assets/sounds/CameraFailedToOpen.mp3');
        await player.onPlayerComplete.first;    
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print("🚨 خطأ أثناء فتح الكاميرا: $e");
      await _sttService.stopListening();
      await _ttsService.stop();
final player = await AudioHelper.playAssetSound('assets/sounds/AnErrorOccurredWhileOpeningTheCamera.mp3');
        await player.onPlayerComplete.first;   
        await Future.delayed(const Duration(milliseconds: 500));
 
    }

    // أوقف بث الكاميرا والـ WebSocket
    _cameraController?.stopImageStream();
    await _channel?.sink.close();
    _channelSub?.cancel();
    _cameraController?.dispose();
    _cameraController = null;
  }

  /// صورة ثابتة تعرض بعد التقاط الكلاس 5
  Uint8List? _capturedImage;

  /// دالة لتحويل YUV420 إلى JPEG في Isolate
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
          // ◼ معاينة الكاميرا: تملأ الشاشة عموديًّا وتقص العرض الزائد
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

          // ◼ عرض رقم الكلاس في أعلى الشاشة
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

          // ◼ عرض الصورة الثابتة بعد التقاط “ثبت الكاميرا”
          if (_capturedImage != null)
            Positioned.fill(
              child: Image.memory(
                _capturedImage!,
                fit: BoxFit.contain,
              ),
            ),

          // ◼ الأفتار في الأسفل قبل تشغيل الكاميرا أو عرض الصورة الثابتة
          if (!_showCamera && _capturedImage == null)
            AnimatedBuilder(
              animation: _avatarAnimController,
              builder: (ctx, ch) => Positioned(
                bottom: _avatarPositionAnim.value,
                child: Container(
                  width: _avatarSizeAnim.value,
                  height: _avatarSizeAnim.value,
                  decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                  ),
                  child: ClipOval(child: ch),
                ),
              ),
              child: _avatarController.value.isInitialized
                  ? AspectRatio(
                aspectRatio: _avatarController.value.aspectRatio,
                child: VideoPlayer(_avatarController),
              )
                  : const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
