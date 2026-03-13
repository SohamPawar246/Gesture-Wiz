import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager extends ChangeNotifier {
  double handSensitivity = 0.65;
  double faceSensitivity = 0.0;
  bool bgmMuted = false;
  bool allMuted = false;
  double pixelationLevel = 1.0;

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

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    handSensitivity = prefs.getDouble(_kHand) ?? 0.65;
    faceSensitivity = prefs.getDouble(_kFace) ?? 0.0;
    bgmMuted = prefs.getBool(_kBgm) ?? false;
    allMuted = prefs.getBool(_kAll) ?? false;
    pixelationLevel = prefs.getDouble(_kPixel) ?? 1.0;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kHand, handSensitivity);
    await prefs.setDouble(_kFace, faceSensitivity);
    await prefs.setBool(_kBgm, bgmMuted);
    await prefs.setBool(_kAll, allMuted);
    await prefs.setDouble(_kPixel, pixelationLevel);
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
}
