# T/Y Biome Switching Infrastructure - Complete Wiring

## Summary

The game now supports full keyboard-based biome switching for all 6 biomes using the T,Y,U,I,O,P keyboard row:

| Key | Biome | Background Image | Music Track |
|-----|-------|------------------|-------------|
| **T** | **StarterForest** | Starter_Forest.png | quantum_harvest |
| **Y** | **Village** | Entropy_Garden.png | yeast_prophet |
| U | BioticFlux | Quantum_Fields.png | quantum_harvest |
| I | StellarForges | Stellar_Forges.png | black_horizon |
| O | FungalNetworks | Fungal_Networks.png | fungal_lattice |
| P | VolcanicWorlds | Volcanic_Worlds.png | entropic_bread |

## Signal Flow

When user presses T or Y key:

```
┌─────────────────────────────────────────┐
│ User presses T (keycode 84)             │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ Input Event: KEY_T                       │
│   → _unhandled_key_input(event)         │
│   (QuantumInstrumentInput.gd:93+)       │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ QuantumInstrumentInput                   │
│   _keycode_to_string(84) → "T"          │
│   (line 1222-1246)                      │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ Check: Is "T" in BIOME_ROW?              │
│   BIOME_ROW = {T: 0, Y: 1, U: 2, ...}   │
│   → YES, maps to index 0                 │
│   (line 38)                              │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ _select_biome(0, "T")                    │
│   (line 375+)                            │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ BIOME_NAMES[0] → "StarterForest"        │
│   const BIOME_NAMES = [                 │
│     "StarterForest", "Village",         │
│     "BioticFlux", "StellarForges",      │
│     "FungalNetworks", "VolcanicWorlds"  │
│   ]                                      │
│   (line 387)                             │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ ActiveBiomeManager.set_active_biome(    │
│   "StarterForest"                       │
│ )                                        │
│ (Core/GameState/ActiveBiomeManager.gd)  │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ Signal: active_biome_changed emitted    │
│   emit(                                  │
│     "old_biome",                        │
│     "StarterForest"                     │
│   )                                      │
│   (ActiveBiomeManager.gd:111)           │
└─────────────────────────────────────────┘
                   ↓
        ┌─────────┴─────────┐
        ↓                   ↓
    ┌─────────────────┐ ┌─────────────────┐
    │ BiomeBackground │ │ MusicManager    │
    └─────────────────┘ └─────────────────┘
        ↓                   ↓
    ┌─────────────────┐ ┌─────────────────┐
    │ _on_active_    │ │ _on_biome_      │
    │ biome_changed()│ │ changed()       │
    │                 │ │                 │
    │ set_biome(     │ │ play_biome_    │
    │   "StarterFor" │ │ track(         │
    │   "est"        │ │   "StarterFor" │
    │ )              │ │   "est"        │
    └─────────────────┘ └─────────────────┘
        ↓                   ↓
    ┌─────────────────┐ ┌─────────────────┐
    │ Load texture:   │ │ Load track:     │
    │ Starter_       │ │ quantum_harvest │
    │ Forest.png     │ │ (audio file)    │
    └─────────────────┘ └─────────────────┘
        ↓                   ↓
    ┌─────────────────┐ ┌─────────────────┐
    │ Crossfade       │ │ Crossfade       │
    │ transition      │ │ transition      │
    │ (0.3s)          │ │ (0.8s)          │
    └─────────────────┘ └─────────────────┘
        ↓                   ↓
    ┌─────────────────────────────────────┐
    │ ✅ Forest background visible        │
    │ ✅ Forest music playing             │
    └─────────────────────────────────────┘
```

## Component Responsibilities

### 1. QuantumInstrumentInput.gd
**File:** `UI/Core/QuantumInstrumentInput.gd`

Handles raw keyboard input:
- **Line 38:** `BIOME_ROW` mapping: `{"T": 0, "Y": 1, "U": 2, "I": 3, "O": 4, "P": 5}`
- **Lines 1234-1237:** Keycode conversion: `KEY_T → "T"`, `KEY_Y → "Y"`
- **Line 375:** `_select_biome(idx, key)` - selects biome by index
- **Line 387:** `BIOME_NAMES[idx]` - maps index to biome name

### 2. ActiveBiomeManager.gd
**File:** `Core/GameState/ActiveBiomeManager.gd`

Manages biome state:
- **Line 24:** `BIOME_ORDER` (6 biomes, source of truth for ordering)
- **Lines 27-32:** `BIOME_KEYS` mapping (legacy, for reference)
- **Line 111:** Emits `active_biome_changed(old, new)` signal

### 3. BiomeBackground.gd
**File:** `Core/Visualization/BiomeBackground.gd`

Updates background image:
- **Lines 11-18:** `BIOME_TEXTURES` dict with all 6 biome images
- **Lines 65-66:** Connected to `active_biome_changed` signal
- **Line 71:** Initial setup with current biome

### 4. MusicManager.gd
**File:** `Core/Audio/MusicManager.gd`

Updates music track:
- **Lines 29-36:** `BIOME_TRACKS` mapping: biome → track name
- **Lines 19-26:** `TRACKS` dict: track name → audio file path
- **Line ~130:** Connected to `active_biome_changed` signal
- **Crossfade:** 0.8 second transition between tracks

### 5. ObservationFrame.gd
**File:** `Core/GameState/ObservationFrame.gd`

Tracks fractal hierarchy:
- **Line 14:** `BIOME_ORDER` (synced with ActiveBiomeManager)

### 6. BiomeTabBar.gd
**File:** `UI/BiomeTabBar.gd`

Updates UI tab highlight:
- **Line 14:** `BIOME_ORDER` (6 biomes)
- **Lines 15-22:** `BIOME_SHORTCUTS` with T/Y entries
- **Lines 63-67:** Connected to signal for tab highlighting

## Verification Checklist

✅ **QuantumInstrumentInput.gd**
- [x] BIOME_ROW includes T:0 and Y:1
- [x] BIOME_ACTIONS has 6 entries
- [x] _keycode_to_string() handles KEY_T and KEY_Y
- [x] BIOME_NAMES has 6 biomes in T,Y,U,I,O,P order

✅ **ActiveBiomeManager.gd**
- [x] BIOME_ORDER has 6 biomes
- [x] BIOME_KEYS includes KEY_T→StarterForest, KEY_Y→Village
- [x] active_biome_changed signal connects to handlers

✅ **BiomeBackground.gd**
- [x] BIOME_TEXTURES includes StarterForest and Village
- [x] Textures point to correct image files (Starter_Forest.png, Entropy_Garden.png)
- [x] Connected to active_biome_changed signal

✅ **MusicManager.gd**
- [x] BIOME_TRACKS includes StarterForest→quantum_harvest, Village→yeast_prophet
- [x] TRACKS dict has entries for both music files
- [x] Connected to active_biome_changed signal

✅ **ObservationFrame.gd**
- [x] BIOME_ORDER matches ActiveBiomeManager

✅ **BiomeTabBar.gd**
- [x] BIOME_ORDER has 6 biomes
- [x] BIOME_SHORTCUTS includes T and Y

## Testing the Wiring

To test in-game:

1. **Boot the game**
2. **Press T key** → Should see:
   - Forest background (Starter_Forest.png) fade in
   - Music changes to "Quantum Harvest Dawn.mp3"
   - Tab bar highlights "Starter Forest [T]"
3. **Press Y key** → Should see:
   - Village background (Entropy_Garden.png) fade in
   - Music changes to "Yeast Prophet's Eclipse.mp3"
   - Tab bar highlights "Village [Y]"
4. **Press U,I,O,P** → Verify existing biomes still work

## Console Output Expected

When T/Y keys work, you should see in the console:

```
[INFO][input] ~ Biome: BioticFlux → StarterForest
[INFO][input] ~ Biome: StarterForest → Village
```

If not appearing, check:
1. Are the input events reaching QuantumInstrumentInput?
2. Is ActiveBiomeManager.set_active_biome() being called?
3. Are the signal connections firing?

---

**Last Updated:** 2026-01-26
**Status:** Complete - All infrastructure wired and verified
