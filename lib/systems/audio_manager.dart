import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  static bool _initialized = false;
  static Future<void>? _initFuture;
  static bool _isUiMusicPlaying = false;
  static bool _wantsUiMusic = false;
  static int _uiMusicRequestId = 0;
  static String? _currentUiTrack;
  static const String _menuTutorialTrack = 'My_Song.wav';
  static const String _mapTrack = 'New_Project.wav';

  static bool _bgmMuted = false;
  static bool _allMuted = false;

  static void setBgmMuted(bool muted) {
    _bgmMuted = muted;
    if (muted || _allMuted) {
      try {
        FlameAudio.bgm.pause();
      } catch (_) {}
    } else if (_wantsUiMusic) {
      try {
        FlameAudio.bgm.resume();
      } catch (_) {}
    }
  }

  static void setAllMuted(bool muted) {
    _allMuted = muted;
    if (muted) {
      try {
        FlameAudio.bgm.pause();
      } catch (_) {}
    } else if (!_bgmMuted && _wantsUiMusic) {
      try {
        FlameAudio.bgm.resume();
      } catch (_) {}
    }
  }

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
      'New_Project.wav',
    ]);
    await FlameAudio.bgm.initialize();
    _initialized = true;
  }

  /// Play a sound effect with optional volume scaling
  static void playSfx(String file, {double volume = 0.5}) {
    if (_allMuted) return;
    FlameAudio.play(file, volume: volume);
  }

  static Future<void> playMenuTutorialMusic({
    double volume = 0.75,
    bool forceRestart = false,
  }) {
    return _playUiMusic(
      _menuTutorialTrack,
      volume: volume,
      forceRestart: forceRestart,
    );
  }

  static Future<void> playMapMusic({
    double volume = 0.75,
    bool forceRestart = false,
  }) {
    return _playUiMusic(_mapTrack, volume: volume, forceRestart: forceRestart);
  }

  static Future<void> _playUiMusic(
    String track, {
    required double volume,
    required bool forceRestart,
  }) async {
    _wantsUiMusic = true;
    final requestId = ++_uiMusicRequestId;

    await init();
    if (!_wantsUiMusic || requestId != _uiMusicRequestId) {
      return;
    }

    final isSameTrackPlaying = _isUiMusicPlaying && _currentUiTrack == track;

    if (forceRestart || (_isUiMusicPlaying && _currentUiTrack != track)) {
      await _stopUiMusicPlayback();
    } else if (isSameTrackPlaying) {
      return;
    }

    if (_bgmMuted || _allMuted) {
      _currentUiTrack = track;
      return;
    }

    try {
      await FlameAudio.bgm.play(track, volume: volume);
      _isUiMusicPlaying = true;
      _currentUiTrack = track;
    } catch (_) {
      _isUiMusicPlaying = false;
      _currentUiTrack = null;
    }
  }

  static Future<void> stopUiMusic() async {
    _wantsUiMusic = false;
    ++_uiMusicRequestId;
    await _stopUiMusicPlayback();
  }

  static Future<void> _stopUiMusicPlayback() async {
    if (!_isUiMusicPlaying) return;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
    _isUiMusicPlaying = false;
    _currentUiTrack = null;
  }
}
