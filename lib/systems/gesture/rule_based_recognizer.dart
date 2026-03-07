import 'dart:math';

import '../hand_tracking/landmark_model.dart';
import 'gesture_recognizer.dart';
import 'gesture_type.dart';

/// Gesture recognition with tuned thresholds for THE EYE's direct-action system.
///
/// Key design principles:
///   - Pinch must NOT bleed from fist: require other fingers to be partially open
///   - Fist requires ALL 4 fingers curled AND tips close to palm
///   - OpenPalm is the default relaxed state — easy to enter and sustain
///   - Point and VSign have strict shape requirements to avoid false triggers
class RuleBasedRecognizer implements GestureRecognizer {
  @override
  GestureType recognize(List<Landmark> landmarks) {
    if (landmarks.length != 21) return GestureType.none;

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
    if (palmSize < 0.01) return GestureType.none;

    // ====================================================================
    // FINGER EXTENSION DETECTION
    // ====================================================================
    final double indexRatio  = (_distance(indexTip, wrist)  - _distance(indexPip,  wrist)) / palmSize;
    final double middleRatio = (_distance(middleTip, wrist) - _distance(middlePip, wrist)) / palmSize;
    final double ringRatio   = (_distance(ringTip, wrist)   - _distance(ringPip,   wrist)) / palmSize;
    final double pinkyRatio  = (_distance(pinkyTip, wrist)  - _distance(pinkyPip,  wrist)) / palmSize;

    // Straightness check (1.05x tolerance for camera angle variation)
    final bool indexStraight  = _distance(indexTip,  indexMcp)  > _distance(indexDip,  indexMcp)  * 1.05;
    final bool middleStraight = _distance(middleTip, middleMcp) > _distance(middleDip, middleMcp) * 1.05;
    final bool ringStraight   = _distance(ringTip,   ringMcp)   > _distance(ringDip,   ringMcp)   * 1.05;
    final bool pinkyStraight  = _distance(pinkyTip,  pinkyMcp)  > _distance(pinkyDip,  pinkyMcp)  * 1.05;

    const double openThreshold = 0.13;
    const double curlThreshold = 0.10;

    final bool isIndexOpen   = indexRatio  > openThreshold && indexStraight;
    final bool isMiddleOpen  = middleRatio > openThreshold && middleStraight;
    final bool isRingOpen    = ringRatio   > openThreshold && ringStraight;
    final bool isPinkyOpen   = pinkyRatio  > openThreshold && pinkyStraight;

    final bool isIndexCurled  = indexRatio  < curlThreshold || !indexStraight;
    final bool isMiddleCurled = middleRatio < curlThreshold || !middleStraight;
    final bool isRingCurled   = ringRatio   < curlThreshold || !ringStraight;
    final bool isPinkyCurled  = pinkyRatio  < curlThreshold || !pinkyStraight;

    final int openCount   = [isIndexOpen,   isMiddleOpen,  isRingOpen,   isPinkyOpen].where((f) => f).length;
    final int curledCount = [isIndexCurled, isMiddleCurled, isRingCurled, isPinkyCurled].where((f) => f).length;

    // ====================================================================
    // GESTURE CLASSIFICATION — strict priority ordering
    // ====================================================================

    // --- OPEN PALM (highest priority — it's the default/resting state) ---
    // Must have all 4 fingers clearly extended. Check FIRST so it takes
    // priority over partial matches.
    if (openCount >= 4) {
      return GestureType.openPalm;
    }

    // --- PINCH: Thumb + Index very close, BUT other fingers NOT all curled ---
    // This is the key fix: if curledCount >= 3 AND thumb-index are close,
    // it's probably a fist, not a pinch. Real pinch = thumb touches index
    // while middle/ring/pinky are relaxed (not tightly curled).
    final double thumbIndexDist  = _distance(thumbTip, indexTip);
    final double thumbMiddleDist = _distance(thumbTip, middleTip);

    if (thumbIndexDist < palmSize * 0.18 || thumbMiddleDist < palmSize * 0.22) {
      // Anti-fist guard: at least 2 of (middle, ring, pinky) should NOT be curled
      final int othersCurled = [isMiddleCurled, isRingCurled, isPinkyCurled].where((f) => f).length;
      if (othersCurled <= 1) {
        return GestureType.pinch;
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
        return GestureType.fist;
      }

      // Fallback: all ratios negative = strong fist
      if (indexRatio < 0 && middleRatio < 0 && ringRatio < 0 && pinkyRatio < 0) {
        return GestureType.fist;
      }
    }

    // --- POINT: ONLY index extended ---
    if (isIndexOpen && isMiddleCurled && isRingCurled && isPinkyCurled) {
      if (_distance(indexTip, wrist) > palmSize * 1.2) {
        return GestureType.point;
      }
    }

    // --- V-SIGN: Index + Middle extended, Ring + Pinky curled ---
    if (isIndexOpen && isMiddleOpen && isRingCurled && isPinkyCurled) {
      final double spread = _distance(indexTip, middleTip);
      if (spread > palmSize * 0.18) {
        return GestureType.vSign;
      }
    }

    // Ambiguous — return none (don't guess)
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
