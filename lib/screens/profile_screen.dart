import 'package:flutter/material.dart';
import 'package:nabd/utils/const_value.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ConstValue.color1, ConstValue.color2],
          ),
        ),
      ),
    );
  }
}
