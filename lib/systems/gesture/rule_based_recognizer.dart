import 'dart:math';

import '../hand_tracking/landmark_model.dart';
import 'gesture_recognizer.dart';
import 'gesture_type.dart';

/// Tightened gesture recognition with stricter thresholds to prevent
/// accidental/ambiguous detections. Each gesture has multiple validation checks.
class RuleBasedRecognizer implements GestureRecognizer {
  @override
  GestureType recognize(List<Landmark> landmarks) {
    if (landmarks.length != 21) return GestureType.none;

    final wrist = landmarks[0];

    // Fingertips
    final thumbTip = landmarks[4];
    final indexTip = landmarks[8];
    final middleTip = landmarks[12];
    final ringTip = landmarks[16];
    final pinkyTip = landmarks[20];

    // MCP joints (knuckle bases)
    final indexMcp = landmarks[5];
    final middleMcp = landmarks[9];
    final ringMcp = landmarks[13];
    final pinkyMcp = landmarks[17];

    // PIP joints (middle knuckles)
    final indexPip = landmarks[6];
    final middlePip = landmarks[10];
    final ringPip = landmarks[14];
    final pinkyPip = landmarks[18];

    // DIP joints (upper knuckles)
    final indexDip = landmarks[7];
    final middleDip = landmarks[11];
    final ringDip = landmarks[15];
    final pinkyDip = landmarks[19];

    // --- Palm size for relative scaling ---
    final double palmSize = _distance(wrist, middleMcp);
    if (palmSize < 0.01) return GestureType.none;

    // ====================================================================
    // FINGER EXTENSION DETECTION (multi-check for reliability)
    // ====================================================================
    // Method 1: Tip-to-wrist vs PIP-to-wrist ratio
    final double indexRatio = (_distance(indexTip, wrist) - _distance(indexPip, wrist)) / palmSize;
    final double middleRatio = (_distance(middleTip, wrist) - _distance(middlePip, wrist)) / palmSize;
    final double ringRatio = (_distance(ringTip, wrist) - _distance(ringPip, wrist)) / palmSize;
    final double pinkyRatio = (_distance(pinkyTip, wrist) - _distance(pinkyPip, wrist)) / palmSize;

    // Method 2: Tip must be farther from MCP than DIP is (finger is straightened)
    final bool indexStraight = _distance(indexTip, indexMcp) > _distance(indexDip, indexMcp) * 1.1;
    final bool middleStraight = _distance(middleTip, middleMcp) > _distance(middleDip, middleMcp) * 1.1;
    final bool ringStraight = _distance(ringTip, ringMcp) > _distance(ringDip, ringMcp) * 1.1;
    final bool pinkyStraight = _distance(pinkyTip, pinkyMcp) > _distance(pinkyDip, pinkyMcp) * 1.1;

    // TIGHT threshold: both ratio AND straightness must agree
    const double openThreshold = 0.15; // Raised from 0.1 → 0.15
    const double curlThreshold = 0.05; // Below this = definitely curled
    
    bool isIndexOpen = indexRatio > openThreshold && indexStraight;
    bool isMiddleOpen = middleRatio > openThreshold && middleStraight;
    bool isRingOpen = ringRatio > openThreshold && ringStraight;
    bool isPinkyOpen = pinkyRatio > openThreshold && pinkyStraight;

    bool isIndexCurled = indexRatio < curlThreshold || !indexStraight;
    bool isMiddleCurled = middleRatio < curlThreshold || !middleStraight;
    bool isRingCurled = ringRatio < curlThreshold || !ringStraight;
    bool isPinkyCurled = pinkyRatio < curlThreshold || !pinkyStraight;

    int openCount = [isIndexOpen, isMiddleOpen, isRingOpen, isPinkyOpen].where((f) => f).length;
    int curledCount = [isIndexCurled, isMiddleCurled, isRingCurled, isPinkyCurled].where((f) => f).length;

    // ====================================================================
    // GESTURE CLASSIFICATION (strict, ordered by specificity)
    // ====================================================================

    // --- PINCH / PRE-SNAP: Thumb tip very close to index OR middle tip ---
    final double thumbIndexDist = _distance(thumbTip, indexTip);
    final double thumbMiddleDist = _distance(thumbTip, middleTip);
    
    if (thumbIndexDist < palmSize * 0.2 || thumbMiddleDist < palmSize * 0.25) {
      // Thumb and index/middle are touching/very close
      // Other fingers should be relatively relaxed (not all curled = that's a fist)
      if (curledCount < 3) {
        return GestureType.pinch;
      }
    }

    // --- FIST: ALL 4 fingers curled tight ---
    if (curledCount >= 4) {
      // Extra validation: all fingertips close to palm
      final double avgTipDist = (
        _distance(indexTip, wrist) +
        _distance(middleTip, wrist) +
        _distance(ringTip, wrist) +
        _distance(pinkyTip, wrist)
      ) / 4.0;
      if (avgTipDist < palmSize * 0.85) {
        return GestureType.fist;
      }
    }

    // --- POINT: ONLY index extended, all others curled ---
    if (isIndexOpen && isMiddleCurled && isRingCurled && isPinkyCurled) {
      // Extra: index tip must be significantly away from wrist
      if (_distance(indexTip, wrist) > palmSize * 1.3) {
        return GestureType.point;
      }
    }

    // --- V-SIGN: Index + Middle extended, Ring + Pinky curled ---
    if (isIndexOpen && isMiddleOpen && isRingCurled && isPinkyCurled) {
      // Extra: the two fingers should be spread apart
      final double spread = _distance(indexTip, middleTip);
      if (spread > palmSize * 0.25) {
        return GestureType.vSign;
      }
    }

    // --- OPEN PALM: All 4 fingers extended ---
    if (openCount >= 4) {
      return GestureType.openPalm;
    }

    // Ambiguous state — return none (don't guess)
    return GestureType.none;
  }

  double _distance(Landmark p1, Landmark p2) {
    return sqrt(
      pow(p1.x - p2.x, 2) +
      pow(p1.y - p2.y, 2) +
      pow(p1.z - p2.z, 2),
    );
  }
}
