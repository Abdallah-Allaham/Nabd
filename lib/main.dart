import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nabd/screens/splash_screen.dart';
import 'package:nabd/utils/shared_preferences_helper.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesHelper().init();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

