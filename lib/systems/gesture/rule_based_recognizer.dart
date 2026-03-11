import 'dart:math';

import '../hand_tracking/landmark_model.dart';
import 'gesture_recognizer.dart';
import 'gesture_type.dart';

/// Gesture recognition with hysteresis thresholds and confidence scoring.
///
/// Key design principles:
///   - Hysteresis eliminates oscillation: enter thresholds are strict,
///     sustain thresholds are relaxed — once a gesture starts, it's sticky.
///   - Confidence scoring lets downstream systems (state machine, visuals)
///     know how definitively the hand matches the gesture shape.
///   - Priority: openPalm > pinch > fist > point > vSign > none
class RuleBasedRecognizer implements GestureRecognizer {
  // --- Hysteresis thresholds ---
  // Enter thresholds (strict: must cross these to START a gesture)
  static const double _openEnter = 0.16;
  static const double _curlEnter = 0.06;
  // Sustain thresholds (relaxed: once in a gesture, easier to STAY)
  static const double _openSustain = 0.10;
  static const double _curlSustain = 0.12;

  // Track which fingers were classified as open/curled last frame
  final List<bool> _prevOpen = [false, false, false, false];   // index, middle, ring, pinky
  final List<bool> _prevCurled = [false, false, false, false];

  @override
  GestureResult recognize(List<Landmark> landmarks) {
    if (landmarks.length != 21) return GestureResult.none;

    final wrist = landmarks[0];

    // Fingertips
    final thumbTip  = landmarks[4];
    final indexTip  = landmarks[8];
    final middleTip = landmarks[12];
    final ringTip   = landmarks[16];
    final pinkyTip  = landmarks[20];

    // MCP joints (knuckle bases)
    final indexMcp  = landmarks[5];
    final middleMcp = landmarks[9];
    final ringMcp   = landmarks[13];
    final pinkyMcp  = landmarks[17];

    // PIP joints (middle knuckles)
    final indexPip  = landmarks[6];
    final middlePip = landmarks[10];
    final ringPip   = landmarks[14];
    final pinkyPip  = landmarks[18];

    // DIP joints (upper knuckles)
    final indexDip  = landmarks[7];
    final middleDip = landmarks[11];
    final ringDip   = landmarks[15];
    final pinkyDip  = landmarks[19];

    // --- Palm size for relative scaling ---
    final double palmSize = _distance(wrist, middleMcp);
    if (palmSize < 0.01) return GestureResult.none;

    // ====================================================================
    // FINGER EXTENSION RATIOS
    // ====================================================================
    final ratios = [
      (_distance(indexTip, wrist)  - _distance(indexPip,  wrist)) / palmSize,
      (_distance(middleTip, wrist) - _distance(middlePip, wrist)) / palmSize,
      (_distance(ringTip, wrist)   - _distance(ringPip,   wrist)) / palmSize,
      (_distance(pinkyTip, wrist)  - _distance(pinkyPip,  wrist)) / palmSize,
    ];

    // Straightness check (1.05x tolerance for camera angle variation)
    final straight = [
      _distance(indexTip,  indexMcp)  > _distance(indexDip,  indexMcp)  * 1.05,
      _distance(middleTip, middleMcp) > _distance(middleDip, middleMcp) * 1.05,
      _distance(ringTip,   ringMcp)   > _distance(ringDip,   ringMcp)   * 1.05,
      _distance(pinkyTip,  pinkyMcp)  > _distance(pinkyDip,  pinkyMcp)  * 1.05,
    ];

    // ====================================================================
    // HYSTERESIS-BASED CLASSIFICATION
    // ====================================================================
    final isOpen = List<bool>.filled(4, false);
    final isCurled = List<bool>.filled(4, false);

    for (int i = 0; i < 4; i++) {
      // Use sustain (relaxed) threshold if finger was already in that state
      final openThresh = _prevOpen[i] ? _openSustain : _openEnter;
      final curlThresh = _prevCurled[i] ? _curlSustain : _curlEnter;

      isOpen[i] = ratios[i] > openThresh && straight[i];
      isCurled[i] = ratios[i] < curlThresh || !straight[i];
    }

    // Update previous state for next frame
    for (int i = 0; i < 4; i++) {
      _prevOpen[i] = isOpen[i];
      _prevCurled[i] = isCurled[i];
    }

    final int openCount = isOpen.where((f) => f).length;
    final int curledCount = isCurled.where((f) => f).length;

    // ====================================================================
    // GESTURE CLASSIFICATION — strict priority ordering
    // ====================================================================

    // --- OPEN PALM (highest priority — it's the default/resting state) ---
    if (openCount >= 4) {
      final confidence = _openPalmConfidence(ratios, straight);
      return _commit(GestureType.openPalm, confidence);
    }

    // --- PINCH: Thumb + Index very close, BUT other fingers NOT all curled ---
    final double thumbIndexDist  = _distance(thumbTip, indexTip);
    final double thumbMiddleDist = _distance(thumbTip, middleTip);

    if (thumbIndexDist < palmSize * 0.18 || thumbMiddleDist < palmSize * 0.22) {
      final int othersCurled = [isCurled[1], isCurled[2], isCurled[3]].where((f) => f).length;
      if (othersCurled <= 1) {
        // Confidence based on how close the pinch is, scaled by palm
        final pinchDist = min(thumbIndexDist, thumbMiddleDist);
        final pinchConf = (1.0 - (pinchDist / (palmSize * 0.22))).clamp(0.0, 1.0);
        return _commit(GestureType.pinch, pinchConf);
      }
    }

    // --- FIST: ALL 4 fingers curled ---
    if (curledCount >= 4) {
      final double avgTipDist = (
        _distance(indexTip,  wrist) +
        _distance(middleTip, wrist) +
        _distance(ringTip,   wrist) +
        _distance(pinkyTip,  wrist)
      ) / 4.0;

      if (avgTipDist < palmSize * 1.1) {
        final fistConf = _curlConfidence(ratios);
        return _commit(GestureType.fist, fistConf);
      }

      // Fallback: all ratios negative = strong fist
      if (ratios[0] < 0 && ratios[1] < 0 && ratios[2] < 0 && ratios[3] < 0) {
        return _commit(GestureType.fist, 1.0);
      }
    }

    // --- POINT: ONLY index extended ---
    if (isOpen[0] && isCurled[1] && isCurled[2] && isCurled[3]) {
      if (_distance(indexTip, wrist) > palmSize * 1.2) {
        final pointConf = _pointConfidence(ratios);
        return _commit(GestureType.point, pointConf);
      }
    }

    // --- V-SIGN: Index + Middle extended, Ring + Pinky curled ---
    if (isOpen[0] && isOpen[1] && isCurled[2] && isCurled[3]) {
      final double spread = _distance(indexTip, middleTip);
      if (spread > palmSize * 0.18) {
        final vConf = _vSignConfidence(ratios, spread, palmSize);
        return _commit(GestureType.vSign, vConf);
      }
    }

    // Ambiguous — return none (don't guess)
    return _commit(GestureType.none, 0.0);
  }

  GestureResult _commit(GestureType type, double confidence) {
    return GestureResult(type, confidence.clamp(0.0, 1.0));
  }

  // ── Confidence helpers ─────────────────────────────────────────────────

  double _openPalmConfidence(List<double> ratios, List<bool> straight) {
    // Min of how far each finger is past the open threshold
    double minConf = 1.0;
    for (int i = 0; i < 4; i++) {
      if (!straight[i]) return 0.3; // Barely qualifies
      final conf = ((ratios[i] - _openSustain) / 0.15).clamp(0.0, 1.0);
      minConf = min(minConf, conf);
    }
    return minConf;
  }

  double _curlConfidence(List<double> ratios) {
    double minConf = 1.0;
    for (int i = 0; i < 4; i++) {
      final conf = ((_curlSustain - ratios[i]) / 0.08).clamp(0.0, 1.0);
      minConf = min(minConf, conf);
    }
    return minConf;
  }

  double _pointConfidence(List<double> ratios) {
    // Index should be well-extended, others well-curled
    final indexConf = ((ratios[0] - _openSustain) / 0.15).clamp(0.0, 1.0);
    final midConf = ((_curlSustain - ratios[1]) / 0.08).clamp(0.0, 1.0);
    final ringConf = ((_curlSustain - ratios[2]) / 0.08).clamp(0.0, 1.0);
    final pinkyConf = ((_curlSustain - ratios[3]) / 0.08).clamp(0.0, 1.0);
    return [indexConf, midConf, ringConf, pinkyConf].reduce(min);
  }

  double _vSignConfidence(List<double> ratios, double spread, double palmSize) {
    final indexConf = ((ratios[0] - _openSustain) / 0.15).clamp(0.0, 1.0);
    final midConf = ((ratios[1] - _openSustain) / 0.15).clamp(0.0, 1.0);
    final ringConf = ((_curlSustain - ratios[2]) / 0.08).clamp(0.0, 1.0);
    final pinkyConf = ((_curlSustain - ratios[3]) / 0.08).clamp(0.0, 1.0);
    final spreadConf = ((spread / palmSize - 0.18) / 0.15).clamp(0.0, 1.0);
    return [indexConf, midConf, ringConf, pinkyConf, spreadConf].reduce(min);
  }

  double _distance(Landmark p1, Landmark p2) {
    return sqrt(
      pow(p1.x - p2.x, 2) +
      pow(p1.y - p2.y, 2) +
      pow(p1.z - p2.z, 2),
    );
  }
}
