import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/utils/audio_helper.dart';


class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  static const _voiceIdChannel = MethodChannel('nabd/voiceid');

  bool   _isProcessing  = false;
  String _voiceIdStatus = '';

  @override
  void initState() {
    super.initState();
    _announcePage();
  }

  Future<void> _announcePage() async {
    // 1) أوقف الاستماع فوراً
    await _sttService.stopListening();

    // 2) جهّز الـ TTS وأعلن الصفحة
    await _ttsService.initialize();
    await _ttsService.speak("انتقلت إلى الإعدادات");
    // 3) بعد الإعلان، أعد تهيئة الكلام وابدأ الاستماع
    await _sttService.initSpeech();
    await _sttService.startListening();

    await _ttsService.stop();
final player = await AudioHelper.playAssetSound('assets/sounds/IWentToSettings.mp3');
        await player.onPlayerComplete.first;   
        await Future.delayed(const Duration(milliseconds: 500));
 
  }

  Future<void> _changeVoiceId() async {
    setState(() {
      _isProcessing  = true;
      _voiceIdStatus = 'جاري حذف بصمة الصوت القديمة...';
    });

    // أوقف الاستماع والـ TTS قبل كل خطوة
    await _sttService.stopListening();
    await _ttsService.stop();

    try {
      // حذف البصمة القديمة
      await _voiceIdChannel.invokeMethod('resetEnrollment');

      setState(() {
        _voiceIdStatus = 'تم الحذف، جاري تسجيل بصمة صوت جديدة...';
      });

      await _sttService.stopListening();
      await _ttsService.stop();
final player = await AudioHelper.playAssetSound('assets/sounds/RegisterANewVoicePrint.mp3');
        await player.onPlayerComplete.first;     
        await Future.delayed(const Duration(milliseconds: 500));
 

      // أخبر المستخدم بالتسجيل
      await _ttsService.speak(
          'تحدث الآن لمدة سبع ثوانٍ لتسجيل بصمة صوتية جديدة'
      );

      // انتظر 7 ثواني للتسجيل
      await Future.delayed(const Duration(seconds: 7));

      // نفّذ التسجيل فعلاً
      final result = await _voiceIdChannel.invokeMethod('enrollVoice');
      if (result == "Voice enrolled successfully") {

        setState(() => _voiceIdStatus = 'تم تسجيل بصمة الصوت بنجاح');
        await _ttsService.speak('تم تسجيل بصمة الصوت بنجاح');
      } else {
        setState(() => _voiceIdStatus = 'فشل تسجيل بصمة الصوت، حاول مرة أخرى');
        await _ttsService.speak('فشل تسجيل بصمة الصوت، حاول مرة أخرى');
      }
    } catch (e) {
      setState(() => _voiceIdStatus = 'حدث خطأ أثناء تغيير بصمة الصوت');
      await _ttsService.speak('حدث خطأ أثناء تغيير بصمة الصوت');

        setState(() {
          _voiceIdStatus = 'تم تسجيل بصمة الصوت الجديدة بنجاح';
        });
        await _sttService.stopListening();
        await _ttsService.stop();
final player = await AudioHelper.playAssetSound('assets/sounds/NewVoiceprintRegistrationSuccessfully.mp3');
        await player.onPlayerComplete.first;        
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        setState(() {
          _voiceIdStatus = 'فشل تسجيل بصمة الصوت، حاول مرة أخرى';
        });
        await _sttService.stopListening();
        await _ttsService.stop();
final player = await AudioHelper.playAssetSound('assets/sounds/VoiceprintRegistrationFailed.mp3');
        await player.onPlayerComplete.first;        
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      setState(() {
        _voiceIdStatus = 'حدث خطأ: $e';
      });
      await _sttService.stopListening();
      await _ttsService.stop();
final player = await AudioHelper.playAssetSound('assets/sounds/AnErrorOccurredWhileChangingTheVoicePrint.mp3');
        await player.onPlayerComplete.first;     
        await Future.delayed(const Duration(milliseconds: 500));
 
    } finally {
      // 1) إيقاف الـ TTS لو بقي شغال
      await _ttsService.stop();
      // 2) بعد كل شيء، أعِد تهيئة الكلام وابدأ الاستماع مجددًا
      setState(() => _isProcessing = false);
      await _sttService.initSpeech();
      await _sttService.startListening();
    }
  }

  @override
  void dispose() {
    _ttsService.stop();
    _sttService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A286D), Color(0xFF151922)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'إعدادات التطبيق',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _changeVoiceId,
                icon: const Icon(Icons.mic, color: Colors.white, size: 28),
                label: const Text(
                  'تغيير بصمة الصوت',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                ),
              ),
              const SizedBox(height: 20),
              if (_voiceIdStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _voiceIdStatus,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
