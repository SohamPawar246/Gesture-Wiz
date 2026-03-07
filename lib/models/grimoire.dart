import 'spell.dart';

class Grimoire {
  final String title;
  final List<GameAction> actions;
  bool unlocked;

  Grimoire({
    required this.title,
    required this.actions,
    this.unlocked = false,
  });
}
