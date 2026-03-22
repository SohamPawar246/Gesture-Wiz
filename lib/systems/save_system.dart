import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'error_notification_service.dart';

/// Current save data version. Increment when save format changes.
const int kSaveVersion = 1;

/// Represents the complete save state for migration purposes.
class SaveData {
  final int version;
  final int level;
  final int xp;
  final List<String> unlockedNodes;
  final List<String> completedNodes;
  final String currentNode;
  final DateTime? lastSaved;
  final String? checksum;

  const SaveData({
    required this.version,
    required this.level,
    required this.xp,
    required this.unlockedNodes,
    required this.completedNodes,
    required this.currentNode,
    this.lastSaved,
    this.checksum,
  });

  /// Create from JSON map
  factory SaveData.fromJson(Map<String, dynamic> json) {
    return SaveData(
      version: json['version'] as int? ?? 1,
      level: json['level'] as int? ?? 1,
      xp: json['xp'] as int? ?? 0,
      unlockedNodes:
          (json['unlockedNodes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['1'],
      completedNodes:
          (json['completedNodes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      currentNode: json['currentNode'] as String? ?? '1',
      lastSaved: json['lastSaved'] != null
          ? DateTime.tryParse(json['lastSaved'] as String)
          : null,
      checksum: json['checksum'] as String?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'level': level,
      'xp': xp,
      'unlockedNodes': unlockedNodes,
      'completedNodes': completedNodes,
      'currentNode': currentNode,
      'lastSaved': DateTime.now().toIso8601String(),
      'checksum': _computeChecksum(),
    };
  }

  /// Compute a simple checksum for corruption detection
  String _computeChecksum() {
    final data =
        '$version|$level|$xp|${unlockedNodes.join(",")}|'
        '${completedNodes.join(",")}|$currentNode';
    // Simple hash - not cryptographic, just for corruption detection
    var hash = 0;
    for (var i = 0; i < data.length; i++) {
      hash = ((hash << 5) - hash + data.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  /// Verify the checksum matches
  bool verifyChecksum() {
    if (checksum == null) return true; // Old saves without checksum
    return checksum == _computeChecksum();
  }

  /// Default empty save
  static SaveData get defaultSave => const SaveData(
    version: kSaveVersion,
    level: 1,
    xp: 0,
    unlockedNodes: ['1'],
    completedNodes: [],
    currentNode: '1',
  );
}

/// Enhanced save system with versioning, migration, and corruption detection.
class SaveSystem {
  // Legacy keys (for backwards compatibility)
  static const String _levelKey = 'player_level';
  static const String _xpKey = 'player_xp';
  static const String _unlockedNodesKey = 'map_unlocked_nodes';
  static const String _completedNodesKey = 'map_completed_nodes';
  static const String _currentNodeKey = 'map_current_node';

  // New versioned save key
  static const String _saveDataKey = 'save_data_v2';
  static const String _backupKey = 'save_data_backup';
  static const String _versionKey = 'save_version';

  bool _migrationPerformed = false;

  /// Whether a migration was performed on last load
  bool get migrationPerformed => _migrationPerformed;

  /// Load all save data with migration support
  Future<SaveData> loadAll() async {
    _migrationPerformed = false;
    final prefs = await SharedPreferences.getInstance();

    // Try to load new format first
    final saveJson = prefs.getString(_saveDataKey);
    if (saveJson != null) {
      try {
        final json = jsonDecode(saveJson) as Map<String, dynamic>;
        final saveData = SaveData.fromJson(json);

        // Verify checksum
        if (!saveData.verifyChecksum()) {
          ErrorNotificationService.instance.warning(
            'Save Data Warning',
            'Save data may be corrupted. Attempting to use backup.',
          );
          return _loadBackup(prefs);
        }

        // Run migrations if needed
        if (saveData.version < kSaveVersion) {
          return _migrate(saveData);
        }

        return saveData;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error loading save data: $e');
        }
        return _loadBackup(prefs);
      }
    }

    // Try to migrate from legacy format
    final legacyVersion = prefs.getInt(_versionKey);
    if (legacyVersion == null) {
      // Check if there's any legacy data
      final hasLegacy =
          prefs.containsKey(_levelKey) || prefs.containsKey(_unlockedNodesKey);
      if (hasLegacy) {
        return _migrateLegacy(prefs);
      }
    }

    // No save data - return defaults
    return SaveData.defaultSave;
  }

  /// Migrate from legacy (pre-versioning) save format
  Future<SaveData> _migrateLegacy(SharedPreferences prefs) async {
    _migrationPerformed = true;

    if (kDebugMode) {
      debugPrint('Migrating from legacy save format...');
    }

    final saveData = SaveData(
      version: kSaveVersion,
      level: prefs.getInt(_levelKey) ?? 1,
      xp: prefs.getInt(_xpKey) ?? 0,
      unlockedNodes: prefs.getStringList(_unlockedNodesKey) ?? ['1'],
      completedNodes: prefs.getStringList(_completedNodesKey) ?? [],
      currentNode: prefs.getString(_currentNodeKey) ?? '1',
    );

    // Save in new format
    await _saveInternal(prefs, saveData);

    ErrorNotificationService.instance.info(
      'Save Migrated',
      'Your save data has been upgraded to the new format.',
    );

    return saveData;
  }

  /// Migrate between versions
  Future<SaveData> _migrate(SaveData oldSave) async {
    _migrationPerformed = true;
    var save = oldSave;

    // Version-specific migrations
    // Example: if (save.version < 2) { save = _migrateV1ToV2(save); }

    // Update version
    final migrated = SaveData(
      version: kSaveVersion,
      level: save.level,
      xp: save.xp,
      unlockedNodes: save.unlockedNodes,
      completedNodes: save.completedNodes,
      currentNode: save.currentNode,
    );

    // Save migrated data
    final prefs = await SharedPreferences.getInstance();
    await _saveInternal(prefs, migrated);

    if (kDebugMode) {
      debugPrint('Migrated save from v${oldSave.version} to v$kSaveVersion');
    }

    return migrated;
  }

  /// Load backup save data
  Future<SaveData> _loadBackup(SharedPreferences prefs) async {
    final backupJson = prefs.getString(_backupKey);
    if (backupJson != null) {
      try {
        final json = jsonDecode(backupJson) as Map<String, dynamic>;
        final backup = SaveData.fromJson(json);

        ErrorNotificationService.instance.info(
          'Backup Restored',
          'Your progress was restored from a backup.',
        );

        return backup;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Backup also corrupted: $e');
        }
      }
    }

    ErrorNotificationService.instance.error(
      'Save Data Lost',
      'Could not recover your save data. Starting fresh.',
    );

    return SaveData.defaultSave;
  }

  /// Save all data with backup
  Future<bool> saveAll(SaveData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create backup of current save before overwriting
      final currentSave = prefs.getString(_saveDataKey);
      if (currentSave != null) {
        await prefs.setString(_backupKey, currentSave);
      }

      await _saveInternal(prefs, data);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving: $e');
      }
      ErrorNotificationService.instance.saveFailed();
      return false;
    }
  }

  Future<void> _saveInternal(SharedPreferences prefs, SaveData data) async {
    final json = data.toJson();
    await prefs.setString(_saveDataKey, jsonEncode(json));
    await prefs.setInt(_versionKey, kSaveVersion);

    // Also save in legacy format for backwards compatibility
    await prefs.setInt(_levelKey, data.level);
    await prefs.setInt(_xpKey, data.xp);
    await prefs.setStringList(_unlockedNodesKey, data.unlockedNodes);
    await prefs.setStringList(_completedNodesKey, data.completedNodes);
    await prefs.setString(_currentNodeKey, data.currentNode);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Legacy API (for backwards compatibility with existing code)
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> saveProgress(int level, int currentXp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_levelKey, level);
    await prefs.setInt(_xpKey, currentXp);

    // Also update versioned save if it exists
    await _updateVersionedSave(
      prefs,
      (data) => SaveData(
        version: data.version,
        level: level,
        xp: currentXp,
        unlockedNodes: data.unlockedNodes,
        completedNodes: data.completedNodes,
        currentNode: data.currentNode,
      ),
    );
  }

  Future<int> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_levelKey) ?? 1;
  }

  Future<int> loadXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_xpKey) ?? 0;
  }

  Future<void> saveMapProgress(
    List<String> unlockedNodes,
    List<String> completedNodes,
    String currentNode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedNodesKey, unlockedNodes);
    await prefs.setStringList(_completedNodesKey, completedNodes);
    await prefs.setString(_currentNodeKey, currentNode);

    // Also update versioned save if it exists
    await _updateVersionedSave(
      prefs,
      (data) => SaveData(
        version: data.version,
        level: data.level,
        xp: data.xp,
        unlockedNodes: unlockedNodes,
        completedNodes: completedNodes,
        currentNode: currentNode,
      ),
    );
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

  /// Helper to update versioned save when using legacy API
  Future<void> _updateVersionedSave(
    SharedPreferences prefs,
    SaveData Function(SaveData) updater,
  ) async {
    final saveJson = prefs.getString(_saveDataKey);
    if (saveJson == null) return;

    try {
      final json = jsonDecode(saveJson) as Map<String, dynamic>;
      final current = SaveData.fromJson(json);
      final updated = updater(current);
      await prefs.setString(_saveDataKey, jsonEncode(updated.toJson()));
    } catch (_) {
      // Ignore errors in background update
    }
  }

  /// Clear all save data (for testing or reset)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveDataKey);
    await prefs.remove(_backupKey);
    await prefs.remove(_versionKey);
    await prefs.remove(_levelKey);
    await prefs.remove(_xpKey);
    await prefs.remove(_unlockedNodesKey);
    await prefs.remove(_completedNodesKey);
    await prefs.remove(_currentNodeKey);
  }

  /// Export save data as JSON string (for debugging/backup)
  Future<String?> exportSave() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_saveDataKey);
  }

  /// Import save data from JSON string
  Future<bool> importSave(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final data = SaveData.fromJson(json);
      return await saveAll(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Import failed: $e');
      }
      return false;
    }
  }
}
