import 'package:shared_preferences/shared_preferences.dart';

class SaveSystem {
  static const String _levelKey = 'player_level';
  static const String _xpKey = 'player_xp';

  Future<void> saveProgress(int level, int currentXp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_levelKey, level);
    await prefs.setInt(_xpKey, currentXp);
  }

  Future<int> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_levelKey) ?? 1; // Default to level 1
  }

  Future<int> loadXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_xpKey) ?? 0; // Default to 0 XP
  }
}
