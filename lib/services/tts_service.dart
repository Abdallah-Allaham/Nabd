import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class TTSService {
  final String _apiKey = dotenv.env['OPENAI_API_KEY']!;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  Future<void> initialize() async {
    _isInitialized = true;
    // ما في إعدادات خاصة للـ OpenAI TTS حالياً، فبس نعمل فلاغ إنه صار initialized
  }


  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isNotEmpty) {
      var headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

      var request = http.Request(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/speech'),
      );

      request.body = json.encode({
        "model": "gpt-4o-mini-tts",
        "input": text,
        "voice": "sage",
        "response_format": "mp3"
      });

      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        Uint8List audioBytes = await response.stream.toBytes();

        // ✅ شغّل الملف الصوتي بصيغة mp3
        try {
          await _audioPlayer.play(BytesSource(audioBytes, mimeType: 'audio/mpeg'), volume: 1.0);
          await _audioPlayer.onPlayerComplete.first;
        } catch (e) {
          print('🔇 فشل تشغيل الصوت: $e');
        }


      } else {
        print("❌ خطأ في استدعاء TTS: ${response.reasonPhrase}");
      }
    }
  }


  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}