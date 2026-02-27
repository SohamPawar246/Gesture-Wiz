class Landmark {
  final double x; // 0.0 to 1.0 (left to right)
  final double y; // 0.0 to 1.0 (top to bottom)
  final double z; // Depth

  const Landmark({
    required this.x,
    required this.y,
    required this.z,
  });

  @override
  String toString() => 'Landmark(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}
