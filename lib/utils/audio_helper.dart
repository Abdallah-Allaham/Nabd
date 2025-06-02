import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;

class AudioHelper {
  /// Plays an asset (e.g. 'assets/sounds/Fingerprint.mp3') 
  /// and returns the AudioPlayer so you can listen for completion.
  static Future<AudioPlayer> playAssetSound(String assetPath) async {
    // 1. Load bytes from your bundled asset
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    // 2. Write to a temporary file
    final dir = await getTemporaryDirectory();
    final filename = p.basename(assetPath);
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    // 3. Create a fresh player, configure it, and play
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(1.0);
    await player.play(DeviceFileSource(file.path));

    return player;
  }
}
