import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:video_player/video_player.dart';

class Avatar extends StatefulWidget {
  final double size;

  const Avatar({super.key, required this.size});

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/videos/avatar_video.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      duration: const Duration(seconds: 2),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: _videoController.value.isInitialized
              ? VideoPlayer(_videoController)
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
