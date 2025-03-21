import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:wave/wave.dart';
import 'package:wave/config.dart';

class Avatar extends StatelessWidget {
  final double size;

  const Avatar({super.key, required this.size});

  Widget _buildWaveCircle() {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: WaveWidget(
          config: CustomConfig(
            gradients: [
              [Colors.blueAccent, Colors.blue.shade100],
              [Colors.purpleAccent, Colors.purple.shade100],
            ],
            durations: [3500, 5000],
            heightPercentages: [0.4, 0.45],
            blur: const MaskFilter.blur(BlurStyle.solid, 10),
            gradientBegin: Alignment.topLeft,
            gradientEnd: Alignment.bottomRight,
          ),
          size: const Size(double.infinity, double.infinity),
          waveAmplitude: 15,
          backgroundColor: Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      duration: const Duration(seconds: 2),
      child: _buildWaveCircle(),
    );
  }
}