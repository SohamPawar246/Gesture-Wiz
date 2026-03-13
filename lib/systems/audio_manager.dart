import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  static bool _initialized = false;
  static Future<void>? _initFuture;
  static bool _isMenuTutorialMusicPlaying = false;
  static bool _wantsMenuTutorialMusic = false;
  static const String _menuTutorialTrack = 'My_Song.wav';

  /// Preload all procedural 8-bit WAV files
  static Future<void> init() async {
    if (_initialized) return;
    _initFuture ??= _initInternal();
    await _initFuture;
  }

  static Future<void> _initInternal() async {
    await FlameAudio.audioCache.loadAll([
      'fireball.wav',
      'pop.wav',
      'hit.wav',
      'shield.wav',
      'heal.wav',
      'explode.wav',
      'wave.wav',
      'My_Song.wav',
    ]);
    await FlameAudio.bgm.initialize();
    _initialized = true;
  }

  /// Play a sound effect with optional volume scaling
  static void playSfx(String file, {double volume = 0.5}) {
    FlameAudio.play(file, volume: volume);
  }

  /// Plays background music only while on main menu and tutorial screens.
  static Future<void> playMenuTutorialMusic({double volume = 0.75}) async {
    _wantsMenuTutorialMusic = true;
    if (_isMenuTutorialMusicPlaying) return;

    await init();
    if (!_wantsMenuTutorialMusic || _isMenuTutorialMusicPlaying) return;

    await FlameAudio.bgm.play(_menuTutorialTrack, volume: volume);
    _isMenuTutorialMusicPlaying = true;
  }

  static Future<void> stopMenuTutorialMusic() async {
    _wantsMenuTutorialMusic = false;
    if (!_isMenuTutorialMusicPlaying) return;
    await FlameAudio.bgm.stop();
    _isMenuTutorialMusicPlaying = false;
  }
}
