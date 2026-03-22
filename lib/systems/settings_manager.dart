import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/difficulty.dart';
import 'performance_monitor.dart';

class SettingsManager extends ChangeNotifier {
  double handSensitivity = 0.65;
  double faceSensitivity = 0.0;
  bool bgmMuted = false;
  bool allMuted = false;
  double pixelationLevel = 1.0;
  Difficulty difficulty = Difficulty.normal;
  bool useMouseMode = false; // Force mouse-only controls

  // Performance settings (Phase 2)
  bool showFps = false;
  FpsDisplayMode fpsDisplayMode = FpsDisplayMode.full;
  QualityLevel qualityLevel = QualityLevel.high;
  bool autoQuality = true; // Automatically adjust quality based on FPS

  // Derived face values
  static const double _baseFaceAlpha = 0.55;
  static const double _maxFaceAlpha = 0.92;
  static const double _baseParallaxH = 65.0;
  static const double _baseParallaxV = 35.0;
  static const double _maxParallaxScale = 4.6;

  double get faceSmoothingAlpha =>
      _baseFaceAlpha + faceSensitivity * (_maxFaceAlpha - _baseFaceAlpha);

  double get faceParallaxScale =>
      1.0 + faceSensitivity * (_maxParallaxScale - 1.0);

  double get parallaxH => _baseParallaxH * faceParallaxScale;
  double get parallaxV => _baseParallaxV * faceParallaxScale;

  // Persistence keys
  static const _kHand = 'settings_hand_sensitivity';
  static const _kFace = 'settings_face_sensitivity';
  static const _kBgm = 'settings_bgm_muted';
  static const _kAll = 'settings_all_muted';
  static const _kPixel = 'settings_pixelation_level';
  static const _kDifficulty = 'settings_difficulty';
  static const _kMouseMode = 'settings_mouse_mode';
  static const _kShowFps = 'settings_show_fps';
  static const _kFpsMode = 'settings_fps_display_mode';
  static const _kQuality = 'settings_quality_level';
  static const _kAutoQuality = 'settings_auto_quality';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    handSensitivity = prefs.getDouble(_kHand) ?? 0.65;
    faceSensitivity = prefs.getDouble(_kFace) ?? 0.0;
    bgmMuted = prefs.getBool(_kBgm) ?? false;
    allMuted = prefs.getBool(_kAll) ?? false;
    pixelationLevel = prefs.getDouble(_kPixel) ?? 1.0;
    difficulty = Difficulty.fromString(prefs.getString(_kDifficulty));
    useMouseMode = prefs.getBool(_kMouseMode) ?? false;
    showFps = prefs.getBool(_kShowFps) ?? false;
    fpsDisplayMode = FpsDisplayMode.fromString(prefs.getString(_kFpsMode));
    qualityLevel = QualityLevel.fromString(prefs.getString(_kQuality));
    autoQuality = prefs.getBool(_kAutoQuality) ?? true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kHand, handSensitivity);
    await prefs.setDouble(_kFace, faceSensitivity);
    await prefs.setBool(_kBgm, bgmMuted);
    await prefs.setBool(_kAll, allMuted);
    await prefs.setDouble(_kPixel, pixelationLevel);
    await prefs.setString(_kDifficulty, difficulty.name);
    await prefs.setBool(_kMouseMode, useMouseMode);
    await prefs.setBool(_kShowFps, showFps);
    await prefs.setString(_kFpsMode, fpsDisplayMode.name);
    await prefs.setString(_kQuality, qualityLevel.name);
    await prefs.setBool(_kAutoQuality, autoQuality);
  }

  void setHandSensitivity(double v) {
    handSensitivity = v.clamp(0.30, 0.95);
    _persist();
    notifyListeners();
  }

  void setFaceSensitivity(double v) {
    faceSensitivity = v.clamp(0.0, 1.0);
    _persist();
    notifyListeners();
  }

  void setBgmMuted(bool v) {
    bgmMuted = v;
    _persist();
    notifyListeners();
  }

  void setAllMuted(bool v) {
    allMuted = v;
    if (v) bgmMuted = true;
    _persist();
    notifyListeners();
  }

  void setPixelationLevel(double v) {
    pixelationLevel = v.clamp(1.0, 4.0);
    _persist();
    notifyListeners();
  }

  void setDifficulty(Difficulty d) {
    difficulty = d;
    _persist();
    notifyListeners();
  }

  void setUseMouseMode(bool v) {
    useMouseMode = v;
    _persist();
    notifyListeners();
  }

  void setShowFps(bool v) {
    showFps = v;
    _persist();
    notifyListeners();
  }

  void setFpsDisplayMode(FpsDisplayMode mode) {
    fpsDisplayMode = mode;
    _persist();
    notifyListeners();
  }

  void setQualityLevel(QualityLevel level) {
    qualityLevel = level;
    _persist();
    notifyListeners();
  }

  void setAutoQuality(bool v) {
    autoQuality = v;
    _persist();
    notifyListeners();
  }
}

/// FPS display mode
enum FpsDisplayMode {
  full,     // Show FPS, frame time, range, entities
  compact;  // Show just FPS number

  static FpsDisplayMode fromString(String? str) {
    return FpsDisplayMode.values.firstWhere(
      (mode) => mode.name == str,
      orElse: () => FpsDisplayMode.full,
    );
  }
}
