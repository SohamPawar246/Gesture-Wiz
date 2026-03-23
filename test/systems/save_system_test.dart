import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_magic/systems/save_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SaveData', () {
    test('should create from JSON with all fields', () {
      final json = {
        'version': 1,
        'level': 5,
        'xp': 250,
        'unlockedNodes': ['1', '2', '3'],
        'completedNodes': ['1', '2'],
        'currentNode': '3',
        'lastSaved': '2026-03-22T10:00:00.000Z',
        'checksum': 'abc123',
      };

      final saveData = SaveData.fromJson(json);

      expect(saveData.version, 1);
      expect(saveData.level, 5);
      expect(saveData.xp, 250);
      expect(saveData.unlockedNodes, ['1', '2', '3']);
      expect(saveData.completedNodes, ['1', '2']);
      expect(saveData.currentNode, '3');
      expect(saveData.lastSaved, isNotNull);
      expect(saveData.checksum, 'abc123');
    });

    test('should use defaults for missing JSON fields', () {
      final saveData = SaveData.fromJson({});

      expect(saveData.version, 1);
      expect(saveData.level, 1);
      expect(saveData.xp, 0);
      expect(saveData.unlockedNodes, ['1']);
      expect(saveData.completedNodes, isEmpty);
      expect(saveData.currentNode, '1');
    });

    test('should convert to JSON', () {
      const saveData = SaveData(
        hasSeenCameraPermission: false,
        version: 1,
        level: 3,
        xp: 100,
        unlockedNodes: ['1', '2'],
        completedNodes: ['1'],
        currentNode: '2',
      );

      final json = saveData.toJson();

      expect(json['version'], 1);
      expect(json['level'], 3);
      expect(json['xp'], 100);
      expect(json['unlockedNodes'], ['1', '2']);
      expect(json['completedNodes'], ['1']);
      expect(json['currentNode'], '2');
      expect(json['lastSaved'], isNotNull);
      expect(json['checksum'], isNotNull);
    });

    test('should verify valid checksum', () {
      const saveData = SaveData(
        hasSeenCameraPermission: false,
        version: 1,
        level: 5,
        xp: 100,
        unlockedNodes: ['1', '2'],
        completedNodes: ['1'],
        currentNode: '2',
      );

      // Generate checksum via toJson, then recreate with that checksum
      final json = saveData.toJson();
      final dataWithChecksum = SaveData.fromJson(json);

      expect(dataWithChecksum.verifyChecksum(), isTrue);
    });

    test('should detect invalid checksum', () {
      final saveData = SaveData.fromJson({
        'version': 1,
        'level': 5,
        'xp': 100,
        'unlockedNodes': ['1', '2'],
        'completedNodes': ['1'],
        'currentNode': '2',
        'checksum': 'invalid_checksum',
      });

      expect(saveData.verifyChecksum(), isFalse);
    });

    test('should accept null checksum (old saves)', () {
      final saveData = SaveData.fromJson({
        'version': 1,
        'level': 5,
        'xp': 100,
        'unlockedNodes': ['1', '2'],
        'completedNodes': ['1'],
        'currentNode': '2',
        // No checksum field
      });

      expect(saveData.verifyChecksum(), isTrue);
    });

    test('defaultSave should have expected values', () {
      final defaultSave = SaveData.defaultSave;

      expect(defaultSave.version, kSaveVersion);
      expect(defaultSave.level, 1);
      expect(defaultSave.xp, 0);
      expect(defaultSave.unlockedNodes, ['1']);
      expect(defaultSave.completedNodes, isEmpty);
      expect(defaultSave.currentNode, '1');
    });
  });

  group('SaveSystem', () {
    late SaveSystem saveSystem;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      saveSystem = SaveSystem();
    });

    group('player progress', () {
      test('should save and load level', () async {
        await saveSystem.saveProgress(5, 100);
        final level = await saveSystem.loadLevel();
        expect(level, 5);
      });

      test('should save and load XP', () async {
        await saveSystem.saveProgress(3, 250);
        final xp = await saveSystem.loadXp();
        expect(xp, 250);
      });

      test('should default to level 1 when no data', () async {
        final level = await saveSystem.loadLevel();
        expect(level, 1);
      });

      test('should default to 0 XP when no data', () async {
        final xp = await saveSystem.loadXp();
        expect(xp, 0);
      });
    });

    group('map progress', () {
      test('should save and load unlocked nodes', () async {
        await saveSystem.saveMapProgress(['1', '2', '3', '4'], ['1', '2'], '3');

        final unlocked = await saveSystem.loadUnlockedNodes();
        expect(unlocked, ['1', '2', '3', '4']);
      });

      test('should save and load completed nodes', () async {
        await saveSystem.saveMapProgress(['1', '2', '3'], ['1', '2'], '3');

        final completed = await saveSystem.loadCompletedNodes();
        expect(completed, ['1', '2']);
      });

      test('should save and load current node', () async {
        await saveSystem.saveMapProgress(['1', '2'], ['1'], '2');

        final current = await saveSystem.loadCurrentNode();
        expect(current, '2');
      });

      test('should default to node 1 for unlocked when no data', () async {
        final unlocked = await saveSystem.loadUnlockedNodes();
        expect(unlocked, ['1']);
      });

      test('should default to empty list for completed when no data', () async {
        final completed = await saveSystem.loadCompletedNodes();
        expect(completed, isEmpty);
      });

      test('should default to node 1 for current when no data', () async {
        final current = await saveSystem.loadCurrentNode();
        expect(current, '1');
      });
    });

    group('persistence isolation', () {
      test('saving progress should not affect map progress', () async {
        await saveSystem.saveMapProgress(['1', '2'], ['1'], '2');
        await saveSystem.saveProgress(10, 500);

        final unlocked = await saveSystem.loadUnlockedNodes();
        expect(unlocked, ['1', '2']);
      });

      test('saving map progress should not affect player progress', () async {
        await saveSystem.saveProgress(7, 300);
        await saveSystem.saveMapProgress(['1', '2', '3'], ['1', '2'], '3');

        final level = await saveSystem.loadLevel();
        final xp = await saveSystem.loadXp();
        expect(level, 7);
        expect(xp, 300);
      });
    });

    group('overwrite behavior', () {
      test('should overwrite previous save data', () async {
        await saveSystem.saveProgress(5, 100);
        await saveSystem.saveProgress(8, 250);

        final level = await saveSystem.loadLevel();
        final xp = await saveSystem.loadXp();
        expect(level, 8);
        expect(xp, 250);
      });

      test('should overwrite map progress', () async {
        await saveSystem.saveMapProgress(['1'], [], '1');
        await saveSystem.saveMapProgress(['1', '2', '3'], ['1', '2'], '3');

        final unlocked = await saveSystem.loadUnlockedNodes();
        final completed = await saveSystem.loadCompletedNodes();
        final current = await saveSystem.loadCurrentNode();

        expect(unlocked, ['1', '2', '3']);
        expect(completed, ['1', '2']);
        expect(current, '3');
      });
    });

    group('versioned save system', () {
      test('should save and load complete SaveData', () async {
        const saveData = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 7,
          xp: 350,
          unlockedNodes: ['1', '2', '3', '4'],
          completedNodes: ['1', '2', '3'],
          currentNode: '4',
        );

        final saved = await saveSystem.saveAll(saveData);
        expect(saved, isTrue);

        final loaded = await saveSystem.loadAll();
        expect(loaded.version, 1);
        expect(loaded.level, 7);
        expect(loaded.xp, 350);
        expect(loaded.unlockedNodes, ['1', '2', '3', '4']);
        expect(loaded.completedNodes, ['1', '2', '3']);
        expect(loaded.currentNode, '4');
      });

      test('should load default SaveData when no data exists', () async {
        final loaded = await saveSystem.loadAll();

        expect(loaded.version, kSaveVersion);
        expect(loaded.level, 1);
        expect(loaded.xp, 0);
        expect(loaded.unlockedNodes, ['1']);
        expect(loaded.completedNodes, isEmpty);
        expect(loaded.currentNode, '1');
      });

      test('should create backup before overwriting save', () async {
        const firstSave = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 5,
          xp: 100,
          unlockedNodes: ['1', '2'],
          completedNodes: ['1'],
          currentNode: '2',
        );

        await saveSystem.saveAll(firstSave);

        const secondSave = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 10,
          xp: 500,
          unlockedNodes: ['1', '2', '3'],
          completedNodes: ['1', '2'],
          currentNode: '3',
        );

        await saveSystem.saveAll(secondSave);

        // Backup should exist in prefs
        final prefs = await SharedPreferences.getInstance();
        final backup = prefs.getString('save_data_backup');
        expect(backup, isNotNull);

        // Backup should contain first save data
        final backupJson = jsonDecode(backup!) as Map<String, dynamic>;
        expect(backupJson['level'], 5);
        expect(backupJson['xp'], 100);
      });

      test('should verify checksum on load', () async {
        const saveData = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 5,
          xp: 200,
          unlockedNodes: ['1', '2'],
          completedNodes: ['1'],
          currentNode: '2',
        );

        await saveSystem.saveAll(saveData);
        final loaded = await saveSystem.loadAll();

        expect(loaded.verifyChecksum(), isTrue);
        expect(loaded.level, 5);
      });

      test('should restore from backup if checksum invalid', () async {
        // Save initial data
        const initialSave = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 3,
          xp: 50,
          unlockedNodes: ['1'],
          completedNodes: [],
          currentNode: '1',
        );
        await saveSystem.saveAll(initialSave);

        // Save again to create backup of initial save
        const secondSave = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 5,
          xp: 100,
          unlockedNodes: ['1', '2'],
          completedNodes: ['1'],
          currentNode: '2',
        );
        await saveSystem.saveAll(secondSave);

        // Manually corrupt the main save
        final prefs = await SharedPreferences.getInstance();
        final corruptedJson = jsonEncode({
          'version': 1,
          'level': 10,
          'xp': 500,
          'unlockedNodes': ['1', '2', '3'],
          'completedNodes': ['1', '2'],
          'currentNode': '3',
          'checksum': 'definitely_wrong_checksum',
        });
        await prefs.setString('save_data_v2', corruptedJson);

        // Should load from backup (which is the initial save)
        final loaded = await saveSystem.loadAll();
        expect(loaded.level, 3); // From backup
        expect(loaded.xp, 50); // From backup
      });
    });

    group('legacy migration', () {
      test('should migrate from legacy format', () async {
        // Set up legacy save data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('player_level', 8);
        await prefs.setInt('player_xp', 400);
        await prefs.setStringList('map_unlocked_nodes', ['1', '2', '3', '4']);
        await prefs.setStringList('map_completed_nodes', ['1', '2', '3']);
        await prefs.setString('map_current_node', '4');

        // Load should trigger migration
        final loaded = await saveSystem.loadAll();

        expect(loaded.version, kSaveVersion);
        expect(loaded.level, 8);
        expect(loaded.xp, 400);
        expect(loaded.unlockedNodes, ['1', '2', '3', '4']);
        expect(loaded.completedNodes, ['1', '2', '3']);
        expect(loaded.currentNode, '4');
        expect(saveSystem.migrationPerformed, isTrue);
      });

      test('should not set migration flag when loading new format', () async {
        const saveData = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 5,
          xp: 100,
          unlockedNodes: ['1', '2'],
          completedNodes: ['1'],
          currentNode: '2',
        );

        await saveSystem.saveAll(saveData);
        await saveSystem.loadAll();

        expect(saveSystem.migrationPerformed, isFalse);
      });

      test('should maintain legacy API compatibility after versioned save', () async {
        // Save using new API
        const saveData = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 6,
          xp: 300,
          unlockedNodes: ['1', '2', '3'],
          completedNodes: ['1', '2'],
          currentNode: '3',
        );
        await saveSystem.saveAll(saveData);

        // Legacy API should still work
        final level = await saveSystem.loadLevel();
        final xp = await saveSystem.loadXp();
        final unlocked = await saveSystem.loadUnlockedNodes();
        final completed = await saveSystem.loadCompletedNodes();
        final current = await saveSystem.loadCurrentNode();

        expect(level, 6);
        expect(xp, 300);
        expect(unlocked, ['1', '2', '3']);
        expect(completed, ['1', '2']);
        expect(current, '3');
      });
    });

    group('export and import', () {
      test('should export save data as JSON string', () async {
        const saveData = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 5,
          xp: 200,
          unlockedNodes: ['1', '2'],
          completedNodes: ['1'],
          currentNode: '2',
        );

        await saveSystem.saveAll(saveData);
        final exported = await saveSystem.exportSave();

        expect(exported, isNotNull);
        final json = jsonDecode(exported!) as Map<String, dynamic>;
        expect(json['level'], 5);
        expect(json['xp'], 200);
      });

      test('should import save data from JSON string', () async {
        const saveData = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 10,
          xp: 999,
          unlockedNodes: ['1', '2', '3', '4', '5'],
          completedNodes: ['1', '2', '3', '4'],
          currentNode: '5',
        );

        final jsonString = jsonEncode(saveData.toJson());
        final imported = await saveSystem.importSave(jsonString);

        expect(imported, isTrue);

        final loaded = await saveSystem.loadAll();
        expect(loaded.level, 10);
        expect(loaded.xp, 999);
        expect(loaded.unlockedNodes, ['1', '2', '3', '4', '5']);
        expect(loaded.completedNodes, ['1', '2', '3', '4']);
        expect(loaded.currentNode, '5');
      });

      test('should reject invalid import JSON', () async {
        final imported = await saveSystem.importSave('not valid json');
        expect(imported, isFalse);
      });

      test('should return null export when no save exists', () async {
        final exported = await saveSystem.exportSave();
        expect(exported, isNull);
      });
    });

    group('clearAll', () {
      test('should remove all save data', () async {
        // Create some save data
        const saveData = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 5,
          xp: 100,
          unlockedNodes: ['1', '2'],
          completedNodes: ['1'],
          currentNode: '2',
        );
        await saveSystem.saveAll(saveData);

        // Clear everything
        await saveSystem.clearAll();

        // Should return defaults
        final loaded = await saveSystem.loadAll();
        expect(loaded.level, 1);
        expect(loaded.xp, 0);
        expect(loaded.unlockedNodes, ['1']);
        expect(loaded.completedNodes, isEmpty);
        expect(loaded.currentNode, '1');

        // Legacy API should also return defaults
        final level = await saveSystem.loadLevel();
        final xp = await saveSystem.loadXp();
        expect(level, 1);
        expect(xp, 0);
      });

      test('should remove backup data', () async {
        // Create save with backup
        const saveData = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 5,
          xp: 100,
          unlockedNodes: ['1', '2'],
          completedNodes: ['1'],
          currentNode: '2',
        );
        await saveSystem.saveAll(saveData);

        const newSave = SaveData(
          hasSeenCameraPermission: false,
        version: 1,
          level: 10,
          xp: 500,
          unlockedNodes: ['1', '2', '3'],
          completedNodes: ['1', '2'],
          currentNode: '3',
        );
        await saveSystem.saveAll(newSave); // Creates backup

        await saveSystem.clearAll();

        // Verify backup is gone
        final prefs = await SharedPreferences.getInstance();
        final backup = prefs.getString('save_data_backup');
        expect(backup, isNull);
      });
    });
  });
}
