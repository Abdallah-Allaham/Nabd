import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _flutterTts.setLanguage('ar-EG');

    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (text.isNotEmpty) {
      // نرجع Future يستنى لحد ما الكلام يخلّص
      Completer<void> completer = Completer();
      _flutterTts.setCompletionHandler(() {
        completer.complete();
      });
      await _flutterTts.speak(text);
      await completer.future; // نستنى لحد ما الكلام يخلّص
    }
  }
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}