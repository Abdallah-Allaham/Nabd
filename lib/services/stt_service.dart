import 'package:speech_to_text/speech_to_text.dart' as stt;

class STTService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  String get lastWords => _lastWords;
  bool get isListening => _speech.isListening;

  bool get isSpeechEnabled => _speechEnabled;

  Future<bool> initSpeech() async {
    if (_speechEnabled && _speech.isAvailable) {
      return true;
    }
    _speechEnabled = await _speech.initialize(
      onError: (errorNotification) {
        print("STT Error: ${errorNotification.errorMsg}, Permanent: ${errorNotification.permanent}");
        if (errorNotification.permanent) {
          _speechEnabled = false;
        }
      },
      onStatus: (status) {
        print("STT Status: $status");
      },
    );
    return _speechEnabled;
  }

  Future<void> startListening() async {
    if (!isListening && _speechEnabled) {
      _lastWords = '';
      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
        },
        pauseFor: const Duration(seconds: 2),
        localeId: 'ar_SA',
      );
    } else if (!_speechEnabled) {
      print("STT service is not enabled, cannot start listening.");
    }
  }

  Future<void> stopListening() async {
    if (isListening) {
      await _speech.stop();
    }
  }

  void clearLastWords() {
    _lastWords = '';
  }

  void dispose() {
    _speech.cancel();
  }
}