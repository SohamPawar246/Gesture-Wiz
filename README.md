# PYROMANCER

> **Snap your fingers. Defeat them all.**

A first-person wave-based dungeon spell-combat game controlled entirely by real-time hand gestures from your webcam. No controllers. No keyboard. Just your hands.

---

## What is it?

You stand at the end of a stone dungeon corridor. Enemies spawn at the far end and march toward you. You cast spells and block attacks using distinct hand poses detected by MediaPipe in real time.

Survive 10 chambers to win. Let enemies reach you and your HP drops. Run out of HP and the darkness consumes you.

---

## Gestures / Controls

| Hand Pose           | Spell               | Effect                                    |
| ------------------- | ------------------- | ----------------------------------------- |
| ☝ Index finger only | **Fire Bolt**       | Homing projectile at nearest enemy        |
| ✊ Fist             | **Force Push**      | AoE burst around your hand                |
| 🖐 Open palm        | **Ward Shield**     | Sustained block — deflects nearby enemies |
| ✌ V sign            | **Overwatch Pulse** | Hits ALL enemies on screen                |
| 👌 Pinch            | **Grab**            | Close-range micro-damage                  |

**Head movement** also drives a parallax effect — lean left/right/up/down and the environment shifts with you.

**Mouse fallback (desktop, no webcam):** move mouse to aim, left-click = Fist, right-click = Fire Bolt.

---

## Enemies

| Name              | HP  | Speed  | Damage | Points |
| ----------------- | --- | ------ | ------ | ------ |
| Skull Spirit      | 1   | Medium | 10     | 100    |
| Evil Eye          | 1   | Fast   | 5      | 150    |
| Toxic Slime       | 2   | Slow   | 15     | 200    |
| Armored Knight    | 3   | Slow   | 25     | 500    |
| Flame Lord (boss) | 10  | Slow   | 50     | 2000   |

Wave 10 spawns the Flame Lord boss alongside regular enemies.

---

## Running the Game

### Web (recommended)

```bash
flutter build web
# serve build/web with any static server
flutter run -d chrome
```

The browser will request webcam access. MediaPipe runs entirely in-browser via WASM — no server needed.

### Desktop (Windows)

```bash
# Terminal 1 — start the Python hand tracker
cd tracker
pip install -r requirements.txt
python tracker.py

# Terminal 2 — run the Flutter app
flutter run -d windows
```

The Python tracker sends UDP packets to `127.0.0.1:5005`. The Flutter app connects automatically.

---

## Project Structure

```
lib/
├── main.dart                          # App entry, screen state machine
├── game/
│   ├── fpv_game.dart                  # Core Flame game loop
│   ├── palette.dart                   # Global colour constants
│   └── components/                    # All visual game objects
│       ├── enemy.dart                 # 5 enemy types, fully procedural art
│       ├── virtual_hand.dart          # Rendered hand from landmarks
│       ├── dungeon_background.dart    # FPV corridor with parallax
│       ├── projectile.dart            # Homing spell projectiles
│       └── ...                        # VFX: shake, flash, splat, particles
├── systems/
│   ├── action_system.dart             # Gesture → combat action dispatch
│   ├── wave_manager.dart              # 10-wave enemy scheduler
│   ├── audio_manager.dart             # SFX playback (flame_audio)
│   ├── save_system.dart               # Level + XP via SharedPreferences
│   ├── gesture/
│   │   ├── rule_based_recognizer.dart # Landmark geometry → GestureType
│   │   └── gesture_state_machine.dart # Debounce, velocity gate, one-shot
│   └── hand_tracking/
│       ├── tracking_service.dart      # Abstract interface
│       ├── web_tracking_service.dart  # JS interop → MediaPipe WASM
│       ├── udp_service.dart           # UDP socket → Python tracker
│       ├── tracking_factory.dart      # Desktop factory
│       ├── tracking_factory_web.dart  # Web factory (conditional import)
│       └── landmark_model.dart        # Landmark(x,y,z) + smoothing
├── models/
│   ├── player_stats.dart              # HP/mana/XP/score (ChangeNotifier)
│   ├── spell.dart                     # GameAction + ActionType enums
│   ├── enemy_type.dart                # EnemyData table
│   └── gesture_cursor_controller.dart # UI cursor driven by hand position
└── ui/
    ├── main_menu_screen.dart
    ├── tutorial_screen.dart
    ├── game_over_screen.dart
    ├── hud.dart                        # Live HP/mana/wave overlay
    └── gesture_cursor_overlay.dart     # Hands-free dwell-tap UI navigation

web/
├── index.html                          # Flutter shell + hidden video element
└── mediapipe_bridge.js                 # MediaPipe WASM driver + live preview

tracker/
├── tracker.py                          # Python/OpenCV UDP broadcaster
└── requirements.txt
```

---

## Architecture

### Hand tracking data flow

```
Webcam
 └─ [Web]  mediapipe_bridge.js  →  window._mpHandResults / _mpFaceResult
           WebTrackingService.poll()  ←  @JS() interop each frame

 └─ [Desktop]  tracker.py  →  UDP:5005
               UdpService  (RawDatagramSocket, JSON decode)

Both paths → List<Landmark>(21 pts, normalised 0–1) per hand
```

### Gesture recognition pipeline (per hand, per frame)

```
Landmarks
  → RuleBasedRecognizer   (finger extension ratios, palm geometry)
  → GestureStateMachine   (velocity gate, debounce, one-shot fire)
  → ActionSystem          (cooldown management, GameAction dispatch)
  → FpvGame._executeAction()
```

### UI gesture navigation

```
GestureCursorController  (ChangeNotifier, ticked every frame)
  → GestureCursorLayer   (Stack overlay on any screen)
  → GestureTapTarget     (wraps buttons, 1.2s dwell = tap)
```

### Face parallax (UI screens)

All three UI screens (`MainMenu`, `Tutorial`, `GameOver`) use:

```dart
AnimatedBuilder(animation: ctrl)  // subscribes to ~60fps notifyListeners()
  → Transform.translate(
      offset: Offset((ctrl.faceX - 0.5) * 65, (ctrl.faceY - 0.5) * 35),
      child: body,  // entire screen Stack
    )
```

### Platform selection

```dart
// main.dart
import 'tracking_factory.dart'
    if (dart.library.js_interop) 'tracking_factory_web.dart';
```

One conditional import selects `UdpService` (desktop) or `WebTrackingService` (web) at compile time. No `dart:io` code reaches the web build.

---

## Key Technical Details

- **No sprite assets.** Every enemy, the dungeon, the hand, all projectiles and effects are drawn procedurally via Flutter/Flame `Canvas` API.
- **Audio** — 7 WAV files generated programmatically by `generate_sounds.py` using pure Python `wave` + `math`. Fully reproducible.
- **Gesture debounce** — gestures require 3 consecutive matching frames to confirm. A velocity gate suppresses recognition for 150ms after fast hand movement. Instant gestures (point/fist/v-sign) fire once then require a neutral reset; sustained gestures (open palm, pinch) return every frame.
- **Exponential smoothing** — landmark positions are smoothed at `alpha = 0.55` in Dart (`WebTrackingService` / `UdpService`) to reduce jitter without lag.
- **Combo system** — kills within a 2-second window stack a multiplier (1×–4×) with streak announcements: DOUBLE KILL → TRIPLE KILL → KILLING SPREE → UNSTOPPABLE → ALL-SEEING.
- **Progression** — level and XP persist between sessions via `SharedPreferences`. Each level increases max HP (+10), mana (+20), and mana regen (+1/s). Score and kills are session-only.

---

## Dependencies

```yaml
flame: ^1.35.1 # Game loop, components, camera
flame_audio: any # Audio playback
shared_preferences: any # Save system
```

Python tracker: `opencv-python`, `mediapipe==0.10.14`

---

## Regenerating Audio Assets

```bash
python generate_sounds.py
# writes assets/audio/*.wav
```
