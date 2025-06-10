import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:nabd/screens/profile_screen.dart';
import 'package:nabd/screens/setting_screen.dart';
import 'package:nabd/screens/home_screen.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/services/assistant_service.dart';
import 'package:nabd/utils/audio_helper.dart';
import 'dart:async';

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

  bool _isSpeaking = false;
  bool _isListening = false;
  String? _lastSpokenText;
  String? _lastCommand;
  bool _assetSoundPlayed = false;
  bool _isHomeFirstVisit = true;

  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final AssistantService _assistantService = AssistantService();

  List<Widget> get _pages => [
    const ProfileScreen(),
    HomeScreen(openCamera: _openCamera),
    const SettingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 3, vsync: this, initialIndex: _selectedIndex)
      ..addListener(_onTabChanged);

    _initializeServicesAndWelcome();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _ttsService.stop();
    _sttService.stopListening();
    _sttService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ttsService.stop();
      _sttService.stopListening();
      _isListening = false;
      _isSpeaking = false;
    } else if (state == AppLifecycleState.resumed) {
      if (!_openCamera) {
        _sttService.initSpeech();
      }
    }
  }

  Future<void> _initializeServicesAndWelcome() async {
    bool initialized = await _sttService.initSpeech();
    if (initialized) {
      await _ttsService.initialize();
      try {
        await _ttsService.speak(' ');
        await Future.delayed(const Duration(milliseconds: 50));
        await _ttsService.stop();
        print("TTS initialized with a dummy sound.");
      } catch (e) {
        print("Error initializing TTS with dummy sound: $e");
      }

      await _speakWithControl("جاهز للمساعدة، انقر على الشاشة للتحدث.");
    } else {
      await _speakWithControl("عذراً، لا يمكن بدء خدمة التعرف على الكلام. قد تحتاج لتأكيد أذونات الميكروفون.");
    }
  }

  Future<void> _speakWithControl(String text) async {
    if (_assetSoundPlayed) {
      _assetSoundPlayed = false;
      return;
    }

    if (_isSpeaking) {
      await _ttsService.stop();
    }
    _isSpeaking = true;
    _lastSpokenText = text;

    await _sttService.stopListening();
    _isListening = false;

    await _ttsService.speak(text);
    _isSpeaking = false;
  }

  Future<void> _playAssetSoundWithControl(String assetPath) async {
    if (_isSpeaking) {
      await _ttsService.stop();
      _isSpeaking = false;
    }
    await _sttService.stopListening();
    _isListening = false;

    try {
      final player = await AudioHelper.playAssetSound(assetPath);
      await player.onPlayerComplete.first;
      _assetSoundPlayed = true;
    } catch (e) {
      print("ERROR: Failed to play asset sound $assetPath: $e");
    }
  }

  Future<void> _playHomePageAnnounce() async {
    print("DEBUG: _playHomePageAnnounce called. _openCamera: $_openCamera, _isSpeaking: $_isSpeaking");
    if (!_openCamera && !_isSpeaking) {
      await _sttService.stopListening();
      await _ttsService.stop();

      try {
        print("DEBUG: Attempting to play HomePage.wav from path 'assets/sounds/HomePage.wav'.");
        final player = await AudioHelper.playAssetSound('assets/sounds/HomePage.wav');
        await player.onPlayerComplete.first;
        print("Home page announced via asset sound.");
      } catch (e) {
        print("ERROR: Failed to play HomePage.wav: $e. Falling back to TTS.");
        await _ttsService.speak("تم الانتقال إلى الصفحة الرئيسية.");
        print("Home page announcement played via TTS (fallback).");
      }
    } else {
      print("WARNING: _playHomePageAnnounce called but _openCamera or _isSpeaking is true.");
    }
  }

  Future<void> _startListening() async {
    if (_isListening || _isSpeaking) return;

    if (!_sttService.isSpeechEnabled) {
      print("STT service not enabled. Re-initializing.");
      bool success = await _sttService.initSpeech();
      if (!success) {
        await _speakWithControl("عذراً، لا يمكن بدء الاستماع. الرجاء التحقق من إعدادات المايكروفون.");
        return;
      }
    }

    setState(() {
      _isListening = true;
    });

    try {
      await _sttService.startListening();
      print("MainScreen: STTService.startListening called.");

      await Future.delayed(const Duration(seconds: 4));

      await _sttService.stopListening();
      setState(() {
        _isListening = false;
      });

      final String recognizedWords = _sttService.lastWords;
      print("Recognized words after delay: '$recognizedWords'");

      _processCommand(recognizedWords);

    } catch (e) {
      print("Error in _startListening: $e");
      setState(() {
        _isListening = false;
      });
      await _playAssetSoundWithControl('assets/sounds/SomethingWentWrong.mp3');
    }
  }

  Future<void> _processCommand(String cmd) async {
    if (!mounted) return;
    print("Processing command: '$cmd'");

    _assetSoundPlayed = false;

    if (cmd.isEmpty) {
      await _speakWithControl("لم أفهم، من فضلك أعد الكلام.");
      return;
    }

    if (_lastSpokenText != null && cmd.trim() == _lastSpokenText!.trim()) {
      _sttService.clearLastWords();
      return;
    }
    if (_lastCommand == cmd) {
      _sttService.clearLastWords();
      return;
    }
    _lastCommand = cmd;

    _sttService.clearLastWords();

    try {
      final resp = await _assistantService.sendMessageToAssistant(cmd);
      final cleaned = resp.replaceAll(RegExp(r'[^\w\sء-ي]'), '').trim();
      print("Assistant response cleaned: '$cleaned'");

      String? soundToPlay;
      String? ttsTextToSpeak;
      bool performPageChange = false;

      switch (cleaned) {
        case "0":
          performPageChange = true;
          _tabController.animateTo(0);
          break;
        case "1":
          performPageChange = true;
          _tabController.animateTo(1);
          break;
        case "2":
          performPageChange = true;
          _tabController.animateTo(2);
          break;
        case "تم التنفيذ":
          if (_selectedIndex == 1) {
            setState(() {
              _selectedIndex = 1;
              _openCamera = true;
            });
            soundToPlay = 'assets/sounds/CameraOpened.mp3';
          } else {
            soundToPlay = 'assets/sounds/YouAreNotOnTheHomePage.mp3';
          }
          break;
        case "اعد الكلام":
          soundToPlay = 'assets/sounds/SpeakAgain.mp3';
          break;
        default:
          ttsTextToSpeak = "لم أفهم، من فضلك أعد الكلام.";
          break;
      }

      if (performPageChange) {
        await Future.delayed(_tabController.animationDuration + const Duration(milliseconds: 50));

        setState(() {
          _selectedIndex = _tabController.index;
          _openCamera = false;
        });
      }

      if (soundToPlay != null) {
        await _playAssetSoundWithControl(soundToPlay);
      } else if (ttsTextToSpeak != null) {
        await _speakWithControl(ttsTextToSpeak);
      }

    } catch (e) {
      print("Error processing command with assistant: $e");
      await _playAssetSoundWithControl('assets/sounds/SomethingWentWrong.mp3');
      return;
    }
  }

  void _onTabChanged() async {
    print("DEBUG: _onTabChanged called. indexIsChanging: ${_tabController.indexIsChanging}, selectedIndex: $_selectedIndex");
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedIndex = _tabController.index;
        _openCamera = false;
      });

      print("MainScreen: _selectedIndex changed to $_selectedIndex");
      print("MainScreen: _isHomeFirstVisit is $_isHomeFirstVisit");

      if (_selectedIndex == 1) { // Home page
        if (_isHomeFirstVisit) {
          _isHomeFirstVisit = false;
          print("MainScreen: First visit to Home, setting _isHomeFirstVisit to false.");
        } else {
          print("MainScreen: Not first visit to Home, attempting to play announce sound.");
          if (!_openCamera && !_isSpeaking) {
            await _playHomePageAnnounce();
          } else {
            print("MainScreen: Skipping announce sound due to _openCamera or _isSpeaking being true.");
          }
        }
      } else { // Other pages
        _isHomeFirstVisit = false;
        print("MainScreen: Moved to non-Home page, setting _isHomeFirstVisit to false.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (!_isListening && !_isSpeaking && !_openCamera) {
          await _startListening();
        } else if (_isListening) {
          await _sttService.stopListening();
          setState(() {
            _isListening = false;
          });
          _processCommand(_sttService.lastWords);
        }
      },
      child: Scaffold(
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
          activeColor: const Color.fromARGB(255, 15, 58, 107),
          style: TabStyle.reactCircle,
        ),
      ),
    );
  }
}