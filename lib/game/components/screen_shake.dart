import 'dart:math';
import 'package:flame/components.dart';

/// Applies a decaying camera shake effect when triggered.
/// Add to the game and call `trigger()` to shake.
class ScreenShake extends Component with HasGameReference {
  final Random _rng = Random();
  double _intensity = 0;
  double _decay = 8.0; // How fast the shake fades

  /// Trigger a shake with the given intensity (pixels of offset)
  void trigger({double intensity = 12.0, double decay = 8.0}) {
    _intensity = intensity;
    _decay = decay;
  }

  @override
  void update(double dt) {
    if (_intensity > 0.5) {
      final offsetX = (_rng.nextDouble() - 0.5) * 2 * _intensity;
      final offsetY = (_rng.nextDouble() - 0.5) * 2 * _intensity;
      game.camera.viewfinder.position = Vector2(offsetX, offsetY);
      _intensity *= (1.0 - _decay * dt).clamp(0.0, 1.0);
    } else if (_intensity > 0) {
      _intensity = 0;
      game.camera.viewfinder.position = Vector2.zero();
    }
  }
}
