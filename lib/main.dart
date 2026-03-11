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
import 'game/fpv_game.dart';
import 'game/palette.dart';
import 'models/gesture_cursor_controller.dart';
import 'package:fpv_magic/systems/hand_tracking/tracking_service.dart';
import 'package:fpv_magic/systems/hand_tracking/tracking_factory.dart'
    if (dart.library.js_interop) 'package:fpv_magic/systems/hand_tracking/tracking_factory_web.dart';
import 'package:fpv_magic/systems/gesture/gesture_type.dart';
import 'package:fpv_magic/models/player_stats.dart';
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
      title: 'PYROMANCER',
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

  @override
  void initState() {
    super.initState();
    _cursorController = GestureCursorController();
    _initGameSystems();
  }

  Future<void> _initGameSystems() async {
    final saveSystem = SaveSystem();
    playerStats = PlayerStats(saveSystem: saveSystem);
    await playerStats.load();

    trackingService = createTrackingService();
    await trackingService.start();

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
    setState(() => gameState = GameState.tutorial);
  }

  void _goToStory() {
    setState(() => gameState = GameState.story);
  }

  void _startGame() {
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
          if (mounted) {
            setState(() {
              _bigBrotherGameOver = false;
              gameState = GameState.gameOver;
            });
          }
        });
      },
      onBigBrotherGameOver: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _bigBrotherGameOver = true;
              gameState = GameState.gameOver;
            });
          }
        });
      },
      onVictory: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => gameState = GameState.victory);
        });
      },
      onWaveChanged: (wave) {},
      playerStats: playerStats,
      trackingService: trackingService,
    );

    setState(() => gameState = GameState.playing);
  }

  void _restartGame() {
    _bigBrotherGameOver = false;
    game?.restartGame();
    setState(() => gameState = GameState.playing);
  }

  void _backToMenu() {
    setState(() => gameState = GameState.mainMenu);
  }

  void _dismissEpilepsyWarning() {
    setState(() => gameState = GameState.mainMenu);
  }

  @override
  void dispose() {
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
                'PYROMANCER',
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

    // ── Main Menu ────────────────────────────────────────────────────
    if (gameState == GameState.mainMenu) {
      return GestureCursorLayer(
        controller: _cursorController,
        child: MainMenuScreen(
          controller: _cursorController,
          onPlayPressed: _goToTutorial,
          onHowToPlay: _goToTutorial,
          onStory: _goToStory,
        ),
      );
    }

    // ── Story ───────────────────────────────────────────────────────
    if (gameState == GameState.story) {
      return GestureCursorLayer(
        controller: _cursorController,
        child: StoryScreen(
          controller: _cursorController,
          onContinue: _backToMenu,
        ),
      );
    }

    // ── Tutorial ─────────────────────────────────────────────────────
    if (gameState == GameState.tutorial) {
      return GestureCursorLayer(
        controller: _cursorController,
        child: TutorialScreen(
          onComplete: _startGame,
          controller: _cursorController,
        ),
      );
    }

    // ── Game + HUD + optional overlays ───────────────────────────────
    return Stack(
      children: [
        // 1. Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.bgDark, Palette.bgDeep, Palette.bgDeep],
            ),
          ),
        ),

        // 2. The Flame Game
        if (game != null) GameWidget(game: game!),

        // 3. Flutter UI Overlay (HUD)
        ListenableBuilder(
          listenable: playerStats,
          builder: (context, _) {
            return HUD(activeGesture: activeGesture, playerStats: playerStats);
          },
        ),

        // 4. Game Over / Victory overlay — wrapped with gesture cursor layer
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
}
