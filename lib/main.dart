import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'ui/hud.dart';
import 'ui/game_over_screen.dart';
import 'ui/tutorial_screen.dart';
import 'ui/epilepsy_warning_screen.dart';
import 'ui/main_menu_screen.dart';
import 'ui/story_screen.dart';
import 'ui/gesture_cursor_overlay.dart';
import 'ui/map_screen.dart';
import 'models/map_node.dart';
import 'game/fpv_game.dart';
import 'game/palette.dart';
import 'models/gesture_cursor_controller.dart';
import 'package:fpv_magic/systems/hand_tracking/tracking_service.dart';
import 'package:fpv_magic/systems/hand_tracking/tracking_factory.dart'
    if (dart.library.js_interop) 'package:fpv_magic/systems/hand_tracking/tracking_factory_web.dart';
import 'package:fpv_magic/systems/gesture/gesture_type.dart';
import 'package:fpv_magic/models/player_stats.dart';
import 'package:fpv_magic/systems/audio_manager.dart';
import 'package:fpv_magic/systems/save_system.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FpvMagicApp());
}

class FpvMagicApp extends StatelessWidget {
  const FpvMagicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'THE GRID',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Palette.bgDeep),
      home: const Scaffold(body: GameScreen()),
    );
  }
}

enum GameState {
  epilepsyWarning,
  mainMenu,
  story,
  tutorial,
  map,
  playing,
  gameOver,
  victory,
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final PlayerStats playerStats;
  late final TrackingService trackingService;
  late final GestureCursorController _cursorController;
  Ticker? _cursorTicker;
  FpvGame? game;

  bool statsLoaded = false;
  GameState gameState = GameState.epilepsyWarning;
  GestureType activeGesture = GestureType.none;
  bool _bigBrotherGameOver = false;

  void _syncUiMusicForState(GameState state) {
    if (state == GameState.mainMenu || state == GameState.tutorial) {
      AudioManager.playMenuTutorialMusic(volume: 1.0);
    } else {
      AudioManager.stopMenuTutorialMusic();
    }
  }

  void _setGameState(GameState state, {bool? bigBrotherGameOver}) {
    if (!mounted) return;
    setState(() {
      gameState = state;
      if (bigBrotherGameOver != null) {
        _bigBrotherGameOver = bigBrotherGameOver;
      }
    });
    _syncUiMusicForState(state);
  }

  @override
  void initState() {
    super.initState();
    _cursorController = GestureCursorController();
    _initGameSystems();
  }

  Future<void> _initGameSystems() async {
    final saveSystem = SaveSystem();
    playerStats = PlayerStats(saveSystem: saveSystem);

    trackingService = createTrackingService();

    // Start player stats loading and tracking service in parallel.
    // Don't block on trackingService — it loads the ML model which is slow.
    // The user sees the epilepsy warning + menu while it initializes.
    await Future.wait([playerStats.load(), AudioManager.init()]);
    trackingService.start(); // Fire-and-forget — runs in background

    // Start the cursor ticker — drives gesture-cursor on UI screens.
    Duration? prevElapsed;
    _cursorTicker = createTicker((elapsed) {
      if (!mounted) return;
      final dt = prevElapsed != null
          ? (elapsed - prevElapsed!).inMicroseconds / 1_000_000.0
          : 0.016;
      prevElapsed = elapsed;
      _cursorController.update(trackingService, dt);
    });
    _cursorTicker!.start();

    if (mounted) setState(() => statsLoaded = true);
  }

  void _goToTutorial() {
    _setGameState(GameState.tutorial);
  }

  void _goToStory() {
    _setGameState(GameState.story);
  }

  void _goToMap() {
    _setGameState(GameState.map);
  }

  void _onNodeSelected(MapNode node) {
    // Stop old game instance to cancel any stale timers
    game?.stopGame();

    playerStats.setCurrentNode(node.id);
    _initGameInstance();
    game!.startLevel(node.startWave, node.endWave);

    _setGameState(GameState.playing);
  }

  void _initGameInstance() {
    game = FpvGame(
      onGestureDetected: (gesture) {
        if (activeGesture != gesture && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => activeGesture = gesture);
          });
        }
      },
      onGameOver: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setGameState(GameState.gameOver, bigBrotherGameOver: false);
        });
      },
      onBigBrotherGameOver: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setGameState(GameState.gameOver, bigBrotherGameOver: true);
        });
      },
      onVictory: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setGameState(GameState.victory);
        });
      },
      onLevelComplete: (wave) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Unlocks new nodes based on current node's graph
            final currentNode = MapGraph.nodes[playerStats.currentNodeId];
            if (currentNode != null) {
              playerStats.completeNode(currentNode.id, currentNode.unlocks);
              // Final node has no unlocks — victory!
              if (currentNode.unlocks.isEmpty) {
                _setGameState(GameState.victory);
                return;
              }
            }
            _goToMap();
          }
        });
      },
      onWaveChanged: (wave) {},
      playerStats: playerStats,
      trackingService: trackingService,
    );
  }

  void _restartGame() {
    _bigBrotherGameOver = false;
    // Go back to map — player keeps map progress, just retries from same node
    _goToMap();
  }

  void _backToMenu() {
    _setGameState(GameState.mainMenu);
  }

  void _dismissEpilepsyWarning() {
    _setGameState(GameState.mainMenu);
  }

  @override
  void dispose() {
    AudioManager.stopMenuTutorialMusic();
    _cursorTicker?.stop();
    _cursorController.dispose();
    trackingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!statsLoaded) {
      return Container(
        color: Palette.bgDeep,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Palette.fireGold),
              SizedBox(height: 24),
              Text(
                'THE GRID',
                style: TextStyle(
                  color: Palette.fireGold,
                  fontFamily: 'monospace',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'LOADING...',
                style: TextStyle(
                  color: Palette.uiGrey,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Epilepsy Warning ─────────────────────────────────────────────
    if (gameState == GameState.epilepsyWarning) {
      return EpilepsyWarningScreen(onComplete: _dismissEpilepsyWarning);
    }

    // Build the current screen widget based on state
    Widget screenContent;

    if (gameState == GameState.mainMenu) {
      screenContent = GestureCursorLayer(
        controller: _cursorController,
        child: MainMenuScreen(
          controller: _cursorController,
          onPlayPressed: _goToTutorial,
          onHowToPlay: _goToTutorial,
          onStory: _goToStory,
        ),
      );
    } else if (gameState == GameState.story) {
      screenContent = GestureCursorLayer(
        controller: _cursorController,
        child: StoryScreen(
          controller: _cursorController,
          onContinue: _backToMenu,
        ),
      );
    } else if (gameState == GameState.tutorial) {
      screenContent = GestureCursorLayer(
        controller: _cursorController,
        child: TutorialScreen(
          onComplete: () {
            _goToMap();
          },
          onBackToMenu: _backToMenu,
          controller: _cursorController,
        ),
      );
    } else if (gameState == GameState.map) {
      screenContent = GestureCursorLayer(
        controller: _cursorController,
        child: MapScreen(
          playerStats: playerStats,
          cursorController: _cursorController,
          onNodeSelected: _onNodeSelected,
          onBackToMenu: _backToMenu,
        ),
      );
    } else {
      // ── Game + HUD + optional overlays ─────────────────────────────
      screenContent = Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Palette.bgDark, Palette.bgDeep, Palette.bgDeep],
              ),
            ),
          ),
          if (game != null) GameWidget(game: game!),
          ListenableBuilder(
            listenable: playerStats,
            builder: (context, _) {
              return HUD(
                activeGesture: activeGesture,
                playerStats: playerStats,
              );
            },
          ),
          if (gameState == GameState.gameOver || gameState == GameState.victory)
            GestureCursorLayer(
              controller: _cursorController,
              child: GameOverScreen(
                controller: _cursorController,
                isVictory: gameState == GameState.victory,
                isBigBrotherGameOver: _bigBrotherGameOver,
                score: playerStats.score,
                kills: playerStats.killCount,
                wave: playerStats.currentWave,
                onRestart: _restartGame,
                onMainMenu: _backToMenu,
              ),
            ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return _CyberGlitchTransition(animation: animation, child: child);
      },
      child: KeyedSubtree(key: ValueKey(gameState), child: screenContent),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Cyberpunk Glitch Transition
// ══════════════════════════════════════════════════════════════════════════
class _CyberGlitchTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _CyberGlitchTransition({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        // Phase 1 (0-0.3): glitch bars appear, content slides in from offset
        // Phase 2 (0.3-1.0): content fades in, glitch bars fade out
        final opacity = t < 0.15 ? t / 0.15 : 1.0;
        final slideOffset = (1.0 - t) * 12.0;

        // RGB split offset for the glitch feel
        final glitchOffset = t < 0.4 ? (1.0 - t / 0.4) * 6.0 : 0.0;

        return Stack(
          children: [
            // Main content with slight vertical slide
            Transform.translate(
              offset: Offset(0, slideOffset),
              child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
            ),

            // Glitch bars overlay (horizontal colored bars that fade out)
            if (t < 0.5)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GlitchBarsPainter(
                      progress: t,
                      offset: glitchOffset,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GlitchBarsPainter extends CustomPainter {
  final double progress;
  final double offset;

  _GlitchBarsPainter({required this.progress, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 0.5) return;

    final alpha = ((0.5 - progress) / 0.5).clamp(0.0, 1.0);
    final rng = Random(42); // deterministic random for stable bars

    for (int i = 0; i < 8; i++) {
      final y = rng.nextDouble() * size.height;
      final h = 2.0 + rng.nextDouble() * 6.0;
      final xOff = (rng.nextDouble() - 0.5) * offset * 20;

      // Cyan bar
      canvas.drawRect(
        Rect.fromLTWH(xOff, y, size.width, h),
        Paint()..color = Colors.cyanAccent.withValues(alpha: alpha * 0.3),
      );

      // Pink bar offset
      canvas.drawRect(
        Rect.fromLTWH(-xOff * 0.7, y + h + 1, size.width, h * 0.6),
        Paint()..color = Colors.pinkAccent.withValues(alpha: alpha * 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchBarsPainter old) =>
      old.progress != progress || old.offset != offset;
}
