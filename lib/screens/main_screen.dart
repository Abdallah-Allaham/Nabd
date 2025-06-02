import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:nabd/screens/profile_screen.dart';
import 'package:nabd/screens/setting_screen.dart';
import 'package:nabd/screens/home_screen.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/services/assistant_service.dart';
import 'package:nabd/utils/audio_helper.dart';

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

    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _ttsService.stop();
    _sttService.stopListening();
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
        _initializeServices();
      }
    }
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.initSpeech();
    await _speakWithControl("جاهز للمساعدة");
  }

  Future<void> _speakWithControl(String text) async {
    if (_isSpeaking) await _ttsService.stop();
    _isSpeaking = true;
    _lastSpokenText = text;

    await _sttService.stopListening();
    _isListening = false;

    await _ttsService.speak(text);
    _isSpeaking = false;

    if (!_openCamera) _startListening();
  }

  Future<void> _startListening() async {
    if (_isListening || _isSpeaking) return;
    _isListening = true;
    try {
      await _sttService.startListening();
      _checkForCommand();
    } catch (_) {
      _isListening = false;
      final player = await AudioHelper.playAssetSound('assets/sounds/SomethingWentWrong.mp3');
      await player.onPlayerComplete.first;
      await Future.delayed(Duration(seconds: 2));
      await _startListening();
    }
  }

  void _checkForCommand() {
    Future.delayed(const Duration(seconds: 6), () async {
      if (!mounted) return;
      final cmd = _sttService.lastWords;
      if (cmd.isEmpty) {
        await _sttService.stopListening();
        _isListening = false;
        return _startListening();
      }
      if (_lastSpokenText != null && cmd.contains(_lastSpokenText!)) {
        _sttService.clearLastWords();
        await _sttService.stopListening();
        _isListening = false;
        return _startListening();
      }
      if (_lastCommand == cmd) {
        _sttService.clearLastWords();
        await _sttService.stopListening();
        _isListening = false;
        return _startListening();
      }
      _lastCommand = cmd;

      _sttService.clearLastWords();
      await _sttService.stopListening();
      _isListening = false;

      try {
        final resp = await _assistantService.sendMessageToAssistant(cmd);
        final cleaned = resp.replaceAll(RegExp(r'[^\w\sء-ي]'), '').trim();

        switch (cleaned) {
          case "0":
            _tabController.animateTo(0);
            setState(() {
              _selectedIndex = 0;
              _openCamera = false;
            });
            await Future.delayed(const Duration(milliseconds: 300));
            return _startListening();
          case "1":
            _tabController.animateTo(1);
            setState(() {
              _selectedIndex = 1;
              _openCamera = false;
            });
            await Future.delayed(const Duration(milliseconds: 300));
            return _startListening();
          case "2":
            _tabController.animateTo(2);
            setState(() {
              _selectedIndex = 2;
              _openCamera = false;
            });
            await Future.delayed(const Duration(milliseconds: 300));
            return _startListening();
          default:
            if (cleaned.contains("تم التنفيذ")) {
              if (_selectedIndex == 1) {
                setState(() {
                  _selectedIndex = 1;
                  _openCamera = true;
                });
              } else {
                final player = await AudioHelper.playAssetSound('assets/sounds/YouAreNotOnTheHomePage.mp3');
                await player.onPlayerComplete.first;
              }
              await Future.delayed(Duration(seconds: 2));
              return _startListening();
            } else if (cleaned.contains("اعد الكلام")) {
              final player = await AudioHelper.playAssetSound('assets/sounds/SpeakAgain.mp3');
              await player.onPlayerComplete.first;
              await Future.delayed(Duration(seconds: 2));
              return _startListening();
            }
        }
      } catch (e) {
        final player = await AudioHelper.playAssetSound('assets/sounds/SomethingWentWrong.mp3');
        await player.onPlayerComplete.first;
        await Future.delayed(Duration(seconds: 2));
        return _startListening();
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedIndex = _tabController.index;
        _openCamera = false;
      });
    }
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
        activeColor: const Color.fromARGB(255, 15, 58, 107),
        style: TabStyle.reactCircle,
      ),
    );
  }
}
