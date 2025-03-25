import 'package:speech_to_text/speech_to_text.dart' as stt;

class STTService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  String get lastWords => _lastWords;

  Future<bool> initSpeech() async {
    _speechEnabled = await _speech.initialize();
    return _speechEnabled;
  }

  Future<void> startListening() async {
    if (!_speechEnabled) {
      await initSpeech();
    }
    if (_speechEnabled) {
      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
        },
        localeId: 'ar_SA',
      );
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  // دالة جديدة لمسح الرد القديم
  void clearLastWords() {
    _lastWords = '';
  }

}