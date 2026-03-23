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
  static const String _creditsTrack = 'brunomagic-outro-credits-ending-melody-381836.mp3';

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
        _logAudioError('pause BGM', e);
      }
    } else if (_wantsUiMusic) {
      try {
        FlameAudio.bgm.resume();
      } catch (e) {
        _logAudioError('resume BGM', e);
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
        _logAudioError('pause audio', e);
      }
    } else if (!_bgmMuted && _wantsUiMusic) {
      try {
        FlameAudio.bgm.resume();
      } catch (e) {
        _logAudioError('resume audio', e);
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
        'menu_hover.wav',
        'menu_select.wav',
        'error.wav',
        'My_Song.wav',
        'New_Project.wav',
        'brunomagic-outro-credits-ending-melody-381836.mp3',
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
      // SFX errors are non-critical — just log, don't disable audio
      _logAudioError('play SFX "$file"', e);
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

  static Future<void> playCreditsMusic({
    double volume = 1.0,
    bool forceRestart = false,
  }) {
    return _playUiMusic(_creditsTrack, volume: volume, forceRestart: forceRestart);
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
      // Already playing the right track — just ensure it's not paused
      try {
        if (!_bgmMuted && !_allMuted) {
          FlameAudio.bgm.resume();
        }
      } catch (_) {
        // Underlying player may have been disposed (e.g. after leaving game
        // level scene). Reset state and fall through to restart the track.
        _isUiMusicPlaying = false;
        _currentUiTrack = null;
      }
      if (_isUiMusicPlaying) return;
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
      _logAudioError('play music "$track"', e);
      // Music errors are non-critical — leave _audioAvailable as-is so SFX
      // and future music attempts still work.
    }
  }

  static Future<void> stopUiMusic() async {
    _wantsUiMusic = false;
    ++_uiMusicRequestId;
    await _stopUiMusicPlayback();
  }

  static Future<void> _stopUiMusicPlayback() async {
    // Always clear our state flags, even if the stop call throws.
    // This prevents stale "isPlaying" state from blocking the next BGM start.
    _isUiMusicPlaying = false;
    _currentUiTrack = null;

    try {
      await FlameAudio.bgm.stop();
    } catch (e) {
      // The BGM player may have already been disposed (e.g. when the
      // GameWidget is removed from the tree). This is expected and safe.
      _logAudioError('stop music', e);
    }
  }

  /// Log an audio error without disabling audio globally.
  /// Only initialization failures permanently disable audio.
  static void _logAudioError(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('Audio error during $operation: $error');
    }
  }
}
