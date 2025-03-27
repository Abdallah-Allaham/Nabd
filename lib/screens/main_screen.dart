import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'home_page.dart'; // تأكد من أن المسار صحيح

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;
  final List<Widget> _pages = [
    const Placeholder(), // Profile Page
    const Home_Page(),   // Home Page
    const Placeholder(), // Settings Page
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: ConvexAppBar(
        items: const [
          TabItem(icon: Icons.person_outline, title: 'Profile'),
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.settings, title: 'Settings'),
        ],
        initialActiveIndex: _selectedIndex,
        backgroundColor: Colors.white, // لون الخلفية أبيض
        color: const Color.fromARGB(255, 123, 123, 123), // لون الأيقونات غير المحددة
        activeColor: Color.fromARGB(255, 15, 58, 107), // أزرق غامق (كحلي) للأيقونة المحددة
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        style: TabStyle.reactCircle, // لإضافة تأثير عند الضغط
      ),
    );
  }
}