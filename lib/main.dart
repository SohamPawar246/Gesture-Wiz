import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'ui/hud.dart';
import 'ui/game_over_screen.dart';
import 'ui/tutorial_screen.dart';
import 'game/fpv_game.dart';
import 'game/palette.dart';
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
      title: 'THE EYE — Big Brother',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Palette.bgDeep,
      ),
      home: const Scaffold(
        body: GameScreen(),
      ),
    );
  }
}

enum GameState { tutorial, playing, gameOver, victory }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final PlayerStats playerStats;
  late final TrackingService trackingService;
  FpvGame? game;
  
  bool statsLoaded = false;
  GameState gameState = GameState.tutorial;
  GestureType activeGesture = GestureType.none;

  @override
  void initState() {
    super.initState();
    _initGameSystems();
  }

  Future<void> _initGameSystems() async {
    final saveSystem = SaveSystem();
    playerStats = PlayerStats(saveSystem: saveSystem);
    await playerStats.load();

    // Conditional: Web uses MediaPipe JS bridge, Desktop uses UDP
    trackingService = createTrackingService();
    await trackingService.start();

    if (mounted) setState(() => statsLoaded = true);
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
          if (mounted) setState(() => gameState = GameState.gameOver);
        });
      },
      onVictory: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => gameState = GameState.victory);
        });
      },
      onWaveChanged: (wave) {
        // Wave changed — HUD will update via playerStats listener
      },
      playerStats: playerStats,
      trackingService: trackingService,
    );

    setState(() => gameState = GameState.playing);
  }

  void _restartGame() {
    game?.restartGame();
    setState(() => gameState = GameState.playing);
  }

  @override
  void dispose() {
    trackingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!statsLoaded) {
      return Container(
        color: Palette.bgDeep,
        child: const Center(
          child: CircularProgressIndicator(color: Palette.fireGold),
        ),
      );
    }

    // Tutorial screen
    if (gameState == GameState.tutorial) {
      return TutorialScreen(onComplete: _startGame);
    }

    // Game + HUD + optional overlay
    return Stack(
      children: [
        // 1. Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Palette.bgDark,
                Palette.bgDeep,
                Palette.bgDeep,
              ],
            ),
          ),
        ),
        
        // 2. The Flame Game
        if (game != null) GameWidget(game: game!),
        
        // 3. Flutter UI Overlay (HUD)
        ListenableBuilder(
          listenable: playerStats,
          builder: (context, _) {
            return HUD(
              activeGesture: activeGesture,
              playerStats: playerStats,
            );
          }
        ),

        // 4. Game Over / Victory overlay
        if (gameState == GameState.gameOver || gameState == GameState.victory)
          GameOverScreen(
            isVictory: gameState == GameState.victory,
            score: playerStats.score,
            kills: playerStats.killCount,
            wave: playerStats.currentWave,
            onRestart: _restartGame,
          ),
      ],
    );
  }
}
