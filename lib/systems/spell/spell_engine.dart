import 'dart:math';

import '../../models/spell.dart';
import '../gesture/gesture_type.dart';

class SpellEngine {
  /// The list of gestures the player has recently performed
  final List<GestureType> _gestureBuffer = [];
  
  /// The maximum number of gestures to remember
  final int maxBufferSize = 5;

  /// Time since the last gesture was added
  double _timeSinceLastGesture = 0;

  /// The last gesture that was processed to prevent frame loop spam
  GestureType _lastStabilizedGesture = GestureType.none;
  
  /// Global timeout window before the combo resets entirely
  final double comboTimeout = 1.5;

  /// The grimorie of all available spells to check against
  final List<Spell> knownSpells;

  SpellEngine({required List<Spell> knownSpells})
      : knownSpells = List.from(knownSpells)
          ..sort((a, b) => b.requiredGestures.length.compareTo(a.requiredGestures.length));

  /// Feeds a new, stabilized gesture into the engine.
  /// Returns a Spell if a combo is matched, otherwise null.
  Spell? processGesture(GestureType newGesture) {
    // Prevent 60fps spamming of the same held gesture
    if (newGesture == _lastStabilizedGesture) return null;
    _lastStabilizedGesture = newGesture;

    // Ignore the camera resting state (or loss of tracking) so it doesn't pad the combat buffer
    if (newGesture == GestureType.none || newGesture == GestureType.openPalm) {
      return null;
    }

    // Add to buffer
    _gestureBuffer.add(newGesture);
    if (_gestureBuffer.length > maxBufferSize) {
      _gestureBuffer.removeAt(0);
    }
    
    // Reset timer on new input
    _timeSinceLastGesture = 0;

    // Check for pattern matches (longest combos first)
    for (var spell in knownSpells) {
      if (_matchesCombo(spell.requiredGestures)) {
        // Clear buffer after successful cast
        _gestureBuffer.clear();
        return spell;
      }
    }

    return null;
  }

  /// Called every frame to tick the timeout clock
  void update(double dt) {
    if (_gestureBuffer.isNotEmpty) {
      _timeSinceLastGesture += dt;
      if (_timeSinceLastGesture >= comboTimeout) {
        _gestureBuffer.clear();
        _lastStabilizedGesture = GestureType.none;
      }
    }
  }

  /// Checks if the end of the current buffer matches the target combo perfectly
  bool _matchesCombo(List<GestureType> requiredPattern) {
    if (requiredPattern.isEmpty || _gestureBuffer.length < requiredPattern.length) {
      return false;
    }

    // Check if the most recent N gestures match the required N pattern
    int startIdx = _gestureBuffer.length - requiredPattern.length;
    for (int i = 0; i < requiredPattern.length; i++) {
      if (_gestureBuffer[startIdx + i] != requiredPattern[i]) {
        return false;
      }
    }
    return true;
  }

  /// Read-only access to the current combo for UI rendering
  List<GestureType> get currentCombo => List.unmodifiable(_gestureBuffer);
  double get timeoutProgress => min(_timeSinceLastGesture / comboTimeout, 1.0);
}
