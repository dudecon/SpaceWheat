# 🍞 SpaceWheat Kitchen Pipeline: Upgrade Directive

**Version**: 1.0
**Date**: 2026-01-05
**Status**: READY FOR IMPLEMENTATION
**Scope**: Complete kitchen gameplay loop via Icon-driven analog quantum physics

---

## Executive Summary

This directive transforms SpaceWheat from a "tool-triggered" game into an **analog quantum gardening** simulation. The core insight:

> **Icons ARE the physics. Buildings are portals that inject Icons. The player sets conditions. The Hamiltonian does the work.**

### What This Fixes
1. ✅ Mill measurement ambiguity → Mill just injects Flour Icon
2. ✅ Energy tap layer mismatch → Taps work on any plot, drain Icon populations
3. ✅ Kitchen cross-biome access → Kitchen is self-contained 8D (3-qubit) system
4. ✅ Wheat not consumed → Lindblad transfers handle population flow
5. ✅ Hard-coded thresholds → Gaussian "sweet spot" curves in Icon requirements

### The Paradigm Shift

```
OLD MODEL (Tool-Triggered):
  Player → clicks Mill → Mill code measures wheat → produces flour
  Player → clicks Kitchen → Kitchen code creates Bell state → produces bread

NEW MODEL (Analog Quantum):
  Player → places Mill → Flour Icon injected into biome
  Physics → Hamiltonian rotates wheat↔flour population
  Player → places Tap on flour → Lindblad drains flour to economy
  Player → adds flour to Kitchen → pumps Kitchen's flour register
  Physics → Gaussian-weighted Lindblad flows toward bread state
  Player → harvests Kitchen when ready → measurement collapses to bread (or not)
```

---

## Part 1: Icon System Extensions

### 1.1 Update Icon.gd

Add these new fields to `Core/QuantumSubstrate/Icon.gd`:

```gdscript
## ========================================
## Dynamic Requirements (Parametric Lindblad)
## Manifest: Analog Quantum Gardening
## ========================================

## Population requirements for this Icon's incoming Lindblad rates to activate
## Key = emoji, Value = Dictionary with "ideal" (float) and "sigma" (float)
## 
## The Lindblad incoming rate is multiplied by:
##   Ω = ∏_i exp(-(P_i - ideal_i)² / (2 * sigma_i²))
##
## When all populations are at their ideal values, Ω = 1.0 (full rate)
## When populations deviate, Ω → 0 (rate suppressed)
##
## Example for Bread:
##   dynamic_requirements = {
##       "🔥": {"ideal": 0.7, "sigma": 0.15},  # Hot but not scorching
##       "💧": {"ideal": 0.4, "sigma": 0.20},  # Damp but not wet
##       "💨": {"ideal": 0.5, "sigma": 0.15}   # Plenty of flour
##   }
@export var dynamic_requirements: Dictionary = {}

## ========================================
## Injection Behavior
## ========================================

## When this Icon is injected, also inject these Icons (dependencies)
## Example: Bread Icon might co-inject Fire, Water, Flour if not present
@export var co_injected_icons: Array[String] = []

## Does injecting this Icon allocate a new quantum register in the bath?
## True for "substance" Icons (flour, water, fire, bread)
## False for "modifier" Icons (temperature boost, catalyst)
@export var allocates_register: bool = true

## Basis labels when this Icon allocates a register
## north_emoji = |0⟩ state (the "present" state)
## south_emoji = |1⟩ state (the "absent" or "opposite" state)
@export var register_north_emoji: String = ""
@export var register_south_emoji: String = ""
```

### 1.2 Add Icon Helper Method

Add to `Icon.gd`:

```gdscript
## Get the register basis labels for this Icon
## Returns: {north: String, south: String}
func get_register_basis() -> Dictionary:
    var north = register_north_emoji if register_north_emoji else emoji
    var south = register_south_emoji if register_south_emoji else "❌"
    return {"north": north, "south": south}
```

---

## Part 2: Define Core Icons for Kitchen Pipeline

### 2.1 Update CoreIcons.gd

In `Core/Icons/CoreIcons.gd`, add/update these Icon definitions in `register_all()`:

```gdscript
static func register_all(registry) -> void:
    # ... existing icons ...
    
    # ========================================
    # KITCHEN PIPELINE ICONS
    # ========================================
    
    # FLOUR (💨) - Produced by Mill, consumed by Kitchen
    var flour = Icon.new()
    flour.emoji = "💨"
    flour.display_name = "Flour"
    flour.description = "Ground wheat, ready for baking"
    flour.trophic_level = 1
    flour.tags = ["ingredient", "processed", "kitchen"]
    
    # Flour couples to wheat (Hamiltonian rotation)
    flour.hamiltonian_couplings = {
        "🌾": 0.25  # Symmetric: wheat ↔ flour oscillation
    }
    
    # Flour can be drained by taps
    flour.is_drain_target = true
    flour.drain_to_sink_rate = 0.05
    
    # Register allocation
    flour.allocates_register = true
    flour.register_north_emoji = "💨"
    flour.register_south_emoji = "🌾"  # Unground wheat
    
    registry.register_icon(flour)
    
    # ----------------------------------------
    
    # FIRE (🔥) - Heat source in Kitchen
    var fire = Icon.new()
    fire.emoji = "🔥"
    fire.display_name = "Fire"
    fire.description = "Heat for cooking"
    fire.trophic_level = 0
    fire.tags = ["abiotic", "energy", "kitchen"]
    fire.is_driver = true
    
    # Fire naturally decays to cold (entropy)
    fire.lindblad_outgoing = {
        "❄️": 0.02  # Slow cooling
    }
    
    # Fire can be drained/tapped
    fire.is_drain_target = true
    fire.drain_to_sink_rate = 0.05
    
    # Register allocation
    fire.allocates_register = true
    fire.register_north_emoji = "🔥"
    fire.register_south_emoji = "❄️"
    
    registry.register_icon(fire)
    
    # ----------------------------------------
    
    # WATER (💧) - Moisture in Kitchen
    var water = Icon.new()
    water.emoji = "💧"
    water.display_name = "Water"
    water.description = "Moisture for dough"
    water.trophic_level = 0
    water.tags = ["abiotic", "ingredient", "kitchen"]
    
    # Water naturally evaporates
    water.lindblad_outgoing = {
        "🏜️": 0.015  # Slow evaporation
    }
    
    # Water can be drained/tapped
    water.is_drain_target = true
    water.drain_to_sink_rate = 0.05
    
    # Register allocation
    water.allocates_register = true
    water.register_north_emoji = "💧"
    water.register_south_emoji = "🏜️"
    
    registry.register_icon(water)
    
    # ----------------------------------------
    
    # BREAD (🍞) - The 3-qubit Bell state outcome
    var bread = Icon.new()
    bread.emoji = "🍞"
    bread.display_name = "Bread"
    bread.description = "Baked from fire, water, and flour in harmony"
    bread.trophic_level = 2
    bread.tags = ["product", "food", "kitchen", "bell_state"]
    
    # THE KEY: Dynamic requirements for Gaussian-weighted Lindblad
    # Bread "emerges" when conditions are in the sweet spot
    bread.dynamic_requirements = {
        "🔥": {"ideal": 0.70, "sigma": 0.15},  # Hot (60-80% fire)
        "💧": {"ideal": 0.40, "sigma": 0.20},  # Damp (20-60% water)
        "💨": {"ideal": 0.50, "sigma": 0.15}   # Floury (35-65% flour)
    }
    
    # Bread pulls from all three input states
    # Rate is multiplied by Gaussian Ω from requirements
    bread.lindblad_incoming = {
        "🔥": 0.08,
        "💧": 0.08,
        "💨": 0.08
    }
    
    # Bread can be harvested (drained to economy)
    bread.is_drain_target = true
    bread.drain_to_sink_rate = 0.1
    
    # Bread is eternal once formed (doesn't decay back)
    bread.is_eternal = true
    
    # Register allocation
    bread.allocates_register = true
    bread.register_north_emoji = "🍞"
    bread.register_south_emoji = "💀"  # Burnt/failed
    
    # Bread requires all three inputs to exist
    bread.co_injected_icons = ["🔥", "💧", "💨"]
    
    registry.register_icon(bread)
```

---

## Part 3: QuantumBath Gaussian Multiplier

### 3.1 Add Population Query Method

Add to `Core/QuantumSubstrate/QuantumBath.gd`:

```gdscript
## Get the population (probability) of an emoji in the bath
## Returns the diagonal element of the density matrix for this basis state
func get_population(emoji: String) -> float:
    """Query P(emoji) from the density matrix.
    
    This is the probability of measuring the bath in the state
    where `emoji` is in its 'north' (present) state.
    
    Returns: float in [0, 1]
    """
    if not _density_matrix:
        return 0.0
    
    # Find the index for this emoji
    var idx = -1
    for i in range(active_icons.size()):
        if active_icons[i].emoji == emoji:
            idx = i
            break
    
    if idx < 0:
        return 0.0
    
    # For a factorized bath, get the marginal probability
    # For now, use simplified diagonal access
    # TODO: Proper partial trace for entangled systems
    
    # Get probability from density matrix diagonal
    # In computational basis, P(emoji=north) = sum of diagonals where qubit_i = 0
    var prob = 0.0
    var dim = _density_matrix.dimension()
    var num_qubits = int(log(dim) / log(2))
    
    for basis_idx in range(dim):
        # Check if qubit at position `idx` is in |0⟩ (north) state
        var qubit_state = (basis_idx >> (num_qubits - 1 - idx)) & 1
        if qubit_state == 0:
            prob += _density_matrix.get_element(basis_idx, basis_idx).real
    
    return clamp(prob, 0.0, 1.0)
```

### 3.2 Add Gaussian Multiplier Computation

Add to `Core/QuantumSubstrate/QuantumBath.gd`:

```gdscript
## Compute the Gaussian "sweet spot" multiplier for an Icon's dynamic requirements
## Returns: float in [0, 1], where 1.0 = all conditions ideal
func compute_requirement_multiplier(icon: Icon) -> float:
    """Compute Ω = ∏_i exp(-(P_i - μ_i)² / (2σ_i²))
    
    This multiplier scales the Icon's Lindblad incoming rates.
    When populations match ideal values, Ω → 1.0
    When populations deviate, Ω → 0.0
    """
    if icon.dynamic_requirements.is_empty():
        return 1.0
    
    var omega = 1.0
    
    for req_emoji in icon.dynamic_requirements:
        var p = get_population(req_emoji)
        var req = icon.dynamic_requirements[req_emoji]
        
        var ideal = req.get("ideal", 0.5)
        var sigma = req.get("sigma", 0.2)
        
        # Gaussian: peaks at ideal, falls off with distance
        var deviation = p - ideal
        var gaussian = exp(-pow(deviation, 2) / (2 * pow(sigma, 2)))
        
        omega *= gaussian
    
    # Debug output (disable in production)
    if omega > 0.01:
        print("  🎯 %s requirement Ω = %.3f" % [icon.emoji, omega])
    
    return omega
```

### 3.3 Modify Lindblad Builder to Use Multiplier

Update the `build_lindblad_from_icons()` method in `QuantumBath.gd`:

```gdscript
func build_lindblad_from_icons(icons: Array) -> void:
    """Build Lindblad superoperator from Icon transfer rates.
    
    For Icons with dynamic_requirements, the incoming rates are
    multiplied by the Gaussian requirement multiplier Ω.
    """
    # ... existing initialization code ...
    
    for icon in icons:
        # Compute requirement multiplier for this icon
        var omega = compute_requirement_multiplier(icon)
        
        # Process outgoing transfers (unmodified)
        for target_emoji in icon.lindblad_outgoing:
            var rate = icon.lindblad_outgoing[target_emoji]
            _add_lindblad_term(icon.emoji, target_emoji, rate)
        
        # Process incoming transfers (scaled by omega)
        for source_emoji in icon.lindblad_incoming:
            var base_rate = icon.lindblad_incoming[source_emoji]
            var effective_rate = base_rate * omega  # KEY: Apply Gaussian multiplier
            
            if effective_rate > 0.001:  # Skip negligible rates
                _add_lindblad_term(source_emoji, icon.emoji, effective_rate)
    
    # ... existing finalization code ...
```

---

## Part 4: Icon Injection System

### 4.1 Add Injection Method to BiomeBase

Add to `Core/Environment/BiomeBase.gd`:

```gdscript
## Inject an Icon into this biome's quantum bath
## This expands the Hilbert space and enables the Icon's physics
func inject_icon(icon: Icon) -> bool:
    """Inject an Icon into the biome, expanding quantum state if needed.
    
    Process:
    1. Check if Icon already active (skip if so)
    2. Allocate quantum register if Icon requires it
    3. Add Icon to active_icons
    4. Co-inject any dependent Icons
    5. Rebuild Hamiltonian and Lindblad operators
    
    Returns: true if injection succeeded
    """
    if not icon:
        push_error("Cannot inject null Icon!")
        return false
    
    if not bath:
        push_error("Biome %s has no bath!" % get_biome_type())
        return false
    
    # Check if already active
    for active_icon in bath.active_icons:
        if active_icon.emoji == icon.emoji:
            print("  ℹ️ Icon %s already active in %s" % [icon.emoji, get_biome_type()])
            return true
    
    print("💉 Injecting Icon %s into %s biome" % [icon.emoji, get_biome_type()])
    
    # Allocate quantum register if needed
    if icon.allocates_register:
        var basis = icon.get_register_basis()
        var reg_id = quantum_computer.allocate_register(basis["north"], basis["south"])
        print("  📊 Allocated register %d for %s (%s/%s)" % [
            reg_id, icon.emoji, basis["north"], basis["south"]
        ])
    
    # Add to active icons
    bath.active_icons.append(icon)
    
    # Co-inject dependencies
    for dep_emoji in icon.co_injected_icons:
        var dep_icon = IconRegistry.get_icon(dep_emoji)
        if dep_icon:
            inject_icon(dep_icon)  # Recursive injection
        else:
            push_warning("Co-injection failed: Icon %s not in registry" % dep_emoji)
    
    # Rebuild operators with new Icon
    bath.build_hamiltonian_from_icons(bath.active_icons)
    bath.build_lindblad_from_icons(bath.active_icons)
    
    print("  ✅ Icon %s active in %s" % [icon.emoji, get_biome_type()])
    return true


## Pump population into an Icon's register (classical → quantum injection)
## Used when player "adds" resources to a biome (e.g., flour to kitchen)
func pump_icon_population(emoji: String, amount: float) -> bool:
    """Increase the population of an Icon's north state.
    
    This is how classical resources (from economy) get converted
    into quantum amplitude in the biome.
    
    Args:
        emoji: Target Icon emoji
        amount: Population to add (0.0 to 1.0 scale)
    
    Returns: true if pump succeeded
    """
    # Find the Icon's register
    var reg_id = -1
    for i in range(bath.active_icons.size()):
        if bath.active_icons[i].emoji == emoji:
            reg_id = i
            break
    
    if reg_id < 0:
        push_warning("Cannot pump %s - not active in biome" % emoji)
        return false
    
    # Get component and apply amplitude boost
    var comp = quantum_computer.get_component_containing(reg_id)
    if not comp:
        return false
    
    # Apply population pump via density matrix manipulation
    # This is a non-unitary operation (injection from classical world)
    # TODO: Implement proper amplitude injection in QuantumComponent
    
    print("💨 Pumped %.2f into %s population" % [amount, emoji])
    return true
```

---

## Part 5: Mill Simplification

### 5.1 Replace QuantumMill Measurement Loop

Rewrite `Core/GameMechanics/QuantumMill.gd`:

```gdscript
class_name QuantumMill
extends Node2D

## Quantum Mill - Icon Injection Portal
##
## NEW MODEL: Mill is NOT a measurement device.
## Mill INJECTS the Flour Icon (💨) into its parent biome.
## The Flour Icon's Hamiltonian coupling to Wheat (🌾) causes
## population to oscillate between wheat and flour.
## Player extracts flour via Energy Taps.

# Configuration
var grid_position: Vector2i = Vector2i.ZERO
var parent_biome = null
var is_active: bool = false

# Reference to FarmGrid (for economy routing)
var farm_grid = null


func _ready():
    print("🏭 QuantumMill initialized at %s" % grid_position)


func activate(biome) -> bool:
    """Activate the mill by injecting Flour Icon into biome.
    
    Called when mill is placed on the grid.
    """
    parent_biome = biome
    
    if not parent_biome:
        push_error("Mill has no parent biome!")
        return false
    
    # Get Flour Icon from registry
    var flour_icon = IconRegistry.get_icon("💨")
    if not flour_icon:
        push_error("Flour Icon (💨) not in registry!")
        return false
    
    # Inject into biome - this enables wheat↔flour dynamics
    var success = parent_biome.inject_icon(flour_icon)
    
    if success:
        is_active = true
        print("🏭 Mill activated: Flour dynamics enabled in %s" % parent_biome.get_biome_type())
    
    return success


func _process(_delta: float):
    # Mill does NOT process anything!
    # Physics happens in the biome bath evolution.
    # Player extracts flour via taps.
    pass


func get_debug_info() -> Dictionary:
    """Return mill state for debugging"""
    return {
        "position": grid_position,
        "is_active": is_active,
        "parent_biome": parent_biome.get_biome_type() if parent_biome else "none"
    }
```

### 5.2 Update FarmGrid Mill Placement

In `Core/GameMechanics/FarmGrid.gd`, update `place_mill()`:

```gdscript
func place_mill(position: Vector2i) -> bool:
    """Place a mill at the given position.
    
    NEW MODEL: Mill injects Flour Icon into biome.
    No measurement loop. Player uses taps to extract flour.
    """
    var plot = get_plot(position)
    if plot == null:
        return false
    
    if plot.is_planted or plot.plot_type != FarmPlot.PlotType.EMPTY:
        push_warning("Cannot place mill on occupied plot!")
        return false
    
    # Mark plot as mill
    plot.plot_type = FarmPlot.PlotType.MILL
    plot.is_planted = true  # Occupied
    
    # Create mill object
    var mill = QuantumMill.new()
    mill.grid_position = position
    mill.farm_grid = self
    
    # Get parent biome and activate mill
    var parent_biome = get_biome_for_plot(position)
    mill.activate(parent_biome)
    
    # Store in registry
    quantum_mills[position] = mill
    
    print("🏭 Mill placed at %s" % position)
    plot_planted.emit(position)
    
    return true
```

### 5.3 Remove Mill Processing Loop

In `FarmGrid._process_quantum_mills()`, simplify to:

```gdscript
func _process_quantum_mills(_delta: float) -> void:
    """Process quantum mills - DEPRECATED.
    
    Mills no longer run measurement loops.
    Flour extraction happens via Energy Taps.
    This method kept for compatibility but does nothing.
    """
    pass  # Mills are passive Icon injectors now
```

---

## Part 6: Energy Tap Fix

### 6.1 Remove is_planted Check

In `UI/FarmInputHandler.gd`, fix `_action_place_energy_tap_for()`:

```gdscript
func _action_place_energy_tap_for(positions: Array[Vector2i], target_emoji: String):
    """Place energy tap targeting specific emoji (Model B)
    
    FIXED: Removed is_planted check. Taps can be placed on any plot.
    The tap creates a Lindblad drain on the biome for target_emoji.
    """
    if not farm or not farm.grid:
        action_performed.emit("place_energy_tap", false, "⚠️  Farm not loaded yet")
        return
    
    if positions.is_empty():
        action_performed.emit("place_energy_tap", false, "⚠️  No plots selected")
        return
    
    print("💧 Placing energy taps targeting %s on %d plots..." % [target_emoji, positions.size()])
    
    var success_count = 0
    
    for pos in positions:
        var plot = farm.grid.get_plot(pos)
        if not plot:
            continue
        
        # REMOVED: is_planted check - taps don't need planted plots!
        # Taps operate on biome bath, not on plot quantum state
        
        # Get the biome and place energy tap
        var biome = farm.grid.get_biome_for_plot(pos)
        if not biome:
            continue
        
        # Check if target emoji exists in biome
        var has_emoji = false
        if biome.bath:
            for icon in biome.bath.active_icons:
                if icon.emoji == target_emoji:
                    has_emoji = true
                    break
        
        if not has_emoji:
            print("  ⚠️ Emoji %s not active in %s - injecting first" % [target_emoji, biome.get_biome_type()])
            var icon = IconRegistry.get_icon(target_emoji)
            if icon:
                biome.inject_icon(icon)
                has_emoji = true
        
        if has_emoji and biome.place_energy_tap(target_emoji, 0.05):
            # Mark plot as tap (optional visual)
            plot.plot_type = FarmPlot.PlotType.ENERGY_TAP
            plot.tap_target_emoji = target_emoji
            success_count += 1
            print("  💧 Tap on %s placed at %s" % [target_emoji, pos])
    
    action_performed.emit("place_energy_tap", success_count > 0,
        "%s Placed %d energy taps targeting %s" % ["✅" if success_count > 0 else "❌", success_count, target_emoji])
```

---

## Part 7: Kitchen as 8D Bell State System

### 7.1 Initialize Kitchen Biome with 3 Qubits

In `Core/Environment/QuantumKitchen_Biome.gd`, update `_initialize_bath()`:

```gdscript
func _initialize_bath() -> void:
    """Initialize the Kitchen as a 3-qubit (8D) quantum system.
    
    The Kitchen contains exactly 3 registers:
      Register 0: Fire (🔥/❄️)
      Register 1: Water (💧/🏜️)
      Register 2: Flour (💨/🌾)
    
    Bread (🍞) emerges through Gaussian-weighted Lindblad dynamics
    when fire, water, and flour populations are in the "sweet spot."
    """
    # Create bath with 3-qubit capacity
    bath = QuantumBath.new()
    bath.biome_name = "Kitchen"
    
    # Inject the three input Icons
    var fire_icon = IconRegistry.get_icon("🔥")
    var water_icon = IconRegistry.get_icon("💧")
    var flour_icon = IconRegistry.get_icon("💨")
    
    # Inject in order (creates 3 registers)
    inject_icon(fire_icon)   # Register 0
    inject_icon(water_icon)  # Register 1
    inject_icon(flour_icon)  # Register 2
    
    # Inject Bread Icon (the output with dynamic_requirements)
    var bread_icon = IconRegistry.get_icon("🍞")
    inject_icon(bread_icon)  # Adds Lindblad terms, uses existing registers
    
    # At this point:
    # - Hilbert space is 2³ = 8 dimensional
    # - Density matrix is 8×8
    # - Bread Lindblad incoming rate is scaled by Gaussian Ω
    
    print("🍳 Kitchen initialized: 8D quantum state (Fire/Water/Flour → Bread)")
    
    # Set visual properties
    visual_label = "🍳 Kitchen"
    visual_color = Color(0.9, 0.6, 0.3, 0.3)  # Warm orange


func get_biome_type() -> String:
    return "Kitchen"
```

### 7.2 Simplify Kitchen Processing in FarmGrid

Update `FarmGrid._process_kitchens()`:

```gdscript
func _process_kitchens(_delta: float) -> void:
    """Process kitchen buildings - SIMPLIFIED.
    
    NEW MODEL: Kitchen physics happens automatically via bath evolution.
    The Bread Icon's Gaussian requirements control when bread forms.
    Player harvests when ready.
    
    This method now only handles:
    1. Checking if player wants to "pump" ingredients into kitchen
    2. Visual feedback updates
    """
    # Kitchen evolution happens in the Kitchen biome's bath.evolve()
    # which is called by the biome's _process()
    
    # Player interaction (pumping ingredients) is handled separately
    # via UI actions that call kitchen_biome.pump_icon_population()
    
    pass  # Evolution is automatic
```

### 7.3 Add Kitchen Harvest (Measurement)

Add method to handle player-triggered measurement:

```gdscript
func harvest_kitchen(position: Vector2i) -> Dictionary:
    """Harvest (measure) the kitchen's 3-qubit state.
    
    This is a projective measurement in the computational basis.
    Outcome probabilities determined by current density matrix.
    
    Returns: {success: bool, outcome: String, bread_amount: int}
    """
    var plot = get_plot(position)
    if not plot or plot.plot_type != FarmPlot.PlotType.KITCHEN:
        return {"success": false, "outcome": "", "bread_amount": 0}
    
    var kitchen_biome = biomes.get("Kitchen")
    if not kitchen_biome:
        return {"success": false, "outcome": "", "bread_amount": 0}
    
    # Get bread population before measurement
    var bread_prob = kitchen_biome.bath.get_population("🍞")
    
    # Perform projective measurement
    # Collapse to |bread⟩ with probability bread_prob
    var roll = randf()
    
    if roll < bread_prob:
        # Success! Measured bread state
        var bread_amount = int(bread_prob * 100)  # Scale to game units
        
        # Reset kitchen state (collapsed, needs re-preparation)
        kitchen_biome.reset_to_ground_state()
        
        # Add to economy
        if farm_economy:
            var credits = bread_amount * FarmEconomy.QUANTUM_TO_CREDITS
            farm_economy.add_resource("🍞", credits, "kitchen_measurement")
        
        print("🍞 Kitchen harvest SUCCESS: %d bread (prob was %.2f)" % [bread_amount, bread_prob])
        return {"success": true, "outcome": "🍞", "bread_amount": bread_amount}
    else:
        # Failed measurement - collapsed to non-bread state
        kitchen_biome.reset_to_ground_state()
        
        print("💀 Kitchen harvest FAILED: collapsed to non-bread (prob was %.2f)" % bread_prob)
        return {"success": true, "outcome": "💀", "bread_amount": 0}
```

---

## Part 8: Player Interaction Flow

### 8.1 Pumping Resources into Kitchen

When player "adds" flour to kitchen (from economy):

```gdscript
# In FarmInputHandler or dedicated UI
func pump_resource_to_kitchen(emoji: String, amount: float) -> bool:
    """Transfer resource from economy to kitchen quantum state.
    
    This is how classical flour becomes quantum flour in the kitchen.
    """
    var kitchen_biome = farm.grid.biomes.get("Kitchen")
    if not kitchen_biome:
        return false
    
    # Check economy has resource
    var available = farm.grid.farm_economy.get_resource(emoji)
    var cost = int(amount * 100)  # Convert to credits
    
    if available < cost:
        print("⚠️ Not enough %s in economy (have %d, need %d)" % [emoji, available, cost])
        return false
    
    # Deduct from economy
    farm.grid.farm_economy.remove_resource(emoji, cost, "kitchen_pump")
    
    # Pump into kitchen
    kitchen_biome.pump_icon_population(emoji, amount)
    
    print("💨 Pumped %s into kitchen (%.2f population)" % [emoji, amount])
    return true
```

### 8.2 Complete Player Flow

```
FULL KITCHEN GAMEPLAY LOOP:

1. PLANT WHEAT (BioticFlux)
   - Player: Select plot → Plant wheat
   - System: Allocates 🌾 register in BioticFlux quantum_computer
   - Physics: Wheat evolves under biome Hamiltonian

2. PLACE MILL (BioticFlux)
   - Player: Select plot → Place mill
   - System: Injects 💨 Icon into BioticFlux bath
   - Physics: Hamiltonian coupling 🌾↔💨 enables population oscillation

3. PLACE TAP ON FLOUR (BioticFlux)
   - Player: Select plot → Energy Tap → Flour
   - System: Creates Lindblad drain L = √κ |⬇️⟩⟨💨|
   - Physics: Flour population drains to economy over time

4. PUMP FLOUR TO KITCHEN
   - Player: UI action → Transfer flour to kitchen
   - System: Deducts economy credits, pumps 💨 population in Kitchen bath
   - Physics: Kitchen's flour register amplitude increases

5. PUMP FIRE TO KITCHEN
   - Player: UI action → Transfer fire to kitchen
   - System: Same as above for 🔥

6. PUMP WATER TO KITCHEN
   - Player: UI action → Transfer water to kitchen
   - System: Same as above for 💧

7. WATCH BREAD PROBABILITY GROW
   - Physics: Gaussian Ω computed each frame
   - If 🔥≈0.7, 💧≈0.4, 💨≈0.5 → Ω≈1.0 → bread Lindblad rate high
   - Bread population grows toward |🍞⟩ state
   - UI: Shows "Bread readiness" meter based on get_population("🍞")

8. HARVEST KITCHEN
   - Player: Select kitchen → Harvest
   - System: Projective measurement of 8D state
   - Outcome: |🍞⟩ with prob = bread_population, else |💀⟩
   - Success: Bread credits added to economy

9. REPEAT / OPTIMIZE
   - Player experiments with different fire/water/flour ratios
   - Discovers the "sweet spot" empirically
   - Optimizes for maximum bread output
```

---

## Part 9: Validation Tests

### 9.1 Test: Mill Injects Flour Icon

```gdscript
func test_mill_injects_flour():
    # Place mill
    farm.grid.place_mill(Vector2i(1, 0))
    
    # Check flour icon is active in BioticFlux
    var biome = farm.grid.get_biome_for_plot(Vector2i(1, 0))
    var has_flour = false
    for icon in biome.bath.active_icons:
        if icon.emoji == "💨":
            has_flour = true
            break
    
    assert(has_flour, "Mill should inject flour icon!")
    print("✅ Mill injection test passed")
```

### 9.2 Test: Gaussian Multiplier Computation

```gdscript
func test_gaussian_multiplier():
    var kitchen = farm.grid.biomes.get("Kitchen")
    var bread_icon = IconRegistry.get_icon("🍞")
    
    # Set ideal conditions
    kitchen.bath.set_test_population("🔥", 0.70)
    kitchen.bath.set_test_population("💧", 0.40)
    kitchen.bath.set_test_population("💨", 0.50)
    
    var omega = kitchen.bath.compute_requirement_multiplier(bread_icon)
    assert(omega > 0.9, "Omega should be ~1.0 at ideal conditions!")
    
    # Set bad conditions
    kitchen.bath.set_test_population("🔥", 0.1)  # Too cold
    omega = kitchen.bath.compute_requirement_multiplier(bread_icon)
    assert(omega < 0.1, "Omega should be low when conditions wrong!")
    
    print("✅ Gaussian multiplier test passed")
```

### 9.3 Test: Full Kitchen Pipeline

```gdscript
func test_full_kitchen_pipeline():
    # 1. Plant wheat
    farm.grid.plant_wheat(Vector2i(0, 0))
    
    # 2. Place mill (injects flour)
    farm.grid.place_mill(Vector2i(1, 0))
    
    # 3. Place tap on flour
    farm.grid.place_energy_tap(Vector2i(2, 0), "💨")
    
    # 4. Evolve biome (flour drains to economy)
    for i in range(100):
        farm.grid.biomes["BioticFlux"].advance_simulation(0.1)
    
    # 5. Check economy has flour
    var flour_credits = farm.grid.farm_economy.get_resource("💨")
    assert(flour_credits > 0, "Should have flour in economy!")
    
    # 6. Pump resources to kitchen
    var kitchen = farm.grid.biomes.get("Kitchen")
    kitchen.pump_icon_population("🔥", 0.7)
    kitchen.pump_icon_population("💧", 0.4)
    kitchen.pump_icon_population("💨", 0.5)
    
    # 7. Evolve kitchen (bread should form)
    for i in range(100):
        kitchen.advance_simulation(0.1)
    
    # 8. Check bread population
    var bread_pop = kitchen.bath.get_population("🍞")
    assert(bread_pop > 0.3, "Bread should have formed!")
    
    print("✅ Full kitchen pipeline test passed")
```

---

## Part 10: Migration Checklist

### Files to Modify

- [ ] `Core/QuantumSubstrate/Icon.gd` - Add dynamic_requirements, injection fields
- [ ] `Core/Icons/CoreIcons.gd` - Define Flour, Fire, Water, Bread Icons
- [ ] `Core/QuantumSubstrate/QuantumBath.gd` - Add get_population(), compute_requirement_multiplier(), update build_lindblad_from_icons()
- [ ] `Core/Environment/BiomeBase.gd` - Add inject_icon(), pump_icon_population()
- [ ] `Core/GameMechanics/QuantumMill.gd` - Replace with Icon injection
- [ ] `Core/GameMechanics/FarmGrid.gd` - Update place_mill(), _process_quantum_mills(), _process_kitchens(), add harvest_kitchen()
- [ ] `UI/FarmInputHandler.gd` - Fix energy tap is_planted check
- [ ] `Core/Environment/QuantumKitchen_Biome.gd` - Initialize as 3-qubit system

### Files to Create (Optional)

- [ ] `Core/GameMechanics/KitchenUI.gd` - UI for pumping resources, watching bread meter
- [ ] `Tests/test_kitchen_pipeline.gd` - Automated pipeline tests

### Deprecated/Remove

- [ ] QuantumMill measurement loop (replaced with Icon injection)
- [ ] FarmGrid._process_kitchens() hard-coded Bell state creation
- [ ] DualEmojiQubit usage in kitchen (replaced with density matrix)

---

## Summary

This directive transforms SpaceWheat into a true **analog quantum gardening** simulation where:

1. **Icons are physics** - All dynamics encoded in Icon resources
2. **Buildings are portals** - Mill/Kitchen inject Icons, don't run logic
3. **Player tends conditions** - Adjusts populations to hit sweet spots
4. **Hamiltonian does work** - Gaussian-weighted Lindblad flows toward bread
5. **Player chooses measurement** - Harvests when probability is favorable
6. **Discovery is gameplay** - Finding the sweet spots IS the game

The kitchen produces bread through genuine 8D quantum dynamics, not hard-coded triggers.

**Ready for implementation.**
