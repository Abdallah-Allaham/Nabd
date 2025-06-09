import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nabd/utils/const_value.dart';
import 'package:nabd/services/tts_service.dart';
import 'package:nabd/services/stt_service.dart';
import 'package:nabd/utils/audio_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String phone = '';
  String name = '';
  String guardianPhone = '';
  String voiceIdStatus = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadProfileData();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _sttService.stopListening();
    await _ttsService.stop();
    final player = await AudioHelper.playAssetSound('assets/sounds/IMovedToTheProfile.mp3');
    await player.onPlayerComplete.first;
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _loadProfileData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.phoneNumber).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        phone = data['phone'] ?? '';
        name = data['name'] ?? '';
        guardianPhone = data['guardian_phone'] ?? '';
        voiceIdStatus = data['voice_id_status'] ?? 'غير معروف';
      });
    }
  }

  Widget _buildInfoCard(String title, String value) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    height: 100,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white24),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value.isNotEmpty ? value : 'لا يوجد معلومات مدخلة',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ConstValue.color1, ConstValue.color2],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                "Your Profile",
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildInfoCard("Phone Number", phone),
            _buildInfoCard("Name", name),
            _buildInfoCard("Guardian's Phone", guardianPhone),
            _buildInfoCard("Voice ID Status", voiceIdStatus),
          ],
        ),
      ),
    );
  }
}
