class MapNode {
  final String id;
  final String label;
  final double x;
  final double y;

  /// First wave index for this node (inclusive).
  final int startWave;

  /// Last wave index for this node (inclusive).
  final int endWave;
  final List<String> unlocks;

  const MapNode({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.startWave,
    required this.endWave,
    this.unlocks = const [],
  });

  int get totalWaves => endWave - startWave + 1;
}

class MapGraph {
  // Coordinates are defined in a logical space (e.g. 0-2000 x 0-2000)
  static const Map<String, MapNode> nodes = {
    '1': MapNode(
      id: '1',
      label: 'SECTOR ALPHA',
      x: 1000,
      y: 1800,
      startWave: 1,
      endWave: 3,
      unlocks: ['2a', '2b'],
    ),
    '2a': MapNode(
      id: '2a',
      label: 'NEON BLVD',
      x: 600,
      y: 1500,
      startWave: 4,
      endWave: 6,
      unlocks: ['3a'],
    ),
    '2b': MapNode(
      id: '2b',
      label: 'DARK ALLEY',
      x: 1400,
      y: 1450,
      startWave: 7,
      endWave: 9,
      unlocks: ['3b'],
    ),
    '3a': MapNode(
      id: '3a',
      label: 'CORP PLAZA',
      x: 500,
      y: 1100,
      startWave: 10,
      endWave: 13,
      unlocks: ['4a', '4b'],
    ),
    '3b': MapNode(
      id: '3b',
      label: 'UNDERGROUND',
      x: 1500,
      y: 1100,
      startWave: 10,
      endWave: 13,
      unlocks: ['4b'],
    ),
    '4a': MapNode(
      id: '4a',
      label: 'SYS-MAIN',
      x: 700,
      y: 700,
      startWave: 14,
      endWave: 17,
      unlocks: ['5'],
    ),
    '4b': MapNode(
      id: '4b',
      label: 'THE HUB',
      x: 1300,
      y: 750,
      startWave: 14,
      endWave: 17,
      unlocks: ['5'],
    ),
    '5': MapNode(
      id: '5',
      label: 'CORE FRAME',
      x: 1000,
      y: 400,
      startWave: 18,
      endWave: 21,
      unlocks: ['6'],
    ),
    '6': MapNode(
      id: '6',
      label: 'SERVER ZERO',
      x: 1000,
      y: 100,
      startWave: 22,
      endWave: 24,
      unlocks: [],
    ),
  };
}
