import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:nabd/screens/profile_screen.dart';
import 'package:nabd/screens/setting_screen.dart';
import 'package:nabd/screens/home_screen.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/utils/audio_helper.dart';
import 'package:nabd/services/assistant_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _selectedIndex = 1;
  bool _openCamera = false;
  late TabController _tabController;
  String? _lastCommand;
  bool _isSpeaking = false;
  bool _isListening = false;
  String? _lastSpokenText;

  final List<Widget> _pages = [
    const ProfileScreen(),
    HomeScreen(openCamera: false),
    const SettingScreen(),
  ];

  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final AssistantService _assistantService = AssistantService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _selectedIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
          _openCamera = false;
          _pages[1] = HomeScreen(openCamera: _openCamera);
        });
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _sttService.stopListening();
    _ttsService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      print("⛔ التطبيق في الخلفية، سيتم إيقاف المساعد");
      _ttsService.stop();
      _sttService.stopListening();
      setState(() {
        _isListening = false;
        _isSpeaking = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      print("✅ عاد التطبيق إلى الواجهة، سيتم إعادة التشغيل");
      _initializeServices();
    }
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.initSpeech();
   // await _speakWithControl("جاهز للمساعدة");
    await _startListening();
  }

  Future<void> _speakWithControl(String text) async {
    if (_isSpeaking) {
      await _ttsService.stop();
    }
    setState(() {
      _isSpeaking = true;
      _lastSpokenText = text;
    });
    await _sttService.stopListening();
    setState(() => _isListening = false);
    print("🔊 بدء التحدث: $text");

    // الـ await هنا هينتظر اكتمال الصوت بسبب awaitSpeakCompletion(true)
    await _ttsService.speak(text);

    setState(() => _isSpeaking = false);
    print("🔊 انتهى التحدث: $text");
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_isListening && !_isSpeaking && mounted) {
      print("🎙️ بدء الاستماع...");
      try {
        setState(() => _isListening = true);
        await _sttService.startListening();
        _checkForCommand();
      } catch (e) {
        print("🚨 خطأ أثناء بدء الاستماع: $e");
        setState(() => _isListening = false);
     //   await _speakWithControl("حدث خطأ في الاستماع، سأحاول مرة أخرى");
      }
    } else if (_isSpeaking) {
      print("🎙️ الـ TTS شغال، بيتم الانتظار...");
    }
  }

  void _checkForCommand() {
    Future.delayed(const Duration(seconds: 6), () async {
      if (_sttService.lastWords.isNotEmpty && mounted) {
        String command = _sttService.lastWords;
        print("\u{1F4AC} الكلام الملتقط: $command");

        // تجاهل الكلام لو هو نفس النص اللي قاله الـ TTS
        if (_lastSpokenText != null && command.contains(_lastSpokenText!)) {
          print("🚫 الكلام الملتقط من الـ TTS، بيتم تجاهله: $command");
          _sttService.clearLastWords();
          await _sttService.stopListening();
          if (mounted) setState(() => _isListening = false);
          await _startListening();
          return;
        }

        if (_lastCommand == command) {
          print("🔁 تم تجاهل الأمر المتكرر: $command");
          _sttService.clearLastWords();
          await _sttService.stopListening();
          if (mounted) setState(() => _isListening = false);
          await _startListening();
          return;
        }
        _lastCommand = command;

        _sttService.clearLastWords();
        await _sttService.stopListening();
        if (mounted) setState(() => _isListening = false);

        try {
          String response = await _assistantService.sendMessageToAssistant(
            command,
          );
          print("\u{1F916} الرد من المساعد: $response");

          String cleaned =
              response.replaceAll(RegExp(r'[^\w\sء-ي]'), '').trim();

          if (cleaned == "0") {
            setState(() {
              _selectedIndex = 0;
              _openCamera = false;
              _tabController.index = _selectedIndex;
              _pages[1] = HomeScreen(openCamera: _openCamera);
            });
            await Future.delayed(Duration(seconds: 3));
            await _startListening();
          } else if (cleaned == "1") {
            setState(() {
              _selectedIndex = 1;
              _openCamera = false;
              _tabController.index = _selectedIndex;
              _pages[1] = HomeScreen(openCamera: _openCamera);
            });
            await Future.delayed(Duration(seconds: 3));
            await _startListening();
          } else if (cleaned == "2") {
            setState(() {
              _selectedIndex = 2;
              _openCamera = false;
              _tabController.index = _selectedIndex;
              _pages[1] = HomeScreen(openCamera: _openCamera);
            });
            await Future.delayed(Duration(seconds: 3));
            await _startListening();
          } else if (cleaned.contains("تم التنفيذ")) {
            if (_selectedIndex == 1) {
              setState(() {
                _selectedIndex = 1;
                _openCamera = true;
                _tabController.index = _selectedIndex;
                _pages[1] = HomeScreen(openCamera: _openCamera);
              });
            } else {
final player = await AudioHelper.playAssetSound('assets/sounds/YouAreNotOnTheHomePage.mp3');
        await player.onPlayerComplete.first;             }
            await Future.delayed(Duration(seconds: 3));
            await _startListening();
          } else if (cleaned.contains("اعد الكلام")) {
final player = await AudioHelper.playAssetSound('assets/sounds/SpeakAgain.mp3');
        await player.onPlayerComplete.first;
        await Future.delayed(Duration(seconds: 2));
            await _startListening();
          } else {}
        } catch (e) {
          print("\u{1F6A8} خطأ أثناء التواصل مع المساعد: $e");
final player = await AudioHelper.playAssetSound('assets/sounds/SomethingWentWrong.mp3');
        await player.onPlayerComplete.first;
        await Future.delayed(Duration(seconds: 3));
          await _startListening();
        }
      } else if (mounted && _isListening) {
        print("🎙️ لم يتم التقاط أي كلام، إعادة الاستماع...");
        await _sttService.stopListening();
        if (mounted) setState(() => _isListening = false);
        await Future.delayed(Duration(seconds: 3));
        await _startListening();
      }else{
       await _startListening();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: ConvexAppBar(
        controller: _tabController,
        items: const [
          TabItem(icon: Icons.person_outline, title: 'Profile'),
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.settings, title: 'Settings'),
        ],
        backgroundColor: Colors.white,
        color: const Color.fromARGB(255, 123, 123, 123),
        activeColor: Color.fromARGB(255, 15, 58, 107),
        style: TabStyle.reactCircle,
      ),
    );
  }
}
