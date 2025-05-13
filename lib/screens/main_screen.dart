import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:nabd/screens/profile_screen.dart';
import 'package:nabd/screens/setting_screen.dart';
import 'package:nabd/screens/home_screen.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/services/assistant_service.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({Key? key, this.initialIndex = 1}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  late int _selectedIndex;
  late List<Widget> _pages;
  late TabController _tabController;
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();

  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final AssistantService _assistantService = AssistantService();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pages = [
      const ProfileScreen(),
      HomeScreen(key: _homeScreenKey), // استخدام GlobalKey هنا
      const SettingScreen(),
    ];
    _tabController = TabController(
      length: 3,
      initialIndex: _selectedIndex,
      vsync: this,
    );
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sttService.stopListening();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    bool speechInitialized = await _sttService.initSpeech();
    if (!speechInitialized) {
      await _ttsService.speak("يرجى تفعيل إذن المايك لاستخدام التطبيق");
      return;
    }
    await _ttsService.speak("جاهز للمساعدة");
    await Future.delayed(const Duration(milliseconds: 100));
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_isListening && mounted) {
      setState(() {
        _isListening = true;
      });
      await _sttService.startListening();
      _checkForCommand();
    }
  }

  void _checkForCommand() async {
    while (_isListening && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_sttService.lastWords.isNotEmpty) {
        String command = _sttService.lastWords;
        print("\u{1F4AC} سيتم إرسال الأمر إلى المساعد: $command");

        _sttService.clearLastWords();
        await _sttService.stopListening();
        if (mounted) setState(() => _isListening = false);

        try {
          String response = await _assistantService.sendMessageToAssistant(command);
          print("\u{1F916} الرد من المساعد: $response");

          String cleaned = response.replaceAll(RegExp(r'[^\w\sء-ي]'), '').trim();

          if (cleaned == "أعد الكلام") {
            await _ttsService.speak("أعد الكلام");
            await Future.delayed(const Duration(milliseconds: 100));
            await _startListening();
          } else if (cleaned.contains("تم التنفيذ")) {
            await _ttsService.speak("تم التنفيذ");
            if (_selectedIndex != 1) {
              setState(() {
                _selectedIndex = 1;
                _tabController.index = _selectedIndex;
              });
              await Future.delayed(const Duration(milliseconds: 100));
            }
            await _openCameraInCurrentScreen();
          } else if (cleaned == "جاري فتح الإعدادات") {
            await _ttsService.speak("جاري فتح الإعدادات");
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              setState(() {
                _selectedIndex = 2;
                _tabController.index = _selectedIndex;
              });
              await _startListening();
            }
          } else if (cleaned == "جاري فتح الملف الشخصي") {
            await _ttsService.speak("جاري فتح الملف الشخصي");
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              setState(() {
                _selectedIndex = 0;
                _tabController.index = _selectedIndex;
              });
              await _startListening();
            }
          } else if (cleaned == "جاري تغيير بصمة الصوت") {
            if (_selectedIndex == 2) {
              await _ttsService.speak("جاري تغيير بصمة الصوت");
              _pages[2] = const SettingScreen(changeVoice: true);
              setState(() {});
              await _startListening();
            } else {
              await _ttsService.speak("هذا الأمر متاح فقط في صفحة الإعدادات");
              await Future.delayed(const Duration(milliseconds: 100));
              await _startListening();
            }
          } else {
            await _ttsService.speak(response);
            await Future.delayed(const Duration(milliseconds: 100));
            await _startListening();
          }
        } catch (e) {
          print("\u{1F6A8} خطأ أثناء التواصل مع المساعد: $e");
          await _ttsService.speak("حدث خطأ، حاول مرة أخرى");
          await Future.delayed(const Duration(milliseconds: 100));
          await _startListening();
        }
      }
    }
  }

  Future<void> _openCameraInCurrentScreen() async {
    if (_homeScreenKey.currentState != null && mounted) {
      await _homeScreenKey.currentState!.openCamera();
      print("تم استدعاء فتح الكاميرا");
    } else {
      print("\u{1F6A8} حالة HomeScreen غير متاحة أو الـ mounted غير صحيح");
    }
  }

  void setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
      _tabController.index = _selectedIndex;
    });
    _startListening();
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
        onTap: (int index) {
          setSelectedIndex(index);
        },
        style: TabStyle.reactCircle,
      ),
    );
  }
}