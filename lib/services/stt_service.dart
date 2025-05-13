import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class STTService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  String get lastWords => _lastWords;

  Future<bool> initSpeech() async {
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          print("🚨 إذن المايك مرفوض");
          return false;
        }
      }

      _speechEnabled = await _speech.initialize(
        onError: (error) => print("🚨 خطأ في STT: $error"),
      );
      return _speechEnabled;
    } catch (e) {
      print("🚨 خطأ أثناء تهيئة STT: $e");
      return false;
    }
  }

  Future<void> startListening() async {
    if (!_speechEnabled) {
      await initSpeech();
    }
    if (_speechEnabled) {
      await _speech.stop(); // التأكد من إيقاف أي استماع سابق
      _lastWords = '';
      try {
        await _speech.listen(
          onResult: (result) {
            _lastWords = result.recognizedWords;
          },
          localeId: 'ar_SA',
        );
      } catch (e) {
        print("🚨 خطأ أثناء بدء الاستماع: $e");
      }
    } else {
      print("🚨 STT غير مفعّل");
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      print("🚨 خطأ أثناء إيقاف الاستماع: $e");
    }
  }

  void clearLastWords() {
    _lastWords = '';
  }
}