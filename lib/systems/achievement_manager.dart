import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/palette.dart';
import '../ui/glitch_text.dart';
import 'audio_manager.dart';

class Achievement {
  final String id;
  final String title;
  final String description;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
  });
}

class AchievementManager {
  static final AchievementManager instance = AchievementManager._internal();
  AchievementManager._internal();

  static const List<Achievement> allAchievements = [
    Achievement(id: 'first_blood', title: 'First Blood', description: 'Kill an enemy.'),
    Achievement(id: 'ghost_machine', title: 'Ghost in the Machine', description: 'Clear a node with 0% Surveillance.'),
    Achievement(id: 'archmage', title: 'Archmage', description: 'Unlock a Level 3 Spell upgrade.'),
    Achievement(id: 'untouchable', title: 'Untouchable', description: 'Clear a node without taking damage.'),
    Achievement(id: 'combo_breaker', title: 'Combo Breaker', description: 'Reach a 15x kill multiplier.'),
    Achievement(id: 'glitch_matrix', title: 'Glitch in the Matrix', description: 'Survive a Server Zero color-invert.'),
    Achievement(id: 'hoarder', title: 'Hoarder', description: 'Collect 5 Artifact drops in a single node.'),
    Achievement(id: 'rebel_leader', title: 'Rebel Leader', description: 'Defeat the Phase 1 Boss.'),
    Achievement(id: 'pacifist', title: 'Pacifist', description: 'Survive a node using only Shield and Heal.'),
    Achievement(id: 'architect', title: 'The Architect', description: 'Discover and complete a Secret Bonus Room.'),
  ];

  final Set<String> _unlockedIds = {};
  bool _initialized = false;
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('unlocked_achievements') ?? [];
    _unlockedIds.addAll(data);
    _initialized = true;
  }

  bool isUnlocked(String id) => _unlockedIds.contains(id);

  List<Achievement> getUnlocked() {
    return allAchievements.where((a) => _unlockedIds.contains(a.id)).toList();
  }

  Future<void> unlock(String id) async {
    if (!_initialized || _unlockedIds.contains(id)) return;
    
    final achievement = allAchievements.where((a) => a.id == id).firstOrNull;
    if (achievement == null) return;

    _unlockedIds.add(id);
    
    // Save
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('unlocked_achievements', _unlockedIds.toList());

    if (kDebugMode) {
      debugPrint('Unlocked Achievement: ${achievement.title}');
    }

    _showUnlockPopup(achievement);
  }

  void _showUnlockPopup(Achievement achievement) {
    if (navigatorKey == null || navigatorKey!.currentContext == null) return;
    AudioManager.playSfx('pickup.wav'); // Reuse a nice beep sound

    final overlayState = navigatorKey!.currentState!.overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: SafeArea(
            child: _AchievementToast(
              achievement: achievement,
              onDismiss: () => entry.remove(),
            ),
          ),
        );
      },
    );

    overlayState.insert(entry);
    
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  // Clear for testing
  Future<void> clearAll() async {
    _unlockedIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('unlocked_achievements');
  }
}

class _AchievementToast extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismiss;

  const _AchievementToast({
    required this.achievement,
    required this.onDismiss,
  });

  @override
  State<_AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<_AchievementToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _slide = Tween<Offset>(begin: const Offset(0, -1.0), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1B0F),
              border: Border.all(color: Palette.fireGold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Palette.fireGold.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Palette.fireGold, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ACHIEVEMENT UNLOCKED',
                      style: TextStyle(
                        color: Color(0xFF88CC88),
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GlitchText(
                      text: widget.achievement.title,
                      style: const TextStyle(
                        color: Palette.fireGold,
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                      glitchIntensity: 0.3,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
