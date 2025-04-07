import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> initialize() async {
    await _flutterTts.setLanguage("ar-SA");
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
  }

  Future<void> speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
