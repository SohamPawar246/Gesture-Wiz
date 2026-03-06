class Landmark {
  final double x; // 0.0 to 1.0 (left to right)
  final double y; // 0.0 to 1.0 (top to bottom)
  final double z; // Depth

  const Landmark({
    required this.x,
    required this.y,
    required this.z,
  });

  /// Linearly interpolate from this landmark toward [other] by factor [t] (0.0–1.0).
  /// Used for temporal smoothing: blend previous smoothed position toward newest raw data.
  Landmark lerp(Landmark other, double t) {
    return Landmark(
      x: x + (other.x - x) * t,
      y: y + (other.y - y) * t,
      z: z + (other.z - z) * t,
    );
  }

  @override
  String toString() => 'Landmark(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}
