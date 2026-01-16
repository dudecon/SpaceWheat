# Toolbar Audit & Comparison
## Current System vs Intended Design

**Date:** 2026-01-13
**Status:** Complete Audit & Gap Analysis

---

## Executive Summary

The toolbar system has **4 tools currently implemented** (matching ToolConfig.gd), but the **intended design calls for expanded F-cycling features**. Below is a detailed comparison of actual vs intended behavior.

---

## Part 1: Current PLAY Mode Toolbar (Implemented)

### Current State (ToolConfig.gd lines 27-72)

| Tool | Emoji | Name | Q | E | R | F-Cycling |
|------|-------|------|---|---|---|-----------|
| **1** | 🔬 | PROBE | Explore (plant_batch) | Measure (measure_batch) | Pop/Harvest (measure_and_harvest) | ❌ None |
| **2** | 🔄 | GATES | Cluster (cluster) | Measure (measure_trigger) | Remove (remove_gates) | ❌ **DISABLED** |
| **3** | 🏭 | INDUSTRY | Mill (place_mill) | Market (place_market) | Kitchen (place_kitchen) | ❌ **DISABLED** |
| **4** | ⚡ | GATES | Pauli-X (apply_pauli_x) | Hadamard (apply_hadamard) | Pauli-Z (apply_pauli_z) | ❌ None |

### Current Analysis

**Issues:**
1. **Tool 2 & 3 F-cycling disabled**: `"has_f_cycling": false` in all tools
2. **Tool naming conflict**: Tool 2 and Tool 4 both named "GATES" with different emoji
3. **Tool 3 (INDUSTRY)**: Not mentioned in architecture doc; seems to be a deviation
4. **F-cycling infrastructure exists but inactive**:
   - `tool_mode_indices` dictionary tracks modes
   - `cycle_tool_mode()` function implemented
   - But all tools have `has_f_cycling: false`

**Tool Count:** 4 (ToolSelectionRow.gd can display up to 6, but only 4 buttons created)

---

## Part 2: Intended PLAY Mode Toolbar (Architecture v2.1)

### Intended Design (SPACEWHEAT_TOOL_ARCHITECTURE_v2.md lines 165-190)

| Tool | Emoji | Name | Q | E | R | F-Cycling |
|------|-------|------|---|---|---|-----------|
| **1** | 🔬 | PROBE | **EXPLORE** (discover) | **MEASURE** (collapse) | **POP** (harvest) | ❌ **None** |
| **2** | 🔄 | GATES | **[F→]** | **[F→]** | **[F→]** | ✅ **3 modes** |
| **3** | 🔗 | ENTANGLE | **[F→]** | **[F→]** | **[F→]** | ✅ **3 modes** |
| **4** | 💉 | INJECT | **SEED** (expand) | **DRIVE** (hamiltonian) | **PURGE** (remove) | ❌ **None** |

### F-Cycling Detail (Tools 2 & 3)

#### Tool 2: GATES 🔄 (3 Modes)

```
Mode 0 (Basic):      Q: X (bit flip)   E: Y (flip+phase)  R: H (superposition)
         ↓
Mode 1 (Phase):      Q: S (π/2 phase)  E: T (π/4 phase)   R: Rφ (custom)
         ↓
Mode 2 (Two-Qubit):  Q: CNOT           E: CZ              R: SWAP
         ↓ (loops back to Mode 0)
```

#### Tool 3: ENTANGLE 🔗 (3 Modes)

```
Mode 0 (Bell):       Q: Φ+ (standard)  E: Φ- (anti)       R: Ψ+/Ψ- (variants)
         ↓
Mode 1 (Cluster):    Q: GHZ (3+ way)   E: W (distributed) R: Graph state
         ↓
Mode 2 (Manipulate): Q: Phase shift    E: Disentangle     R: Transfer
         ↓ (loops back to Mode 0)
```

### Intended Analysis

**Features:**
- ✅ Strong separation between Tool 1 (PROBE: 80% gameplay) and Tools 2-4 (advanced)
- ✅ F-cycling expands action vocabulary within tools (no new buttons needed)
- ✅ Tool naming aligned with quantum operations
- ✅ Quantum tomography paradigm clear

**Status:** Design specification complete, **not fully implemented in code**

---

## Part 3: BUILD Mode Toolbar (Implemented)

### Current State (ToolConfig.gd lines 78-123)

| Tool | Emoji | Name | Q | E | R | F-Cycling |
|------|-------|------|---|---|---|-----------|
| **1** | 🌍 | BIOME | Assign Biome ▸ (submenu) | Clear Assignment | Inspect Plot | ❌ None |
| **2** | ⚙️ | ICON | Assign Icon ▸ (submenu) | Swap N/S | Clear Icon | ❌ None |
| **3** | 🔬 | LINDBLAD | Drive (+pop) | Decay (-pop) | Transfer | ❌ None |
| **4** | ⚡ | SYSTEM | Reset Bath | Snapshot | Debug View | ❌ None |

### Intended Design (Architecture v2.1 lines 274-308)

| Tool | Emoji | Name | Q | E | R | F-Cycling |
|------|-------|------|---|---|---|-----------|
| **1** | 🌍 | BIOME DESIGN | Paint territory | Merge regions | Split region | ❌ None |
| **2** | ⚙️ | ICON TUNING | Weights | Couplings | Drivers | ❌ None |
| **3** | 🔬 | LINDBLAD CONTROL | Decay (T1) | Transfer | Gated conditions | ❌ None |
| **4** | ⚡ | SYSTEM CONFIG | Integrator | Step Size | Benchmark | ❌ None |

---

## Part 4: Submenus (Dynamic Menu System)

### Current Implementation (ToolConfig.gd lines 129-151)

**Dynamic Submenus Implemented:**
1. **biome_assign** — Dynamically generates Q/E/R from available biomes
2. **icon_assign** — Dynamically generates Q/E/R from available icons

**How it works:**
- Tool 1 Q-action: `submenu_biome_assign` → Opens dynamic biome list
- Tool 2 Q-action: `submenu_icon_assign` → Opens dynamic icon list
- System generates 3 menu items (Q/E/R) at runtime from game state

**Status:** ✅ Fully implemented

---

## Part 5: Global Controls (Always Active)

### Current State

| Key | Action | Implemented |
|-----|--------|-------------|
| **Tab** | Toggle BUILD/PLAY mode | ✅ Yes |
| **Spacebar** | Pause/Resume evolution | ✅ Yes |
| **Escape** | Close overlay / Cancel / Pause menu | ✅ Yes (partial) |
| **1-6** | Select tool | ✅ Yes |

### Intended Enhancements

- Spacebar should show visual "PAUSED" indicator (unclear if implemented)
- Escape should close overlay → return to default viewport (overlay system incomplete)

**Status:** ✅ Core controls working, some visual feedback missing

---

## Part 6: Overlay System (Currently Incomplete)

### Intended Design (Architecture v2.1 lines 347-369)

| Button | Overlay | Alternate Viewport | QER+F Actions | Status |
|--------|---------|-------------------|---------------|--------|
| 📊 | Inspector | Density matrix heatmap | Q: Select register, E: Details, R: Compare, F: Cycle view | ❌ Not implemented |
| 🧭 | Semantic Map | Octant visualization | Q: Navigate octant, E: Zoom, R: Attractors, F: Cycle projection | ❌ Not implemented |
| 🗺️ | Macro Map | Galaxy/world view | Q: Select biome, E: Zoom, R: Connections, F: Cycle layer | ❌ Not implemented |
| 📜 | Quests | Contract list | Q: Select quest, E: Details, R: Accept/Abandon, F: Filter | ❌ Partial (QuestBoard exists) |
| ⌨️ | Controls | Hotkey reference | Q/E/R: Navigate, F: Toggle compact | ❌ Not implemented |
| 👤 | Profile | Player stats | Q: Category, E: Details, R: Toggle, F: Cycle tabs | ❌ Not implemented |
| 🔬 | Biome Detail | Biome close-up | Q: Select Icon, E: Parameters, R: Registers, F: Cycle Icon | ❌ Partial (BiomeInspectorOverlay exists) |

**Status:** ❌ **Major gap** — Framework exists (OverlayManager) but v2 overlay system not implemented

---

## Part 7: Gap Analysis Summary

### ✅ Implemented Features

- [x] Core PLAY mode tools (1-4) with basic actions
- [x] Core BUILD mode tools (1-4) with basic actions
- [x] Dynamic biome/icon assignment submenus
- [x] Tab toggle for BUILD/PLAY mode switching
- [x] Spacebar pause/resume (evolution pausing works)
- [x] Input routing infrastructure (FarmInputHandler)
- [x] Tool selection buttons (ToolSelectionRow)
- [x] Action preview row (ActionPreviewRow)

### ❌ Missing / Incomplete Features

#### High Priority (Core Design)

1. **F-Cycling for Tools 2-3** ❌
   - Infrastructure exists but disabled
   - Need to enable `has_f_cycling: true` in PLAY mode Tools 2-3
   - Actions table incomplete (modes array missing)
   - Action cycling logic needs integration with ActionPreviewRow

2. **Tool Name Standardization** ❌
   - Tool 3 (INDUSTRY) not in architecture doc → needs alignment or removal
   - Tool 4 should be INJECT, not GATES
   - Duplicate "GATES" emoji ⚡ for two different tools

3. **Quantum Tomography Paradigm Shift** ❌
   - Tool 1 Q still labeled "plant_batch" (should be "explore" for PROBE)
   - "INDUSTRY" tool contradicts exploration-first paradigm
   - INJECT (Tool 4) mechanics not implemented

#### Medium Priority (Overlay System)

4. **V2 Overlay System** ❌
   - Base class missing: `V2OverlayBase`
   - OverlayManager needs v2 extension
   - 6 new overlay implementations needed
   - Inspector overlay (priority 1) not started
   - QER+F remapping for overlays not implemented
   - WASD navigation for overlays not implemented

5. **Sidebar Overlay Buttons** ❌
   - No hexagon buttons on left/right sides
   - No visual indicator for active overlay
   - No button styling specifications

#### Low Priority (Polish)

6. **F-Mode Visual Indicator** ❌
   - No display showing current F-cycling mode (e.g., "GATES: Basic")
   - No visual feedback when F is pressed

7. **Pause State Visual Feedback** ❌
   - Infrastructure exists but UI feedback unclear
   - Need "PAUSED" indicator or visual state change

---

## Part 8: Implementation Roadmap

### Phase 1: Fix Core Tool System (High Priority)

1. **Update ToolConfig.gd:**
   ```gdscript
   # Fix Tool naming and F-cycling
   - Rename Tool 3 from INDUSTRY to ENTANGLE
   - Rename Tool 4 actions to match INJECT
   - Enable has_f_cycling: true for Tools 2-3
   - Add modes array to each cycling tool
   - Define ACTION_TABLE with 3 modes per tool
   ```

2. **Enable F-Cycling UI:**
   ```gdscript
   # Modify ActionPreviewRow.gd
   - Display F-mode indicator (e.g., "GATES: Mode 1/3")
   - Update button labels when F is pressed
   - Show visual transition between modes
   ```

3. **Test Core Loop:**
   - Verify Tool 1 PROBE works (EXPLORE → MEASURE → POP)
   - Verify Tool 2 GATES cycles through modes on F press
   - Verify Tool 3 ENTANGLE cycles through modes on F press

### Phase 2: Implement Overlay System (Medium Priority)

1. **Create V2OverlayBase:**
   - Base class for all v2 overlays
   - Define standard interface (handle_input, on_q_pressed, etc.)

2. **Implement Inspector Overlay (Priority 1):**
   - Density matrix visualization
   - Register/Bubble selection
   - View mode cycling (Bloch → Matrix → Bars)

3. **Adapt Existing Overlays:**
   - QuestBoard → Quests overlay
   - BiomeInspectorOverlay → Biome Detail overlay
   - KeyboardHint → Controls overlay

4. **New Overlays (Lower Priority):**
   - Semantic Map
   - Macro Map
   - Profile

### Phase 3: UI Refinement (Low Priority)

1. **Add Sidebar Buttons**
2. **F-Mode Indicator Display**
3. **Pause State Visual Feedback**
4. **Complete Overlay Documentation**

---

## Part 9: Quick Reference Table

### Current vs Intended: PLAY Mode

```
╔════════════════════════════════════════════════════════════════════════════╗
║ COMPARISON: Current Implementation vs Intended Design                      ║
╠═══════╦════════════╦═══════════════════════════╦═══════════════════════════╣
║ Tool  ║  Intended  ║ Current Status            ║ Gap                       ║
╠═══════╬════════════╬═══════════════════════════╬═══════════════════════════╣
║   1   ║ PROBE 🔬   ║ ✅ Implemented (4 actions)║ ❌ Action name: plant_batch║
║       ║ Q/E/R      ║    (Explore, Measure, Pop)║    should be "explore"    ║
║       ║ No F-cycle ║                           ║                           ║
║───────┼────────────┼───────────────────────────┼───────────────────────────┤
║   2   ║ GATES 🔄   ║ ✅ Implemented base       ║ ❌ F-cycling disabled      ║
║       ║ 3 F-modes  ║    ❌ F-cycling disabled  ║    (has_f_cycling: false) ║
║       ║            ║    (different actions)    ║ ❌ Missing mode structure  ║
║───────┼────────────┼───────────────────────────┼───────────────────────────┤
║   3   ║ ENTANGLE 🔗║ ❌ Current: INDUSTRY 🏭   ║ ❌ Completely wrong tool   ║
║       ║ 3 F-modes  ║    (Mill, Market, Kitchen)║ ❌ Need full redesign      ║
║───────┼────────────┼───────────────────────────┼───────────────────────────┤
║   4   ║ INJECT 💉  ║ ❌ Current: GATES ⚡      ║ ❌ Wrong name & actions    ║
║       ║ Q/E/R      ║    (Pauli-X, H, Pauli-Z) ║ ❌ Need new mechanics      ║
║       ║ No F-cycle ║    (different from Tool 2)║                           ║
╚═══════╩════════════╩═══════════════════════════╩═══════════════════════════╝
```

---

## Part 10: Action Details Comparison

### Tool 1: PROBE 🔬

| Aspect | Current | Intended |
|--------|---------|----------|
| **Q Action** | `plant_batch` | `explore` (bind plot to random register) |
| **E Action** | `measure_batch` | `measure` (collapse wavefunction) |
| **R Action** | `measure_and_harvest` | `pop` (harvest resources) |
| **F-Cycling** | No | No |
| **Description** | Explore, measure, harvest | Same, but semantic change: discover not create |

### Tool 2: GATES 🔄

| Aspect | Current | Intended |
|--------|---------|----------|
| **Modes** | 0 (disabled) | 3: Basic, Phase, TwoQubit |
| **Mode 0 (Basic)** | ❌ Not implemented | X, Y, H gates |
| **Mode 1 (Phase)** | ❌ Not implemented | S, T, Rφ gates |
| **Mode 2 (TwoQubit)** | ❌ Not implemented | CNOT, CZ, SWAP |
| **F-Cycling** | ❌ Disabled | ✅ Cycles Basic → Phase → TwoQubit |
| **Selection** | Single Bubble | 1 (single-qubit) or 2 (two-qubit) Bubbles |

### Tool 3: ENTANGLE 🔗

| Aspect | Current | Intended |
|--------|---------|----------|
| **Current Tool** | INDUSTRY (🏭) | Should be ENTANGLE (🔗) |
| **Modes** | 0 (disabled) | 3: Bell, Cluster, Manipulate |
| **Mode 0 (Bell)** | ❌ Not implemented | Φ+, Φ-, Ψ+/Ψ- states |
| **Mode 1 (Cluster)** | ❌ Not implemented | GHZ, W, Graph states |
| **Mode 2 (Manipulate)** | ❌ Not implemented | Phase, Disentangle, Transfer |
| **F-Cycling** | ❌ Disabled | ✅ Cycles Bell → Cluster → Manipulate |
| **Selection** | N/A | 2+ Bubbles (depends on mode) |

### Tool 4: INJECT 💉

| Aspect | Current | Intended |
|--------|---------|----------|
| **Current Name** | GATES (⚡) | Should be INJECT (💉) |
| **Current Actions** | Pauli-X, Hadamard, Pauli-Z | SEED, DRIVE, PURGE |
| **Q (Intended)** | ❌ Not implemented | SEED (add new qubit pair) |
| **E (Intended)** | ❌ Not implemented | DRIVE (apply Hamiltonian) |
| **R (Intended)** | ❌ Not implemented | PURGE (remove qubit) |
| **F-Cycling** | No | No |
| **Cost** | None | Resource-intensive (Flux + materials) |

---

## Part 11: Code Files Affected

### Files Needing Major Updates

1. **Core/GameState/ToolConfig.gd** (PRIMARY)
   - Update PLAY_TOOLS constants
   - Enable F-cycling for Tools 2-3
   - Add modes array and ACTION_TABLE

2. **UI/Panels/ActionPreviewRow.gd**
   - Add F-mode indicator display
   - Update labels on F-press

3. **UI/FarmInputHandler.gd**
   - Route F-cycling tool mode changes
   - Update tool action dispatch

### Files Needing New Implementation

4. **UI/Overlays/V2OverlayBase.gd** (NEW)
   - Base class for overlay system

5. **UI/Overlays/InspectorOverlay.gd** (NEW)
   - Priority 1 overlay

6. **UI/Managers/OverlayManager.gd** (MODIFY)
   - Add v2 overlay support

---

## Part 12: UI & Menu Configuration Audit

### Overview

The current UI is organized into **11 major systems** with **40+ panels/overlays**. This audit compares current implementation against the intended v2.1 architecture.

---

### 12.1: Architecture & Organization

#### Current State

**Scene Hierarchy:**
```
PlayerShell (Root, persistent across farm switches)
├── OverlayLayer (z_index=100, all menus/overlays)
├── ActionBarLayer (z_index=50, tool buttons + Q/E/R row)
└── FarmUIContainer
    └── FarmUI (Farm-specific, swappable)
        ├── ResourcePanel (top)
        └── PlotGridDisplay (main area)
```

**Managers (3):**
1. **UILayoutManager** - Responsive scaling, responsive breakpoints
2. **OverlayManager** - Menu/overlay management (centralized)
3. **ActionBarManager** - Creates tool and action button rows

**Status:** ✅ Solid architecture, well-organized hierarchy

---

### 12.2: Menu System Audit

#### Current Menus Implemented

| Menu | Access Key | Type | Status | Purpose |
|------|-----------|------|--------|---------|
| **Escape Menu** | ESC | Modal | ✅ Working | Pause, save, load, quit, settings |
| **Save/Load** | Via ESC | Modal | ✅ Working | 3 save slots + debug environments |
| **Quest Board** | C | Modal | ✅ Working | 4-slot quest interface (U/I/O/P) |
| **Faction Browser** | C (alternate) | Panel | ⚠️ Legacy | Browse faction quests |
| **Vocabulary** | V | Panel | ✅ Working | View discovered emojis |
| **Keyboard Help** | K | Panel | ✅ Working | Keyboard shortcuts reference |
| **Biome Inspector** | B | Overlay | ✅ Working | Inspect biome properties |
| **Quantum Config** | Shift+Q | Panel | ✅ Working | Quantum rigor mode settings |
| **Logger Config** | L | Panel | ✅ Working | Debug logging settings |
| **Icon Detail** | Click emoji | Panel | ✅ Working | Show emoji icon info |

**Total Menus:** 10 working

---

#### Keyboard Shortcut Mapping

```
┌─────────────────────────────────────────┐
│ MODAL LAYER (Layer 1 - Highest Priority)│
├─────────────────────────────────────────┤
│ ESC → Toggle Escape Menu (pause)        │
│ C → Toggle Quest Board                  │
│ C (alt) → Show Faction Offers           │
└─────────────────────────────────────────┘
        ↓ (if modal not active)
┌─────────────────────────────────────────┐
│ SHELL LAYER (Layer 2 - Medium Priority) │
├─────────────────────────────────────────┤
│ V → Toggle Vocabulary                   │
│ K → Toggle Keyboard Help                │
│ L → Toggle Logger Config                │
│ B → Toggle Biome Inspector              │
│ Shift+Q → Toggle Quantum Config         │
└─────────────────────────────────────────┘
        ↓ (if no shell shortcut matches)
┌─────────────────────────────────────────┐
│ FARM LAYER (Layer 3 - Lowest Priority)  │
├─────────────────────────────────────────┤
│ 1-4 → Select Tool                       │
│ Q/E/R → Execute Tool Action             │
│ F → Cycle Tool Mode (disabled)          │
│ T/Y/U/I/O/P → Select Plot               │
│ Spacebar → Pause/Resume Evolution       │
│ Tab → Toggle BUILD/PLAY Mode            │
└─────────────────────────────────────────┘
```

**Status:** ✅ Modal stack working, 3-layer input hierarchy working

---

### 12.3: Overlay System Comparison

#### Current Overlays

| Overlay | Status | Purpose | Z-Index | QER+F Actions |
|---------|--------|---------|---------|---------------|
| **Quest Board** | ✅ Working | 4-slot quest UI | 1003 | C slot selection |
| **Vocabulary** | ✅ Working | Emoji discovery | 1000 | Click to view details |
| **Biome Inspector** | ✅ Working | Biome properties | 100 | Read-only inspection |
| **Quantum Config** | ✅ Working | Rigor settings | 1003 | Radio button select |
| **Logger Config** | ✅ Working | Debug settings | Modal | Toggle logging |
| **Escape Menu** | ✅ Working | Pause menu | 4090 | Arrow + Enter nav |
| **Save/Load Menu** | ✅ Working | Save system | 4000 | Arrow + Enter nav |
| **Quantum HUD** | ✅ Working | Left sidebar info | Modal | Info display only |
| **Touch Buttons** | ✅ Working | Right sidebar (mobile) | 4090 | Touch buttons |
| **Keyboard Help** | ✅ Working | Shortcuts reference | Modal | Read-only display |

**Current Count:** 10 overlays

#### Intended Overlays (v2 System)

| Overlay | Status | Purpose | QER+F Actions | Selection |
|---------|--------|---------|---------------|-----------|
| **Inspector** 📊 | ❌ Not impl. | Density matrix visualization | Select, Details, Compare, Cycle view | WASD |
| **Semantic Map** 🧭 | ❌ Not impl. | Octant visualization | Navigate octant, Zoom, Attractors, Cycle proj. | WASD |
| **Macro Map** 🗺️ | ❌ Not impl. | Galaxy/biome territories | Select biome, Zoom, Connections, Cycle layer | WASD |
| **Quests** 📜 | ⚠️ Partial | Contract list (adapt QuestBoard) | Select quest, Details, Accept/Abandon, Filter | WASD |
| **Controls** ⌨️ | ❌ Not impl. | Hotkey reference (adapt K menu) | Navigate, Toggle compact | WASD |
| **Profile** 👤 | ❌ Not impl. | Player stats/vocabulary | Select category, Details, Toggle, Cycle tabs | WASD |
| **Biome Detail** 🔬 | ⚠️ Partial | Biome close-up (adapt existing) | Select Icon, Parameters, Registers, Cycle | WASD |

**Intended Count:** 7 overlays (only 4 currently have base implementations)

**Gap:** 3 new overlays needed (Inspector, Semantic Map, Macro Map)

---

### 12.4: Action Bar System

#### Current State (ActionBarManager)

**Creates:**
1. **ToolSelectionRow** - Tools 1-4 selection buttons (can support 6)
2. **ActionPreviewRow** - Q/E/R action preview buttons

**Features:**
- ✅ Tool button highlighting (cyan when selected)
- ✅ Action button availability (green=available, gray=disabled)
- ✅ Submenu support (biome/icon assignment)
- ✅ Dynamic label updates
- ✅ Responsive sizing

**Gaps:**
- ❌ No F-mode indicator display (e.g., "GATES: Mode 1/3")
- ❌ No F-cycle visual feedback
- ❌ Only 4 tools visible (infrastructure supports 6)
- ❌ No overlay action label support (QER+F should change when overlay open)

**Status:** ✅ Functional, needs enhancement for F-cycling and overlay integration

---

### 12.5: Z-Index Layering

#### Current Layering

```
Player-Level Layers (PlayerShell):
├── OverlayLayer (z_index=100)
│   ├── Save/Load Menu (z=4000) ✅
│   ├── Escape Menu (z=4090) ✅
│   ├── Touch Button Bar (z=4090) ✅
│   ├── Quest Board (z=1003) ✅
│   ├── Quantum Config (z=1003) ✅
│   ├── Faction Offers (z=1002) ⚠️ Legacy
│   ├── Quest Panel (z=1001) ⚠️ Legacy
│   ├── Vocabulary (z=1000) ✅
│   ├── Biome Inspector (z=100) ✅
│   ├── Logger Config (Modal) ✅
│   ├── Quantum HUD (Modal) ✅
│   ├── Icon Detail (Modal) ✅
│   └── v2 Overlays (z=2000) ⚠️ Not used
└── ActionBarLayer (z_index=50)
    ├── ActionPreviewRow (z=4000) ✅
    └── ToolSelectionRow (z=3000) ✅

Farm-Level Layers (FarmUI):
└── FarmUI (z_index=100)
    ├── ResourcePanel (top) ✅
    └── PlotGridDisplay (z=-10) ✅
```

**Status:** ✅ Well-organized, clear precedence

---

### 12.6: Panel Count Analysis

#### Current Panels: 40+ Components

**Location:** `/home/tehcr33d/ws/SpaceWheat/UI/Panels/` (26 files)

**By Category:**

| Category | Count | Purpose | Status |
|----------|-------|---------|--------|
| **Core Interaction** | 2 | Tool selection, action buttons | ✅ Working |
| **Quest System** | 4 | Quest board, offers, panel, contract | ✅ Working |
| **Information** | 8 | HUD, keyboard help, biome info, icon detail | ✅ Working |
| **Visualization** | 6 | Network, ecosystem, attractor, biome oval | ⚠️ Partial |
| **Configuration** | 3 | Quantum rigor, logger, resource | ✅ Working |
| **Navigation** | 2 | Faction browser, goal panel | ⚠️ Legacy |
| **Meters & Displays** | 5 | Energy, uncertainty, semantic context, etc. | ✅ Working |
| **Not Classified** | 4 | Specialized components | ⚠️ Mixed |

**Analysis:** Too many panels for core functionality; some are duplicated or legacy

---

### 12.7: Overlay Manager Coverage

#### Overlays Managed by OverlayManager

**Location:** `/home/tehcr33d/ws/SpaceWheat/UI/Managers/OverlayManager.gd`

**Current Responsibilities:**
- ✅ Toggle quest board / faction offers
- ✅ Toggle vocabulary overlay
- ✅ Toggle escape menu
- ✅ Toggle keyboard help
- ✅ Toggle biome inspector
- ✅ Toggle quantum config
- ✅ Toggle save/load menu
- ✅ Modal stack management
- ✅ Visibility toggling

**Missing (v2 System):**
- ❌ v2 overlay support framework
- ❌ QER+F action remapping
- ❌ WASD navigation within overlays
- ❌ Overlay-specific action labels
- ❌ Overlay state persistence

**Status:** ✅ Works for current system, needs extension for v2

---

### 12.8: Input Routing Analysis

#### Current Three-Layer System

**Layer 1: Modal Stack (PlayerShell)**
- Priority: Highest
- Examples: ESC menu, Save/Load, Quest Board
- Behavior: Each modal gets input first
- LIFO processing: Newest modal processed first

**Layer 2: Shell Actions (PlayerShell)**
- Priority: Medium (if no modal active)
- Examples: C, V, K, L, B, Shift+Q
- Behavior: Global keyboard shortcuts
- Status: ✅ Working

**Layer 3: Farm Input (FarmInputHandler)**
- Priority: Lowest (if no modal/shell shortcut)
- Examples: 1-4 (tools), Q/E/R (actions), F (mode cycle)
- Behavior: Farm-level gameplay
- Status: ✅ Mostly working, F-cycling disabled

**Status:** ✅ Solid architecture, clear precedence

---

### 12.9: Missing UI Features for v2.1 Design

#### Critical Gaps

| Feature | Current | Intended | Impact |
|---------|---------|----------|--------|
| **F-Mode Indicator** | ❌ None | "GATES: Mode 1/3" in tool area | Visual feedback missing |
| **Overlay Action Labels** | ❌ Static | QER+F change per overlay | Can't show overlay actions |
| **WASD Navigation** | ❌ None | Overlay selection system | Can't navigate overlays |
| **Overlay Sidebar Buttons** | ❌ None | Hexagon buttons left/right | No overlay access buttons |
| **Pause Indicator** | ⚠️ Partial | "PAUSED" text overlay | Visual feedback weak |
| **Inspector Overlay** | ❌ None | Density matrix visualization | Priority 1, not done |
| **v2 Overlay Base Class** | ❌ None | V2OverlayBase with interface | Foundation missing |
| **Semantic Map Overlay** | ❌ None | Octant visualization | Important feature missing |
| **Profile Overlay** | ❌ None | Player stats display | Nice-to-have missing |

---

### 12.10: UI Recommendations

#### High Priority (Core Functionality)

1. **Implement F-Mode Indicator**
   - Display current mode in tool button area
   - Update on F press with visual transition
   - Example: Add to ActionPreviewRow above buttons

2. **Enable v2 Overlay System**
   - Create V2OverlayBase class
   - Extend OverlayManager with v2 methods
   - Start with Inspector overlay (simplest)

3. **Fix Overlay Action Label Updates**
   - Detect when overlay opens
   - Update ActionPreviewRow to show overlay actions
   - Handle Q/E/R remapping

#### Medium Priority (Extended Features)

4. **Add Sidebar Overlay Buttons**
   - Left sidebar: 📊/🧭/👤 buttons (Inspector/Semantic/Profile)
   - Right sidebar: 🗺️/📜/⌨️ buttons (Macro/Quests/Controls)
   - Highlight active overlay
   - Touch-friendly sizing

5. **Implement WASD Overlay Navigation**
   - Support within overlay viewports
   - Connect to overlay selection state
   - Visual highlight of selected item

6. **Consolidate Panels**
   - Remove duplicate panels (Quest Panel + Quest Board)
   - Archive legacy panels (Faction Offers, etc.)
   - Streamline to ~20 core panels

#### Low Priority (Polish)

7. **Enhance Pause Indicator**
   - Clearer visual feedback when paused
   - Darken/desaturate or add "PAUSED" overlay

8. **Rename & Organize Tools**
   - Fix Tool 3 (INDUSTRY → ENTANGLE)
   - Fix Tool 4 (GATES → INJECT)
   - Ensure no emoji duplication

---

### 12.11: Panel Cleanup Recommendations

#### Current Panel Inventory

**Keep (Core):**
- ToolSelectionRow
- ActionPreviewRow
- ResourcePanel
- QuestBoard
- VocabularyPanel
- BiomeInspectorOverlay
- KeyboardHintButton
- EscapeMenu
- SaveLoadMenu

**Archive/Legacy:**
- QuestPanel (duplicate of QuestBoard)
- FactionQuestOffersPanel (redundant)
- ControlsInterface (replace with ControlsOverlay v2)

**Consolidate:**
- Multiple info panels → Single unified Info system
- Multiple visualization panels → Dedicated VisualizationManager

**Total After Cleanup:** ~20 core panels (vs current 40+)

---

### 12.12: File Structure Recommendations

#### Current Structure
```
/UI/
├── Managers/ (3 files)
├── Panels/ (26 files) ← TOO MANY
├── Overlays/ (4 files) ← Needs v2
├── Components/ (1 file)
├── Input/ (1 file)
└── Root level (10 files)
```

#### Recommended Structure
```
/UI/
├── Managers/ (3 files)
│   ├── UILayoutManager.gd
│   ├── OverlayManager.gd
│   └── ActionBarManager.gd
├── Panels/ (12-15 core files)
│   ├── ActionPreviewRow.gd
│   ├── ToolSelectionRow.gd
│   ├── ResourcePanel.gd
│   ├── QuestBoard.gd
│   ├── EscapeMenu.gd
│   ├── SaveLoadMenu.gd
│   └── ... (others)
├── Overlays/ (10+ files)
│   ├── V2OverlayBase.gd ← NEW
│   ├── InspectorOverlay.gd ← NEW
│   ├── SemanticMapOverlay.gd ← NEW
│   ├── MacroMapOverlay.gd ← NEW
│   ├── ControlsOverlay.gd ← NEW
│   ├── BiomeDetailOverlay.gd (adapted)
│   ├── QuestOverlay.gd (adapted)
│   ├── ProfileOverlay.gd ← NEW
│   └── ... (legacy)
├── Components/
├── Input/
└── Root level
```

---

### 12.13: Current UI Strengths ✅

1. **Clean Architecture** - PlayerShell + FarmUI separation works well
2. **Responsive Scaling** - UILayoutManager handles multiple screen sizes
3. **Modal Stack** - Clear 3-layer input hierarchy
4. **Centralized Overlay Management** - OverlayManager is single source of truth
5. **Dynamic Action Bars** - Buttons update based on context
6. **Keyboard Shortcuts** - Well-organized shortcut system
7. **Signal-Driven** - Clean decoupling via signals

---

### 12.14: Current UI Weaknesses ❌

1. **Too Many Panels** - 26 files in Panels/ (some redundant)
2. **F-Cycling Not Integrated** - Infrastructure disabled, no UI feedback
3. **No Overlay Sidebar Buttons** - Hard to discover overlays
4. **Legacy Code** - Multiple deprecated panels still in system
5. **No v2 Overlay System** - Framework incomplete
6. **Tool Naming Issues** - INDUSTRY and duplicate GATES confusing
7. **No Pause Indicator** - Visual feedback unclear when paused

---

## Part 14: Overall Conclusion

### Current State (Comprehensive)
- **4-tool PLAY mode system implemented** but with incorrect tool definitions
- **Core infrastructure working** (input routing, tool selection, action preview)
- **F-cycling infrastructure exists but disabled**
- **Overlay system incomplete** (framework present, v2 overlays not implemented)

### Intended State
- **4-tool PLAY mode** with proper quantum paradigm tools (PROBE, GATES, ENTANGLE, INJECT)
- **Full F-cycling support** for Tools 2-3 with 3 modes each
- **7 v2 overlays** with full QER+F remapping and WASD navigation
- **Touch-first design** with no hover states

### Effort Required
- **High Priority (Core Tools)**: ~4-6 hours
  - Fix ToolConfig.gd tool definitions
  - Enable F-cycling with mode structure
  - Update UI to show F-mode indicators

- **Medium Priority (Overlay System)**: ~2-3 days
  - Create V2OverlayBase class
  - Implement Inspector overlay (simplest first)
  - Adapt existing overlays

- **Low Priority (Polish)**: ~1 day
  - Visual feedback enhancements
  - Button styling

---

**Document Status:** Complete
**Last Updated:** 2026-01-13
**Next Action:** Prioritize ToolConfig.gd fixes for immediate implementation
