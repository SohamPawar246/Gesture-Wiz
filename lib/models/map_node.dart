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

  /// Short storyline shown after completing this node.
  final String briefing;

  const MapNode({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.startWave,
    required this.endWave,
    this.unlocks = const [],
    this.briefing = '',
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
      briefing:
          'SECTOR ALPHA \u2014 CLEARED.\n\n'
          'The outer firewall crumbles behind you.\n'
          'Deeper in the Grid, the signal forks \u2014\n'
          'neon lights flicker to the west,\n'
          'shadows pool in the eastern corridors.\n\n'
          'The Ministry knows you are coming.',
    ),
    '2a': MapNode(
      id: '2a',
      label: 'NEON BLVD',
      x: 600,
      y: 1500,
      startWave: 4,
      endWave: 6,
      unlocks: ['3a'],
      briefing:
          'NEON BLVD \u2014 CLEARED.\n\n'
          'The billboards go dark one by one.\n'
          'Propaganda feeds dissolve into static.\n'
          'Through the dying glow you see it \u2014\n'
          'a corporate spire, still transmitting.\n\n'
          'Someone important doesn\'t want you\n'
          'reaching the upper grid.',
    ),
    '2b': MapNode(
      id: '2b',
      label: 'DARK ALLEY',
      x: 1400,
      y: 1450,
      startWave: 7,
      endWave: 9,
      unlocks: ['3b'],
      briefing:
          'DARK ALLEY \u2014 CLEARED.\n\n'
          'The whispers in the walls have stopped.\n'
          'Erased minds once wandered these tunnels,\n'
          'now only silence and broken code remain.\n'
          'A hidden passage leads further down \u2014\n'
          'into the Underground.',
    ),
    '3a': MapNode(
      id: '3a',
      label: 'CORP PLAZA',
      x: 500,
      y: 1100,
      startWave: 10,
      endWave: 13,
      unlocks: ['4a', '4b'],
      briefing:
          'CORP PLAZA \u2014 CLEARED.\n\n'
          'The Ministry\'s commerce layer lies in ruins.\n'
          'Data vaults hang open, leaking secrets.\n'
          'Two routes branch from the wreckage \u2014\n'
          'the mainframe systems or the central hub.\n\n'
          'Big Brother\'s inner defenses are waking up.',
    ),
    '3b': MapNode(
      id: '3b',
      label: 'UNDERGROUND',
      x: 1500,
      y: 1100,
      startWave: 10,
      endWave: 13,
      unlocks: ['4b'],
      briefing:
          'UNDERGROUND \u2014 CLEARED.\n\n'
          'The forgotten sub-layer collapses behind you.\n'
          'You found something here \u2014 old Resistance\n'
          'code, etched into the Grid\'s foundation.\n'
          'It hums with power the Ministry tried to erase.\n\n'
          'The Hub awaits above.',
    ),
    '4a': MapNode(
      id: '4a',
      label: 'SYS-MAIN',
      x: 700,
      y: 700,
      startWave: 14,
      endWave: 17,
      unlocks: ['5'],
      briefing:
          'SYS-MAIN \u2014 CLEARED.\n\n'
          'The mainframe\'s guardians are silenced.\n'
          'Streams of raw data rush past you \u2014\n'
          'surveillance logs, thought records, kill orders.\n'
          'You can feel the Core pulsing ahead,\n'
          'the heart of Big Brother\'s network.\n\n'
          'Almost there.',
    ),
    '4b': MapNode(
      id: '4b',
      label: 'THE HUB',
      x: 1300,
      y: 750,
      startWave: 14,
      endWave: 17,
      unlocks: ['5'],
      briefing:
          'THE HUB \u2014 CLEARED.\n\n'
          'The central relay station falls silent.\n'
          'Every surveillance feed in the city\n'
          'blinked out for one precious second.\n'
          'Somewhere above, people looked up\n'
          'and saw the sky without a camera watching.\n\n'
          'One final push remains.',
    ),
    '5': MapNode(
      id: '5',
      label: 'CORE FRAME',
      x: 1000,
      y: 400,
      startWave: 18,
      endWave: 21,
      unlocks: ['6'],
      briefing:
          'CORE FRAME \u2014 CLEARED.\n\n'
          'The processor towers shatter like glass.\n'
          'Big Brother\'s mind is fragmenting \u2014\n'
          'its thoughts scattered across dying circuits.\n'
          'But the root process still runs,\n'
          'deep inside Server Zero.\n\n'
          'End this. Now.',
    ),
    '6': MapNode(
      id: '6',
      label: 'SERVER ZERO',
      x: 1000,
      y: 100,
      startWave: 22,
      endWave: 24,
      unlocks: [],
      briefing:
          'SERVER ZERO \u2014 DESTROYED.\n\n'
          'The last process terminates.\n'
          'Big Brother\'s eye closes forever.\n\n'
          'Across the city, cameras go dark.\n'
          'Screens that once broadcast propaganda\n'
          'now display only two words:\n\n'
          'YOU ARE FREE.\n\n'
          'The Resistance will rebuild.\n'
          'The Grid belongs to the people now.\n\n'
          '\u2014 TRANSMISSION ENDS \u2014',
    ),
  };
}
