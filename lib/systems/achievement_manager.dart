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
  final IconData icon;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.icon = Icons.emoji_events,
  });
}

class AchievementManager {
  static final AchievementManager instance = AchievementManager._internal();
  AchievementManager._internal();

  /// Full 20-achievement roster — cyberpunk surveillance narrative.
  static const List<Achievement> allAchievements = [
    // ── Combat milestones ─────────────────────────────────────────
    Achievement(
      id: 'first_breach',
      title: 'FIRST BREACH',
      description: 'Eliminate your first target.',
      icon: Icons.close,
    ),
    Achievement(
      id: 'executioner',
      title: 'EXECUTIONER',
      description: 'Eliminate 100 enemies.',
      icon: Icons.repeat,
    ),
    Achievement(
      id: 'overflow',
      title: 'OVERFLOW',
      description: 'Reach a 15× kill streak.',
      icon: Icons.bolt,
    ),
    Achievement(
      id: 'overkill',
      title: 'OVERKILL',
      description: 'Deal 500+ damage in a single hit.',
      icon: Icons.local_fire_department,
    ),
    Achievement(
      id: 'untouchable',
      title: 'UNTOUCHABLE',
      description: 'Clear a node without taking any damage.',
      icon: Icons.shield,
    ),

    // ── Stealth / surveillance ────────────────────────────────────
    Achievement(
      id: 'ghost_protocol',
      title: 'GHOST PROTOCOL',
      description: 'Clear a node at 0% surveillance.',
      icon: Icons.visibility_off,
    ),
    Achievement(
      id: 'static',
      title: 'STATIC',
      description: 'Survive a Server Zero glitch storm.',
      icon: Icons.blur_on,
    ),
    Achievement(
      id: 'pacifist',
      title: 'PACIFIST',
      description: 'Survive a node using only Firewall and Sys Restore.',
      icon: Icons.favorite_border,
    ),

    // ── Spell mastery ─────────────────────────────────────────────
    Achievement(
      id: 'architect',
      title: 'ARCHITECT',
      description: 'Unlock a Level 3 spell upgrade.',
      icon: Icons.memory,
    ),
    Achievement(
      id: 'firewall_master',
      title: 'FIREWALL MASTER',
      description: 'Block 50 incoming attacks.',
      icon: Icons.security,
    ),
    Achievement(
      id: 'zero_day_exe',
      title: 'ZERO DAY EXE',
      description: 'Fire Zero Day 10 times in one run.',
      icon: Icons.radio_button_checked,
    ),

    // ── Collection ────────────────────────────────────────────────
    Achievement(
      id: 'hoarder',
      title: 'HOARDER',
      description: 'Collect 5 artifact drops in a single node.',
      icon: Icons.inventory_2,
    ),
    Achievement(
      id: 'data_miner',
      title: 'DATA MINER',
      description: 'Collect 50 total artifacts across the campaign.',
      icon: Icons.storage,
    ),

    // ── Progression ───────────────────────────────────────────────
    Achievement(
      id: 'survivor',
      title: 'SURVIVOR',
      description: 'Complete 10 combat waves.',
      icon: Icons.favorite,
    ),
    Achievement(
      id: 'revolutionary',
      title: 'REVOLUTIONARY',
      description: 'Defeat the first sector boss.',
      icon: Icons.star,
    ),
    Achievement(
      id: 'speedrunner',
      title: 'SPEEDRUNNER',
      description: 'Clear a node in under 60 seconds.',
      icon: Icons.timer,
    ),
    Achievement(
      id: 'perfectionist',
      title: 'PERFECTIONIST',
      description: 'Complete a full sector without a game over.',
      icon: Icons.verified,
    ),
    Achievement(
      id: 'decryptor',
      title: 'DECRYPTOR',
      description: 'Discover a secret room.',
      icon: Icons.lock_open,
    ),

    // ── Campaign completion ───────────────────────────────────────
    Achievement(
      id: 'liberator',
      title: 'LIBERATOR',
      description: 'Complete the full campaign.',
      icon: Icons.flag,
    ),
    Achievement(
      id: 'true_rebel',
      title: 'TRUE REBEL',
      description: 'Defeat the final overseer.',
      icon: Icons.remove_red_eye,
    ),
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

  List<Achievement> getUnlocked() =>
      allAchievements.where((a) => _unlockedIds.contains(a.id)).toList();

  int get unlockedCount => _unlockedIds.length;
  int get totalCount => allAchievements.length;

  Future<void> unlock(String id) async {
    if (!_initialized || _unlockedIds.contains(id)) return;

    final achievement = allAchievements.where((a) => a.id == id).firstOrNull;
    if (achievement == null) return;

    _unlockedIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('unlocked_achievements', _unlockedIds.toList());

    if (kDebugMode) debugPrint('[ACH] Unlocked: ${achievement.title}');
    _showUnlockPopup(achievement);
  }

  void _showUnlockPopup(Achievement achievement) {
    if (navigatorKey?.currentContext == null) return;
    AudioManager.playSfx('pickup.wav');

    final overlayState = navigatorKey!.currentState!.overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 40,
        left: 0,
        right: 0,
        child: SafeArea(
          child: _AchievementToast(
            achievement: achievement,
            onDismiss: () => entry.remove(),
          ),
        ),
      ),
    );

    overlayState.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> clearAll() async {
    _unlockedIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('unlocked_achievements');
  }
}

// ══════════════════════════════════════════════════════════════════
// Cyberpunk Achievement Toast
// ══════════════════════════════════════════════════════════════════
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

class _AchievementToastState extends State<_AchievementToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
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
              color: Palette.bgPanel.withValues(alpha: 0.95),
              border: Border.all(color: Palette.neonCyan, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Palette.neonCyan.withValues(alpha: 0.3),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Palette.neonCyan.withValues(alpha: 0.1),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with glow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Palette.neonCyan.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Palette.neonCyan.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    widget.achievement.icon,
                    color: Palette.neonCyan,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ACHIEVEMENT UNLOCKED',
                      style: TextStyle(
                        color: Palette.neonCyan.withValues(alpha: 0.65),
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GlitchText(
                      text: widget.achievement.title,
                      style: const TextStyle(
                        color: Palette.dataWhite,
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Palette.neonCyan,
                          ),
                        ],
                      ),
                      glitchIntensity: 0.25,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.achievement.description,
                      style: TextStyle(
                        color: Palette.dataGrey,
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
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
