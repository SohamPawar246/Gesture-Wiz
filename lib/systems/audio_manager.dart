import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'error_notification_service.dart';

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
  static bool _audioAvailable = true; // Track if audio system is working

  /// Whether audio is available (false if initialization failed)
  static bool get isAudioAvailable => _audioAvailable;

  static void setBgmMuted(bool muted) {
    _bgmMuted = muted;
    if (!_audioAvailable) return;

    if (muted || _allMuted) {
      try {
        FlameAudio.bgm.pause();
      } catch (e) {
        _handleAudioError('pause BGM', e);
      }
    } else if (_wantsUiMusic) {
      try {
        FlameAudio.bgm.resume();
      } catch (e) {
        _handleAudioError('resume BGM', e);
      }
    }
  }

  static void setAllMuted(bool muted) {
    _allMuted = muted;
    if (!_audioAvailable) return;

    if (muted) {
      try {
        FlameAudio.bgm.pause();
      } catch (e) {
        _handleAudioError('pause audio', e);
      }
    } else if (!_bgmMuted && _wantsUiMusic) {
      try {
        FlameAudio.bgm.resume();
      } catch (e) {
        _handleAudioError('resume audio', e);
      }
    }
  }

  /// Preload all procedural 8-bit WAV files
  static Future<void> init() async {
    if (_initialized) return;
    _initFuture ??= _initInternal();
    await _initFuture;
  }

  static Future<void> _initInternal() async {
    try {
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
      _audioAvailable = true;
    } catch (e) {
      _initialized = true; // Mark as initialized to prevent retry loops
      _audioAvailable = false;

      // Notify user that audio is unavailable
      ErrorNotificationService.instance.audioInitFailed(
        onRetry: () => _retryInit(),
      );

      if (kDebugMode) {
        debugPrint('Audio initialization failed: $e');
      }
    }
  }

  /// Retry audio initialization
  static Future<void> _retryInit() async {
    _initialized = false;
    _initFuture = null;
    await init();

    if (_audioAvailable) {
      ErrorNotificationService.instance.info(
        'Audio Restored',
        'Sound effects are now available.',
      );
    }
  }

  /// Play a sound effect with optional volume scaling
  static void playSfx(String file, {double volume = 0.5}) {
    if (_allMuted || !_audioAvailable) return;

    try {
      FlameAudio.play(file, volume: volume);
    } catch (e) {
      _handleAudioError('play sound effect', e);
    }
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

    if (!_audioAvailable) return;

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
    } catch (e) {
      _isUiMusicPlaying = false;
      _currentUiTrack = null;
      _handleAudioError('play music', e);
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
    } catch (e) {
      _handleAudioError('stop music', e);
    }
    _isUiMusicPlaying = false;
    _currentUiTrack = null;
  }

  /// Handle audio errors - log and optionally notify user
  static void _handleAudioError(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('Audio error during $operation: $error');
    }

    // Only notify once when audio becomes unavailable
    if (_audioAvailable) {
      _audioAvailable = false;
      ErrorNotificationService.instance.warning(
        'Audio Issue',
        'Sound may be unavailable. The game will continue.',
      );
    }
  }
}
