import 'spell.dart';

class Grimoire {
  final String title;
  final List<Spell> spells;
  bool unlocked;

  Grimoire({
    required this.title,
    required this.spells,
    this.unlocked = false,
  });
}
