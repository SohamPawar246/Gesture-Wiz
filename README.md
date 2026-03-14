# THE EYE PROTOCOL

> **"Snap your fingers. Resist them all."**

A first-person wave-based spell-combat game controlled entirely by real-time hand gestures from your webcam. No controllers. No keyboard. Just your hands — and Big Brother watching every move.

Built with Flutter + Flame. All art is procedurally generated — zero sprite assets.

---

## The Story

**Year 2084.** The Ministry of Truth has abolished the written word. Big Brother monitors every screen, every camera, every breath. Books are ashes. Free thought is treason. But a resistance survives — channeling forbidden hand gestures through the Ministry's own surveillance cameras to cast spells that shatter its digital constructs.

You are one of them. Stay calm, fight smart, and don't let Big Brother notice.

---

## Gameplay

You stand at the end of a procedurally-drawn dungeon corridor. Enemies spawn at the far end and march toward you. Cast spells using hand gestures detected by your webcam in real time. Survive all 24 waves across 9 sectors to reach Server Zero and bring down the system.

**But there's a catch:** Big Brother is watching. Move too erratically or spam spells too fast and the surveillance detection bar rises. Stay in the red zone for 5 seconds and it's game over — not from enemies, but from the system itself.

---

## Gestures / Controls

| Hand Pose           | Spell               | Mana | Cooldown | Effect                                    |
| ------------------- | ------------------- | ---- | -------- | ----------------------------------------- |
| ☝ Index finger only | **Fire Bolt**       | 8    | 0.4s     | Homing projectile at nearest enemy        |
| ✊ Fist             | **Force Push**      | 15   | 0.8s     | AoE burst pushing enemies back            |
| 🖐 Open palm        | **Ward Shield**     | 3/s  | —        | Sustained block — deflects nearby enemies |
| 👌 Pinch            | **Telekinesis**     | 5/s  | —        | Sustained close-range damage-over-time    |
| ✌ V sign            | **Overwatch Pulse** | 40   | 8.0s     | Ultimate — hits ALL enemies on screen     |

**Head movement** drives a parallax effect on menus — lean left/right/up/down and the UI shifts with you. Sensitivity is configurable from subtle to ultra-reactive.

**Mouse fallback (desktop, no webcam):** move mouse to aim, left-click = Fist, right-click = Fire Bolt.

---

## Big Brother Surveillance

A detection bar sits in the webcam overlay, color-coded green → yellow → red:

- **Green (0–30%):** You're under the radar. Decays steadily.
- **Yellow (30–62%):** Big Brother is suspicious. Slow down.
- **Red (62–100%):** Full alert. Stay here for 5 continuous seconds = game over.

**What raises detection:**

- Rapid spell-casting (actions within a 2.8s window stack multiplicatively)
- Erratic hand movement (high wrist velocity filtered through a dual-rate EMA)

**What lowers detection:**

- Staying calm — minimal movement and infrequent casting
- Dropping below yellow accelerates decay

The detection level is pushed to JavaScript so the webcam video overlay's bounding box changes color in real time.

---

## Campaign Map — THE GRID

The game uses a branching node-based campaign map with 9 sectors across 6 tiers:

```
                    [SECTOR ALPHA]           Tier 1 — Waves 1-3
                     /          \
              [NEON BLVD]    [DARK ALLEY]    Tier 2 — Waves 4-9
                  |              |
            [CORP PLAZA]   [UNDERGROUND]     Tier 3 — Waves 10-13
                  \           /  \
               [SYS-MAIN]  [THE HUB]        Tier 4 — Waves 14-17
                      \      /
                    [CORE FRAME]             Tier 5 — Waves 18-21
                        |
                   [SERVER ZERO]             Tier 6 — Waves 22-24 (Final)
```

Completing a sector unlocks its connected successors. The graph branches at tiers 2–3 and converges at tier 5, offering path choices through the campaign. Progress persists across sessions.

---

## Enemies

| Name              | HP  | Speed  | Damage | Points |
| ----------------- | --- | ------ | ------ | ------ |
| Skull Spirit      | 1   | Medium | 10     | 100    |
| Evil Eye          | 1   | Fast   | 5      | 150    |
| Toxic Slime       | 2   | Slow   | 15     | 200    |
| Armored Knight    | 3   | Slow   | 25     | 500    |
| Flame Lord (boss) | 10  | Slow   | 50     | 2000   |

---

## Settings

Accessible from the main menu via the SETTINGS button. All settings persist across sessions.

| Setting          | Range               | Effect                                                       |
| ---------------- | ------------------- | ------------------------------------------------------------ |
| Hand Sensitivity | Smooth ↔ Snappy     | Controls cursor smoothing alpha (0.30–0.95)                  |
| Face Sensitivity | Default ↔ Ultra Max | Face tracking alpha (0.55–0.92) and parallax scale (1×–4.6×) |
| Resolution       | Crisp ↔ Retro       | Pixelation post-processing (1× native to 4× downscale)       |
| Mute BGM         | Toggle              | Pauses/resumes background music                              |
| Mute All         | Toggle              | Mutes background music and all sound effects                 |

The settings panel uses segmented bar controls compatible with both mouse and gesture-cursor (dwell-tap) interaction.

---

## Game Flow

```
Epilepsy Warning (4.5s)
    ↓
Main Menu ←──────────────────┐
    ├── Story (optional lore) ──┘
    ├── Settings (overlay)
    ↓
Tutorial
    ↓
Map (select sector) ←───────┐
    ↓                        │
Gameplay (waves) ────────────┤ (sector complete → unlock next)
    ↓                        │
Game Over / Victory ─────────┘ (restart → map, or back to menu)
```

Screen transitions use a cyberpunk glitch effect with RGB chromatic aberration bars.

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
├── main.dart                          # App entry, screen state machine, settings wiring
├── game/
│   ├── fpv_game.dart                  # Core Flame game loop + surveillance integration
│   ├── palette.dart                   # Global colour constants
│   └── components/                    # All visual game objects
│       ├── enemy.dart                 # 5 enemy types, fully procedural art
│       ├── virtual_hand.dart          # Rendered hand from landmarks
│       ├── dungeon_background.dart    # FPV corridor with parallax
│       ├── projectile.dart            # Homing spell projectiles
│       └── ...                        # VFX: shake, flash, splat, particles
├── systems/
│   ├── action_system.dart             # Gesture → combat action dispatch
│   ├── wave_manager.dart              # Wave enemy scheduler (24 waves)
│   ├── surveillance_system.dart       # Big Brother detection meter
│   ├── audio_manager.dart             # SFX + BGM with mute support
│   ├── save_system.dart               # Level + XP via SharedPreferences
│   ├── settings_manager.dart          # User settings persistence + ChangeNotifier
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
│   ├── map_node.dart                  # 9-node campaign graph definition
│   ├── spell.dart                     # GameAction + ActionType enums
│   ├── enemy_type.dart                # EnemyData table
│   └── gesture_cursor_controller.dart # UI cursor driven by hand + face position
└── ui/
    ├── main_menu_screen.dart          # Animated menu with fire particles
    ├── tutorial_screen.dart           # Gesture tutorial walkthrough
    ├── game_over_screen.dart          # Death / Big Brother game over / victory
    ├── map_screen.dart                # Pannable cyberpunk node-selection map
    ├── story_screen.dart              # Lore with typewriter text reveal
    ├── epilepsy_warning_screen.dart   # Timed photosensitivity warning
    ├── settings_panel.dart            # Settings modal overlay
    ├── pixelation_wrapper.dart        # Post-processing retro resolution effect
    ├── glitch_text.dart               # Cyberpunk RGB-shift text corruption
    ├── hud.dart                       # Live HP/mana/wave overlay
    └── gesture_cursor_overlay.dart    # Hands-free dwell-tap UI navigation

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
  → RuleBasedRecognizer   (finger extension ratios, palm geometry, hysteresis)
  → GestureStateMachine   (debounce, velocity gate, one-shot fire, rest gate)
  → ActionSystem          (cooldown management, GameAction dispatch)
  → FpvGame._executeAction()
  → SurveillanceSystem.onActionFired()  (raises Big Brother detection)
```

### UI gesture navigation

```
GestureCursorController  (ChangeNotifier, ticked every frame)
  → GestureCursorLayer   (Stack overlay on any screen)
  → GestureTapTarget     (wraps buttons, 1.2s dwell = tap, pinch = instant)
```

### Face parallax (UI screens)

All three UI screens (`MainMenu`, `Tutorial`, `GameOver`) use configurable parallax:

```dart
Transform.translate(
  offset: Offset(
    (ctrl.faceX - 0.5) * ctrl.parallaxH,   // default 65px, up to ~300px
    (ctrl.faceY - 0.5) * ctrl.parallaxV,   // default 35px, up to ~161px
  ),
  child: body,
)
```

Parallax multipliers are driven by the Face Sensitivity setting.

### Platform selection

```dart
import 'tracking_factory.dart'
    if (dart.library.js_interop) 'tracking_factory_web.dart';
```

One conditional import selects `UdpService` (desktop) or `WebTrackingService` (web) at compile time. No `dart:io` code reaches the web build.

---

## Key Technical Details

- **No sprite assets.** Every enemy, the dungeon, the hand, all projectiles and effects are drawn procedurally via Flutter/Flame `Canvas` API.
- **Audio** — WAV files generated programmatically by `generate_sounds.py` using pure Python `wave` + `math`. Two BGM tracks for menu and map. Mute controls use `FlameAudio.bgm.pause()/resume()` to preserve playback position.
- **Gesture debounce** — gestures require confirmation frames via the state machine. A rest gate suppresses instant gestures until a neutral pose is held. Sustained gestures (shield, grab) bypass the rest gate.
- **Exponential smoothing** — hand landmarks use velocity-adaptive smoothing (`alpha 0.30–0.92` based on movement speed). Face uses fixed `alpha 0.65` in the tracking service + configurable `alpha 0.55–0.92` in the controller.
- **Combo system** — kills within a 2-second window stack a multiplier (1×–4×) with streak announcements: DOUBLE KILL → TRIPLE KILL → KILLING SPREE → UNSTOPPABLE → ALL-SEEING.
- **Progression** — level, XP, and map progress persist between sessions via `SharedPreferences`. Each level increases max HP (+10), mana (+20), and mana regen (+1/s).
- **Pixelation effect** — captures the widget tree via `RepaintBoundary.toImage()` at reduced pixel ratio, displays with `FilterQuality.none` for nearest-neighbor upscaling. Frame capture is scheduled via `addPostFrameCallback` to avoid layout conflicts.
- **Surveillance JS bridge** — detection level is written to `window._bbDetectionLevel` each frame so the webcam overlay (in `mediapipe_bridge.js`) can colorize the face/hand bounding boxes in sync with gameplay.

---

## Dependencies

```yaml
flame: ^1.35.1 # Game loop, components, camera
flame_audio: any # Audio playback (BGM + SFX)
shared_preferences: any # Save system + settings persistence
```

Python tracker: `opencv-python`, `mediapipe==0.10.14`

---

## Regenerating Audio Assets

```bash
python generate_sounds.py
# writes assets/audio/*.wav
```
