import 'package:shared_preferences/shared_preferences.dart';

class SaveSystem {
  static const String _levelKey = 'player_level';
  static const String _xpKey = 'player_xp';
  static const String _unlockedNodesKey = 'map_unlocked_nodes';
  static const String _completedNodesKey = 'map_completed_nodes';
  static const String _currentNodeKey = 'map_current_node';

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

  // --- Map Progress ---
  Future<void> saveMapProgress(
    List<String> unlockedNodes,
    List<String> completedNodes,
    String currentNode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedNodesKey, unlockedNodes);
    await prefs.setStringList(_completedNodesKey, completedNodes);
    await prefs.setString(_currentNodeKey, currentNode);
  }

  Future<List<String>> loadUnlockedNodes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedNodesKey) ?? ['1'];
  }

  Future<List<String>> loadCompletedNodes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_completedNodesKey) ?? [];
  }

  Future<String> loadCurrentNode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentNodeKey) ?? '1';
  }
}
