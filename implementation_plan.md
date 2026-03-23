# THE EYE PROTOCOL — Complete Cyberpunk Overhaul Plan

**Vision**: Transform the game from a game-jam prototype into a polished, cohesive cyberpunk experience that feels like playing inside a neon-drenched dystopian nightmare. Every visual element, sound, and interaction should reinforce the surveillance-state narrative.

**Core Aesthetic Pillars**:

1. **Neon noir** — Deep blacks punctuated by electric cyan, hot magenta, warning amber
2. **Digital decay** — Glitches, data corruption, scan lines, chromatic aberration
3. **Surveillance paranoia** — Watching eyes, scan beams, tracking indicators
4. **Cybernetic minimalism** — Clean geometric shapes, HUD-like overlays, holographic elements

---

## PHASE 1: VISUAL IDENTITY OVERHAUL

### 1.1 New Cyberpunk Color Palette

**File**: `lib/game/palette.dart`

Replace the current teal/amber "Jon Wick" palette with true cyberpunk colors:

```dart
class Palette {
  // === BACKGROUNDS (Deep noir blacks) ===
  static const Color bgVoid       = Color(0xFF030308);   // Pure void
  static const Color bgDeep       = Color(0xFF0A0A12);   // Deep space
  static const Color bgPanel      = Color(0xFF12121A);   // UI panels
  static const Color bgElevated   = Color(0xFF1A1A24);   // Elevated surfaces

  // === PRIMARY NEON (Electric Cyan) ===
  static const Color neonCyan     = Color(0xFF00FFFF);   // Primary accent
  static const Color neonCyanDim  = Color(0xFF00AAAA);   // Dimmed state
  static const Color neonCyanGlow = Color(0xFF00FFFF);   // Glow effects

  // === SECONDARY NEON (Hot Magenta/Pink) ===
  static const Color neonMagenta  = Color(0xFFFF00FF);   // Secondary accent
  static const Color neonPink     = Color(0xFFFF0080);   // Hot pink
  static const Color neonPinkGlow = Color(0xFFFF44AA);   // Pink glow

  // === DANGER/ALERT (Warning Amber/Red) ===
  static const Color alertRed     = Color(0xFFFF0040);   // Critical warning
  static const Color alertAmber   = Color(0xFFFFAA00);   // Caution
  static const Color alertGlow    = Color(0xFFFF2200);   // Danger glow

  // === SYSTEM COLORS ===
  static const Color dataGreen    = Color(0xFF00FF66);   // Success/safe
  static const Color dataBlue     = Color(0xFF0066FF);   // Mana/info
  static const Color dataPurple   = Color(0xFF8800FF);   // Rare/special
  static const Color dataWhite    = Color(0xFFEEEEFF);   // Text/clean UI

  // === EFFECT COLORS ===
  static const Color scanLine     = Color(0x15FFFFFF);   // Scanline overlay
  static const Color hologram     = Color(0xFF00FFCC);   // Holographic tint
  static const Color corruption   = Color(0xFFFF0044);   // Data corruption
}
```

### 1.2 Cyberpunk Background Environment

**File**: `lib/game/components/cyber_corridor.dart` (NEW — replaces dungeon_background.dart)

Transform the dungeon into a cyberpunk surveillance corridor:

- **Digital grid floor** — Glowing cyan grid lines with moving data pulses
- **Holographic walls** — Semi-transparent panels with scrolling code/data
- **Neon strip lighting** — Pink/cyan LED strips along edges pulsing with bass
- **Surveillance cameras** — Robotic camera heads tracking player movement
- **Floating drones** — Background drones with scanning beams
- **Central surveillance eye** — Giant holographic eye at the vanishing point
- **Particle effects** — Digital sparks, data fragments, holographic noise
- **Environmental tells** — When surveillance meter rises, environment goes red

**Key Features**:

```
- Parallax layers responding to head tracking
- "DATA STREAM" vertical lines (like Matrix rain but horizontal/geometric)
- Pulsing floor grid that reacts to spell casting
- Dynamic lighting that shifts with combat intensity
- Holographic warning signs that appear when surveillance is high
```

### 1.3 Enemy Visual Redesign

**File**: `lib/game/components/enemy.dart`

Redesign all enemies to fit cyberpunk aesthetic:

**DRONE (replaces Skull)**

- Floating surveillance drone with single red eye
- Metallic body with glowing energy core
- Propeller/hover effects with cyan particle trails
- Death animation: Sparks, EMP burst, crash

**SENTINEL (replaces Eyeball)**

- Larger surveillance orb with multiple scanning lenses
- Holographic shield ring that rotates
- Laser targeting painter before attack
- Charging glow effect before firing

**GLITCH (replaces Slime)**

- Corrupted data entity — pixelated, unstable form
- Constantly glitching/shifting shape
- Leaves behind "data corruption" puddles (purple/magenta)
- Death: Dissolves into corrupt pixels

**ENFORCER (replaces Knight)**

- Riot control mech with energy shield
- Heavy armor with charging indicator
- Shoulder-mounted warning lights
- Shield reflects projectiles until broken

**OVERSEER (Boss)**

- Massive floating surveillance head
- Multiple eyes that track independently
- Holographic body made of data streams
- Phase transitions with dramatic visual shifts
- Summons holographic minions

### 1.4 Spell Effect Overhaul

**File**: `lib/game/components/spell_effect.dart`

Redesign all spell effects with cyberpunk visuals:

**FIRE BOLT → DATA SPIKE**

- Electric cyan projectile with trailing code fragments
- Hexagonal targeting reticle
- Impact creates "system breach" effect (spreading cracks of light)
- Sound: Electronic zap with bass impact

**FORCE PUSH → EMP BLAST**

- Expanding electromagnetic pulse ring
- Distortion wave (like heat shimmer)
- Affected enemies show "SYSTEM DISRUPTED" holographic text
- Cyan/magenta color shift on expansion

**WARD SHIELD → FIREWALL**

- Hexagonal honeycomb shield pattern
- Rotating defensive symbols/code
- Blocked attacks cause "ACCESS DENIED" flash
- Shield edges glow brighter on successful block

**TELEKINESIS → HACK GRIP**

- Digital tendrils/wires connecting to target
- "CONNECTION ESTABLISHED" indicator
- Target shows "COMPROMISED" status
- Throwing creates arc trails

**OVERWATCH → ZERO DAY**

- Screen-wide electromagnetic storm
- Inverted colors flash
- All enemies show "CRITICAL VULNERABILITY"
- Massive bass drop with screen shake

---

## PHASE 2: UI/UX CYBERPUNK POLISH

### 2.1 HUD Redesign

**File**: `lib/ui/hud.dart`

Complete HUD overhaul for cyberpunk terminal aesthetic:

**Layout**:

```
┌─────────────────────────────────────────────────────────────┐
│ [EYE ICON] SURVEILLANCE: ████████░░ 78%        WAVE 3/5    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐                       ┌──────────────┐   │
│  │ HP ███████░░ │                       │ SCORE: 12450 │   │
│  │ 85/100       │                       │ KILLS: 23    │   │
│  ├──────────────┤                       │ STREAK: 5x   │   │
│  │ MP █████░░░░ │                       └──────────────┘   │
│  │ 55/100       │                                          │
│  └──────────────┘                                          │
│                                                             │
│                    [GAMEPLAY AREA]                          │
│                                                             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│         ▶ DATA SPIKE [READY]  ◆ COOLDOWNS DISPLAY          │
└─────────────────────────────────────────────────────────────┘
```

**Features**:

- Animated corner brackets that pulse on events
- Glitch effects when taking damage
- Color shift to red as HP drops
- "WARNING" overlay at low HP (pulsing border)
- Kill counter that creates satisfying "tick" animation
- Combo multiplier with escalating glow intensity

### 2.2 Main Menu Overhaul

**File**: `lib/ui/main_menu_screen.dart`

Enhance the already-good main menu:

- **Boot sequence** — Fake terminal bootup before menu appears
- **Background** — Animated surveillance feed grid (like CCTV wall)
- **Title treatment** — More dramatic entrance animation
- **Particle system** — Data fragments floating upward
- **Sound design** — Ambient electronic hum, glitch sounds on hover
- **Easter eggs** — Hidden terminal commands if you type

### 2.3 Map Screen Enhancement

**File**: `lib/ui/map_screen.dart`

Make the map feel like a hacker's network overview:

- **Visual style** — Dark network topology view with glowing nodes
- **Node types** — Different shapes/colors for node types (combat, secret, boss)
- **Connection lines** — Animated data flow along completed paths
- **Hover details** — Holographic popup with mission briefing
- **Unlock animations** — Dramatic "ACCESS GRANTED" when path opens
- **Secret nodes** — Flickering/unstable appearance
- **Current position** — Pulsing beacon with "YOU ARE HERE"

### 2.4 Upgrade Screen Polish

**File**: `lib/ui/upgrade_screen.dart`

Transform into a cybernetic augmentation interface:

- **Theme** — Neural implant installation terminal
- **Layout** — Brain/body diagram with augmentation slots
- **Upgrade cards** — Holographic cards that float and rotate
- **Purchase animation** — "INSTALLING..." progress bar with glitch
- **Sound** — Mechanical/electronic upgrade installation sounds
- **Locked items** — Static/corrupted appearance
- **Apex upgrades** — More dramatic presentation (larger, pulsing)

---

## PHASE 3: GAMEPLAY ENHANCEMENT

### 3.1 Enemy Special Attacks (Refined)

**File**: `lib/game/components/enemy.dart` + `lib/game/fpv_game.dart`

**GLITCH — Corruption Zones**

- Leaves digital corruption puddles on screen glass
- Puddles display "MEMORY LEAK" with damage ticks
- Visual: Purple/magenta pixelated zones
- Duration: 5 seconds, fades with dissolve effect
- Player must avoid moving cursor through zones

**SENTINEL — Laser Lock**

- Stops at depth 0.6
- Projects targeting laser for 1.5s (red line to player cursor)
- "TARGET ACQUIRED" warning text
- If player doesn't shield: instant high damage beam
- Beam visual: Thick red laser with bloom effect

**ENFORCER — Breach Protocol**

- Raises energy shield (immune to direct attacks)
- Charges forward with warning lights
- "BREACH IMMINENT" indicator
- Can only be stopped by EMP blast or Zero Day
- Impact deals massive damage + knockback effect

**OVERSEER (Boss) — Multi-Phase**

- _Phase 1_: Summons Drones, basic attacks
- _Phase 2 (<50% HP)_: Activates "LOCKDOWN" — scanning beams sweep screen
- _Phase 3 (<25% HP)_: "PURGE PROTOCOL" — rapid attacks, glitch zones everywhere
- Death: Dramatic shutdown sequence with flickering and explosion

### 3.2 Environmental Hazards Per Sector

**File**: `lib/systems/hazard_controller.dart`

**SECTOR 1: UNDERGROUND (Data Tunnels)**

- _Hazard_: EMP Blackouts — Screen goes dark except for enemy eyes/glows
- _Duration_: 3 seconds
- _Visual_: Flickering lights, emergency red strobes
- _Tell_: Warning klaxon + "POWER FAILURE" text before blackout

**SECTOR 2: NEON BOULEVARD**

- _Hazard_: Scanner Sweeps — Vertical scan beam moves across screen
- _Danger_: Casting while cursor in beam = +30% surveillance
- _Visual_: Semi-transparent cyan beam with "SCANNING" label
- _Strategy_: Time spells between sweeps

**SECTOR 3: SERVER ZERO**

- _Hazard_: Glitch Storms — Severe chromatic aberration + color inversion
- _Duration_: 2-3 seconds
- _Visual_: RGB split, inverted colors, static noise
- _Audio_: Distorted, corrupted sound
- _Warning_: Screen edges start glitching before full storm

### 3.3 Artifact/Loot System

**File**: `lib/game/components/artifact_item.dart`

**Mechanics**:

- 10% drop chance on enemy kill
- Floats toward screen, must grab before it fades (5 seconds)
- Grab prioritizes loot over enemies when overlapping
- Distinct collection animation and sound for each type

**Artifacts**:
| Name | Color | Effect | Visual |
|------|-------|--------|--------|
| DATA CORE | Cyan | Full mana restore | Glowing cube |
| JAMMER | Green | Freeze surveillance 5s | Antenna device |
| OVERCLOCK | Yellow | Free spells for 5s | CPU chip |
| REPAIR KIT | Red | Heal 25% HP | Medical kit |
| RARE: VIRUS | Purple | Double damage 10s | Skull hologram |

**Collection Effects**:

- Satisfying "whoosh" as item is grabbed
- Brief slowdown (100ms)
- Particle burst in item color
- Holographic text "+EFFECT NAME"

### 3.4 Secret Rooms System

**File**: `lib/models/map_node.dart`

**Access Conditions**:

- Secret Room A: Clear any node without taking damage
- Secret Room B: Achieve 10+ kill streak
- Secret Room C: Complete a sector with <20% surveillance

**Secret Room Types**:

- _THE ARCHIVE_: Survival mode, endless drones, massive XP reward
- _THE BLACKSITE_: No attacks allowed, survive with defense only
- _ZERO DAY CACHE_: Boss rush with guaranteed rare artifacts

**Visual Treatment**:

- Nodes appear as corrupted/flickering on map
- "SIGNAL DETECTED" when unlock condition approached
- "DECRYPTING..." animation when access granted
- Unique red/purple color scheme inside

---

## PHASE 4: AUDIO ENHANCEMENT

### 4.1 Sound Design Overhaul

**File**: `lib/systems/audio_manager.dart`

**Ambient Soundscape**:

- Electronic hum/drone baseline
- Random glitch/beep sounds
- Distant surveillance announcements (distorted PA system)
- Heartbeat/bass pulse that syncs with low HP

**Combat Sounds**:

- Data Spike: Electronic zap with bass impact
- EMP Blast: Low frequency pulse wave
- Firewall: Hexagonal "deploy" sound
- Hack Grip: Digital connection/static
- Zero Day: Massive bass drop + distortion

**UI Sounds**:

- Menu hover: Soft blip
- Menu select: Satisfying click + confirmation tone
- Error: Harsh buzz
- Achievement: Triumphant synth chord
- Damage taken: Distorted impact + warning alarm flash

**Music Zones**:

- Menu: Ambient cyberpunk atmosphere
- Combat: Driving synthwave with dynamic intensity
- Boss: Dark aggressive electronic
- Victory: Triumphant but melancholic
- Game Over: Corrupted, dying electronics

### 4.2 Dynamic Audio System

**New File**: `lib/systems/dynamic_audio.dart`

- Music intensity scales with combat activity
- Layers added/removed based on game state
- Low HP triggers filtered/distorted music
- High surveillance creates tense undertone
- Boss phases have distinct music transitions

---

## PHASE 5: POLISH & EFFECTS

### 5.1 Screen Effects System

**File**: `lib/game/components/screen_effects.dart` (NEW)

**Chromatic Aberration**:

- RGB channel separation on damage
- Intensity scales with damage amount
- Subtle persistent effect at low HP

**Scanlines**:

- Animated horizontal scanlines
- Intensity varies with game state
- Billboard-style horizontal scroll

**Vignette**:

- Dynamic vignette that intensifies in combat
- Color shifts to red at low HP
- Pulsing effect during critical states

**Glitch Overlays**:

- Random glitch frames during intense combat
- Screen tear effects
- Block displacement artifacts

### 5.2 Particle Systems

**File**: `lib/game/components/particle_systems.dart` (NEW)

**Ambient Particles**:

- Digital dust/data fragments
- Floating code symbols
- Holographic noise flickers

**Combat Particles**:

- Spell trail effects (code streams)
- Impact sparks (geometric shards)
- Enemy death (EMP burst + debris)

**Environmental Particles**:

- Sector-specific particle types
- Interactive with player position
- React to combat intensity

### 5.3 Transition Effects

**File**: `lib/ui/transitions.dart` (NEW)

**Screen Transitions**:

- Glitch wipe between screens
- Data stream dissolve
- Scanline reveal
- Boot sequence for cold starts

**In-Game Transitions**:

- Wave start: "WAVE X INCOMING" with alarm
- Wave complete: "SECTOR CLEARED" triumph
- Boss entrance: Dramatic reveal with music sting
- Victory/defeat: Appropriate dramatic sequences

---

## PHASE 6: TECHNICAL IMPROVEMENTS

### 6.1 Performance Optimization

- Object pooling for particles/projectiles
- LOD system for effects based on performance
- Lazy loading of heavy assets
- Memory management for long sessions
- FPS monitoring with auto-quality adjustment

### 6.2 Error Handling

- Graceful degradation for missing assets
- User-friendly error messages in cyberpunk style
- Crash recovery with save preservation
- Network timeout handling for web version

### 6.3 Testing Coverage

- Unit tests for all gameplay calculations
- Integration tests for save/load
- Visual regression tests
- Performance benchmarks

---

## PHASE 7: CONTENT COMPLETION

### 7.1 Achievement System Polish

**File**: `lib/systems/achievement_manager.dart`

20 achievements with cyberpunk names:

| ID  | Name            | Condition                       | Icon      |
| --- | --------------- | ------------------------------- | --------- |
| 01  | FIRST BREACH    | Kill first enemy                | Skull     |
| 02  | GHOST PROTOCOL  | Clear node at 0% surveillance   | Ghost     |
| 03  | ARCHITECT       | Unlock apex upgrade             | CPU       |
| 04  | UNTOUCHABLE     | Clear node without damage       | Shield    |
| 05  | OVERFLOW        | 15x kill streak                 | Lightning |
| 06  | STATIC          | Survive glitch storm            | Glitch    |
| 07  | HOARDER         | Collect 5 artifacts in one node | Cube      |
| 08  | REVOLUTIONARY   | Defeat Sector 1 boss            | Fist      |
| 09  | PACIFIST        | Survive wave with only defense  | Dove      |
| 10  | DECRYPTOR       | Find secret room                | Key       |
| 11  | OVERKILL        | Deal 500+ damage in one hit     | Explosion |
| 12  | FIREWALL MASTER | Block 50 attacks                | Wall      |
| 13  | DATA MINER      | Collect 50 total artifacts      | Pickaxe   |
| 14  | EXECUTIONER     | Kill 100 enemies                | Reaper    |
| 15  | SURVIVOR        | Complete 10 waves               | Heart     |
| 16  | SPEEDRUNNER     | Clear node in under 60s         | Clock     |
| 17  | PERFECTIONIST   | Clear sector without game over  | Star      |
| 18  | LIBERATOR       | Complete the campaign           | Flag      |
| 19  | COMPLETIONIST   | Unlock all achievements         | Trophy    |
| 20  | TRUE REBEL      | Defeat final boss               | Eye       |

### 7.2 Tutorial Enhancement

**File**: `lib/ui/tutorial_screen.dart`

Interactive tutorial with:

- Step-by-step gesture training
- Practice targets
- Tooltip overlays during first combat
- Skip option for returning players
- "REMINDER" system for unused abilities

### 7.3 Story Integration

**File**: `lib/ui/story_screen.dart`

- Sector briefings with character portraits
- Dialogue system for narrative beats
- Collectible data logs (lore items)
- Multiple ending paths based on choices

---

## IMPLEMENTATION ORDER

### Week 1: Visual Foundation

1. New color palette
2. Cyber corridor background
3. Enemy visual redesign (sprites/rendering)
4. Basic screen effects

### Week 2: UI Overhaul

1. HUD redesign
2. Map screen enhancement
3. Upgrade screen polish
4. Transition effects

### Week 3: Gameplay Systems

1. Enemy special attacks (fully functional)
2. Environmental hazards
3. Artifact system
4. Secret rooms

### Week 4: Audio & Polish

1. Sound design implementation
2. Particle system refinement
3. Achievement system completion
4. Tutorial enhancement

### Week 5: Testing & Optimization

1. Bug fixing
2. Performance optimization
3. Cross-platform testing
4. Final polish pass

---

## SUCCESS CRITERIA

- **Visual Consistency**: Every screen feels like same cyberpunk world
- **Performance**: 60 FPS on target devices
- **Playability**: Complete campaign without bugs
- **Immersion**: Sound and visuals create tension/atmosphere
- **Polish**: No placeholder assets, all effects complete
- **Accessibility**: Colorblind mode, adjustable effects

---

## FILE CHANGE SUMMARY

**NEW FILES**:

- `lib/game/components/cyber_corridor.dart`
- `lib/game/components/screen_effects.dart`
- `lib/game/components/particle_systems.dart`
- `lib/ui/transitions.dart`
- `lib/systems/dynamic_audio.dart`

**MAJOR REWRITES**:

- `lib/game/palette.dart`
- `lib/game/components/enemy.dart`
- `lib/game/components/spell_effect.dart`
- `lib/game/components/projectile.dart`
- `lib/ui/hud.dart`
- `lib/ui/upgrade_screen.dart`

**ENHANCEMENTS**:

- `lib/ui/main_menu_screen.dart`
- `lib/ui/map_screen.dart`
- `lib/ui/tutorial_screen.dart`
- `lib/systems/achievement_manager.dart`
- `lib/systems/audio_manager.dart`
- `lib/systems/hazard_controller.dart`
- `lib/game/components/artifact_item.dart`

---

**END OF PLAN**

This plan prioritizes visual cohesion and gameplay feel over feature creep. Every change should reinforce the core cyberpunk surveillance-state narrative. The player should feel like a digital rebel fighting against an oppressive system, with every visual and audio element supporting that fantasy.
