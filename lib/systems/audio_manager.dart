import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  /// Preload all procedural 8-bit WAV files
  static Future<void> init() async {
    await FlameAudio.audioCache.loadAll([
      'fireball.wav',
      'pop.wav',
      'hit.wav',
      'shield.wav',
      'heal.wav',
      'explode.wav',
      'wave.wav',
    ]);
  }

  /// Play a sound effect with optional volume scaling
  static void playSfx(String file, {double volume = 0.5}) {
    FlameAudio.play(file, volume: volume);
  }
}
