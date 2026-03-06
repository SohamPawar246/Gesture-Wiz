import 'dart:math';

import '../hand_tracking/landmark_model.dart';
import 'gesture_recognizer.dart';
import 'gesture_type.dart';

/// Tightened gesture recognition with balanced thresholds.
///
/// Philosophy:
///   - Use BOTH the ratio method AND the straightness check, but with slightly
///     relaxed thresholds to tolerate natural camera angle variation.
///   - Temporal smoothing in UdpService handles jitter; this recognizer handles shape.
///   - Each gesture has explicit priority ordering to prevent ambiguous class bleed.
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
    // Using two independent checks and combining with weighted confidence:
    //   Method 1 (ratio): tip-to-wrist extending beyond PIP-to-wrist
    //   Method 2 (straightness): tip farther from MCP than DIP is
    // Thresholds slightly relaxed (0.13 open, 0.10 curl) vs the old 0.15/0.10
    // to compensate for camera angle changes causing false negatives.
    // ====================================================================
    final double indexRatio  = (_distance(indexTip, wrist)  - _distance(indexPip,  wrist)) / palmSize;
    final double middleRatio = (_distance(middleTip, wrist) - _distance(middlePip, wrist)) / palmSize;
    final double ringRatio   = (_distance(ringTip, wrist)   - _distance(ringPip,   wrist)) / palmSize;
    final double pinkyRatio  = (_distance(pinkyTip, wrist)  - _distance(pinkyPip,  wrist)) / palmSize;

    // 1.05x multiplier (was 1.1x) — less sensitive to minor DIP occlusion
    final bool indexStraight  = _distance(indexTip,  indexMcp)  > _distance(indexDip,  indexMcp)  * 1.05;
    final bool middleStraight = _distance(middleTip, middleMcp) > _distance(middleDip, middleMcp) * 1.05;
    final bool ringStraight   = _distance(ringTip,   ringMcp)   > _distance(ringDip,   ringMcp)   * 1.05;
    final bool pinkyStraight  = _distance(pinkyTip,  pinkyMcp)  > _distance(pinkyDip,  pinkyMcp)  * 1.05;

    // Open: ratio above 0.13 (was 0.15) AND straightness agrees
    const double openThreshold = 0.13;
    // Curl: ratio below 0.10 OR not straight — either is sufficient
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
    // GESTURE CLASSIFICATION — ordered from most specific to most general
    // ====================================================================

    // --- PINCH: Thumb very close to index or middle tip ---
    // Guard: only if at most 2 other fingers are curled (avoid fist bleed)
    final double thumbIndexDist  = _distance(thumbTip, indexTip);
    final double thumbMiddleDist = _distance(thumbTip, middleTip);

    if (thumbIndexDist < palmSize * 0.22 || thumbMiddleDist < palmSize * 0.27) {
      // Must NOT be a full fist (curledCount < 3 means at least index or middle is partially free)
      if (curledCount < 3) {
        return GestureType.pinch;
      }
    }

    // --- FIST: ALL 4 fingers curled tight ---
    if (curledCount >= 4) {
      // Primary check: average tip distance close to palm
      final double avgTipDist = (
        _distance(indexTip,  wrist) +
        _distance(middleTip, wrist) +
        _distance(ringTip,   wrist) +
        _distance(pinkyTip,  wrist)
      ) / 4.0;

      if (avgTipDist < palmSize * 1.1) {
        return GestureType.fist;
      }

      // Secondary fallback: if all 4 ratios are negative (tips below PIP level),
      // it's definitively a strong fist even if the wrist estimate drifts
      if (indexRatio < 0 && middleRatio < 0 && ringRatio < 0 && pinkyRatio < 0) {
        return GestureType.fist;
      }
    }

    // --- POINT: ONLY index extended, middle/ring/pinky curled ---
    if (isIndexOpen && isMiddleCurled && isRingCurled && isPinkyCurled) {
      if (_distance(indexTip, wrist) > palmSize * 1.25) { // Slightly relaxed from 1.3
        return GestureType.point;
      }
    }

    // --- V-SIGN: Index + Middle extended, Ring + Pinky curled, fingers spread ---
    if (isIndexOpen && isMiddleOpen && isRingCurled && isPinkyCurled) {
      final double spread = _distance(indexTip, middleTip);
      if (spread > palmSize * 0.20) { // Relaxed from 0.25 — allows closer V signs
        return GestureType.vSign;
      }
    }

    // --- OPEN PALM: 4 fingers extended ---
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
