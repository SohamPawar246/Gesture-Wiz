import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'ui/hud.dart';
import 'ui/game_over_screen.dart';
import 'ui/tutorial_screen.dart';
import 'game/fpv_game.dart';
import 'game/palette.dart';
import 'package:fpv_magic/systems/hand_tracking/udp_service.dart';
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
      title: 'FPV Magic Spellcasting',
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
  late final UdpService udpService;
  FpvGame? game;
  
  bool statsLoaded = false;
  GameState gameState = GameState.tutorial;
  GestureType activeGesture = GestureType.none;
  List<GestureType> currentCombo = [];
  double timeoutProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initGameSystems();
  }

  Future<void> _initGameSystems() async {
    // 1. Load Player Progress
    final saveSystem = SaveSystem();
    playerStats = PlayerStats(saveSystem: saveSystem);
    await playerStats.load();

    // 2. Start UDP Listener for hand tracking
    udpService = UdpService();
    await udpService.start();

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
      onComboChanged: (combo, progress) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              currentCombo = combo;
              timeoutProgress = progress;
            });
          }
        });
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
      udpService: udpService,
    );

    setState(() => gameState = GameState.playing);
  }

  void _restartGame() {
    game?.restartGame();
    setState(() => gameState = GameState.playing);
  }

  @override
  void dispose() {
    udpService.dispose();
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
        // 1. Bottom Layer: Dark teal dungeon background
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
        
        // 2. Middle Layer: The Flame Game
        if (game != null) GameWidget(game: game!),
        
        // 3. Top Layer: The Flutter UI Overlay (HUD)
        ListenableBuilder(
          listenable: playerStats,
          builder: (context, _) {
            return HUD(
              activeGesture: activeGesture,
              currentCombo: currentCombo,
              timeoutProgress: timeoutProgress,
              playerStats: playerStats,
              knownSpells: game?.knownSpells ?? [],
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
