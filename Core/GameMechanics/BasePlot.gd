class_name BasePlot
extends Resource

## BasePlot - Foundation class for all farm plots (Model C)
##
## Model C: Plot is a MEASUREMENT BASIS on a biome's QuantumComputer.
## Does NOT own quantum state - only tracks which register to measure.
##
## OLD (Model B): Plot referenced QuantumComputer register (digital/discrete)
## NEW (Model C): Plot references QuantumBath measurement axis (analog/continuous)

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")


## Safely log via VerboseConfig (Resource can't use @onready)
func _log(level: String, category: String, emoji: String, message: String) -> void:
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		return
	var verbose = tree.root.get_node_or_null("/root/VerboseConfig")
	if not verbose:
		return
	match level:
		"info":
			verbose.info(category, emoji, message)
		"debug":
			verbose.debug(category, emoji, message)
		"warn":
			verbose.warn(category, emoji, message)

signal growth_complete
signal state_collapsed(final_state: String)

# ============================================================================
# MODEL C: Bath Measurement Axis (NOT Independent Quantum State)
# ============================================================================

# Plot identification
@export var plot_id: String = ""
@export var grid_position: Vector2i = Vector2i.ZERO

# Model C: Quantum register reference (which register in biome's quantum computer)
# NEW: register_id identifies which qubit in biome's QuantumComputer holds this plot's state
@export var register_id: int = -1  # QuantumComputer register ID (-1 = not planted)
var parent_biome: Node = null  # Reference to BiomeBase that owns quantum computer

# Measurement basis labels (defines which qubit axis to measure)
@export var north_emoji: String = "🌾"
@export var south_emoji: String = "🌽"

# Plot metadata (NOT quantum state)
@export var is_planted: bool = false
@export var has_been_measured: bool = false  # DEPRECATED: use is_measured() for v2 terminals
@export var theta_frozen: bool = false  # Measurement locked the theta value (stops Hamiltonian drift)
@export var measured_outcome: String = ""  # Measurement result ("north", "south", or empty)

# V2 Architecture: Reference to bound terminal (when using terminal-based binding)
# When bound_terminal is set, query it for is_measured, emoji_pair, etc.
var bound_terminal = null  # Terminal instance

# Conspiracy network connection
@export var conspiracy_node_id: String = ""
@export var conspiracy_bond_strength: float = 0.0

# Berry phase accumulator (plot memory)
@export var replant_cycles: int = 0
@export var berry_phase: float = 0.0

# Entanglement tracking (updated via parent_biome quantum computer)
var entangled_plots: Dictionary = {}  # plot_id -> strength
var plot_infrastructure_entanglements: Array[Vector2i] = []
const MAX_ENTANGLEMENTS = 3

# Persistent gate infrastructure (survives harvest/replant)
var persistent_gates: Array[Dictionary] = []


func _init():
	plot_id = "plot_%d" % randi()


# ============================================================================
# MODEL C: Quantum State Access (Computed from Parent Biome's Bath)
# ============================================================================

## Get current measurement outcome (or empty if unmeasured)
func get_measurement_outcome() -> String:
	return measured_outcome

## Get basis labels for this plot's measurement basis
func get_basis_labels() -> Array[String]:
	return [north_emoji, south_emoji]

## Get purity from parent biome's quantum computer
func get_purity() -> float:
	"""Query purity from parent biome's quantum computer.

	Model C: Purity is computed from the density matrix as Tr(ρ²).
	Returns 0 if plot not planted or no parent_biome.
	"""
	if not is_planted or not parent_biome:
		return 0.0

	if not parent_biome.quantum_computer:
		return 0.0

	return parent_biome.quantum_computer.get_purity()

## Get coherence from parent biome's quantum computer
func get_coherence() -> float:
	"""Query coherence from parent biome's quantum computer."""
	if not is_planted or not parent_biome:
		return 0.0

	if not parent_biome.quantum_computer:
		return 0.0

	# Coherence approximated from purity (off-diagonal elements)
	return parent_biome.quantum_computer.get_purity()

## Get mass (probability in subspace)
func get_mass() -> float:
	"""Get probability mass in measurement basis subspace."""
	if not is_planted or not parent_biome:
		return 0.0

	if not parent_biome.quantum_computer:
		return 0.0

	var p_north = parent_biome.quantum_computer.get_population(north_emoji)
	var p_south = parent_biome.quantum_computer.get_population(south_emoji)
	return p_north + p_south

## Core Methods

func get_dominant_emoji() -> String:
	"""Get the current outcome emoji (measured or measurement outcome)

	Model B: Returns measurement_outcome if measured, or basis label based on marginal.
	"""
	if has_been_measured and measured_outcome != "":
		return measured_outcome

	# If unmeasured, return dominant basis state based on purity
	# This is approximate - true outcome only known after measurement
	var p_north = get_purity() * 0.5  # Simplified; real impl queries marginal
	return north_emoji if (randf() < 0.5) else south_emoji


func get_plot_emojis() -> Dictionary:
	"""Get the dual-emoji pair for this plot type

	V2 Architecture: Delegates to bound_terminal when available.
	Falls back to legacy behavior for v1 compatibility.

	PHASE 5 (PARAMETRIC): Queries parent biome capabilities for emoji pair.
	Falls back to current north/south emojis if no biome or capability found.

	Subclasses can override to customize per-plot basis.
	"""
	# V2: If bound_terminal exists, delegate to it (single source of truth)
	if bound_terminal and bound_terminal.is_bound:
		return bound_terminal.get_emoji_pair()

	# PARAMETRIC: Query parent biome for capability if plot_type_name is set
	if parent_biome and parent_biome.has_method("get_plantable_capabilities"):
		# Get plot_type_name from subclass (FarmPlot has this property)
		var type_name = get("plot_type_name")
		if type_name:
			# Find capability matching plot_type_name
			for cap in parent_biome.get_plantable_capabilities():
				if cap.plant_type == type_name:
					return cap.emoji_pair

	# Fallback: Return current basis labels (set during planting)
	return {"north": north_emoji, "south": south_emoji}


## V2 computed property: is this plot measured?
## Delegates to bound_terminal when available, falls back to has_been_measured
func is_measured() -> bool:
	if bound_terminal:
		return bound_terminal.is_measured
	return has_been_measured


## V2 computed property: is this plot occupied (bound to a terminal)?
## For v2 architecture, a plot is "occupied" if it has a bound terminal
func is_occupied() -> bool:
	return bound_terminal != null and bound_terminal.is_bound


func register_in_biome(biome: Node) -> bool:
	"""Register this plot's measurement axis in the biome's quantum computer.

	Called by FarmGrid.plant() after emoji pairs are set.
	Assumes north_emoji and south_emoji are already configured.

	Args:
		biome: BiomeBase with quantum_computer

	Returns:
		true if successful, false if failed
	"""
	if not biome or not "quantum_computer" in biome or not biome.quantum_computer:
		push_error("Biome has no quantum_computer for plot %s!" % grid_position)
		return false

	parent_biome = biome

	# Get register_id - axis should already exist from expand_quantum_system
	if biome.quantum_computer.register_map.has(north_emoji):
		register_id = biome.quantum_computer.register_map.qubit(north_emoji)
	else:
		push_error("Axis %s/%s not found in quantum computer - was expand_quantum_system called?" % [
			north_emoji, south_emoji])
		return false

	is_planted = true
	has_been_measured = false
	measured_outcome = ""

	_log("debug", "farm", "🌱", "Plot %s: registered axis %d (%s/%s) in %s" % [
		grid_position, register_id, north_emoji, south_emoji, biome.get_biome_type()])
	return true


func measure(_icon_network = null) -> String:
	"""Measure (collapse) quantum state at this plot

	Model C: Delegates to parent_biome's quantum_computer.measure_axis() for measurement.

	Returns: The measurement outcome emoji (north_emoji or south_emoji)
	Sets: has_been_measured = true and measured_outcome on success
	"""
	if not parent_biome:
		push_error("Plot %s not properly planted - no parent biome!" % grid_position)
		return ""

	if not is_planted:
		push_error("Cannot measure unplanted plot!")
		return ""

	if has_been_measured:
		push_warning("Plot %s already measured - outcome: %s" % [grid_position, measured_outcome])
		if measured_outcome == north_emoji:
			return "north"
		elif measured_outcome == south_emoji:
			return "south"
		return measured_outcome

	if not parent_biome.quantum_computer:
		push_error("Parent biome %s has no quantum_computer!" % parent_biome.get_biome_type())
		return ""

	# Measure north/south axis using quantum_computer
	var outcome_emoji = parent_biome.quantum_computer.measure_axis(north_emoji, south_emoji)

	if outcome_emoji == "":
		push_error("Measurement failed for plot %s!" % grid_position)
		return ""

	# Convert emoji outcome to basis name for internal storage
	var basis_outcome = "north" if outcome_emoji == north_emoji else "south"

	# Record outcome
	has_been_measured = true
	measured_outcome = basis_outcome

	_log("debug", "farm", "🔬", "Plot %s measured: outcome=%s (emoji: %s)" % [grid_position, basis_outcome, outcome_emoji])

	return basis_outcome


func harvest() -> Dictionary:
	"""Harvest this plot - collect yield and clear quantum state

	Model C: Queries purity from parent_biome's quantum_computer.

	Manifest Section 4.4: Harvest follows Gozouta protocol:
	- If POSTSELECT_COSTED enabled: cost = 1/P(subspace), yield *= (1/cost)
	- If INSPECTOR mode: use old formula (backward compatible)

	Returns: Dictionary with:
		- success: bool
		- outcome: String (emoji)
		- energy: float (raw quantum energy for credits calculation)
		- yield: int (credits)
		- measurement_cost: float (POSTSELECT_COSTED mode only)
	"""
	if not is_planted or not parent_biome:
		return {"success": false, "yield": 0, "energy": 0.0}

	# Get quantum rigor config
	var config = QuantumRigorConfig.instance
	var use_costed_model = config and config.selective_measure_model == QuantumRigorConfig.SelectiveMeasureModel.POSTSELECT_COSTED

	var outcome = ""
	var measurement_cost = 1.0

	# Auto-measure if not already measured
	if not has_been_measured:
		measure()

	# Double-check measurement succeeded
	if not has_been_measured:
		return {"success": false, "yield": 0, "energy": 0.0}

	# Map basis outcome to emoji (measured_outcome is basis name "north" or "south")
	if measured_outcome == "north":
		outcome = north_emoji
	elif measured_outcome == "south":
		outcome = south_emoji
	else:
		outcome = "?"

	var purity = get_purity()
	if purity == 0.0:
		purity = 1.0  # Default to pure if no quantum state access

	# Purity multiplier for yield:
	# - Pure state (Tr(ρ²) = 1.0) → 2.0× yield
	# - Mixed state (Tr(ρ²) = 0.5) → 1.0× yield
	# - Maximally mixed (Tr(ρ²) ≈ 0.17) → 0.34× yield
	var purity_multiplier = 2.0 * purity

	# Base yield: 10 credits if measurement succeeded
	# (Manifest Section 4.4: outcome-based, not radius-based)
	var base_yield = 10.0

	# Apply purity multiplier
	var yield_with_purity = base_yield * purity_multiplier

	# Apply measurement cost penalty (Manifest Section 4.3)
	# POSTSELECT_COSTED: yield *= (1/cost)
	# INSPECTOR: cost = 1.0, so no penalty
	var yield_amount = max(1, int(yield_with_purity / measurement_cost))

	# Clear the plot
	is_planted = false
	register_id = -1
	has_been_measured = false
	measured_outcome = ""  # Clear stored outcome
	replant_cycles += 1

	# OLD (Model B): Remove register from parent biome
	# if parent_biome and parent_biome.has_method("clear_register_for_plot"):
	# 	parent_biome.clear_register_for_plot(grid_position)

	# NEW (Model C): Clear subplot from parent biome (if method exists)
	if parent_biome and parent_biome.has_method("clear_subplot_for_plot"):
		parent_biome.clear_subplot_for_plot(grid_position)
	# Note: Bath state persists - not cleared on individual plot harvest

	var result_dict = {
		"success": true,
		"outcome": outcome,
		"energy": base_yield,  # Legacy key - now represents base yield
		"yield": yield_amount,
		"purity": purity,  # Quantum state purity Tr(ρ²)
		"purity_multiplier": purity_multiplier  # Yield multiplier from purity
	}

	# Add measurement cost if using costed model
	if use_costed_model:
		result_dict["measurement_cost"] = measurement_cost

	_log("debug", "farm", "✂️", "Plot %s harvested: purity=%.3f (×%.2f), cost=%.2f/%.2f, outcome=%s, yield=%d" % [
		grid_position, purity, purity_multiplier, 1.0/measurement_cost, measurement_cost, outcome, yield_amount])

	return result_dict


func collapse_to_measurement(outcome: String) -> void:
	"""Collapse quantum state based on measurement outcome (Model B version)"""
	# Model B: Measurement collapse is handled by parent biome's quantum computer
	has_been_measured = true
	measured_outcome = outcome
	state_collapsed.emit(outcome)


func reset() -> void:
	"""Reset plot to initial unplanted state.
	Called after harvest or when clearing the plot.
	NOTE: persistent_gates is NOT cleared - infrastructure survives harvest."""
	is_planted = false
	has_been_measured = false
	measured_outcome = ""
	register_id = -1
	entangled_plots.clear()
	plot_infrastructure_entanglements.clear()
	conspiracy_node_id = ""
	conspiracy_bond_strength = 0.0
	# persistent_gates intentionally NOT cleared - survives harvest/replant


func remove_entanglement(partner_id: String) -> void:
	"""Remove entanglement with a specific plot.
	Called when breaking entanglement or when partner plot is harvested."""
	if entangled_plots.has(partner_id):
		entangled_plots.erase(partner_id)


# ============================================================================
# PERSISTENT GATE INFRASTRUCTURE
# ============================================================================

func add_persistent_gate(gate_type: String, linked_plots: Array[Vector2i] = []) -> void:
	"""Add a persistent gate to this plot. Gates survive harvest/replant."""
	persistent_gates.append({
		"type": gate_type,
		"active": true,
		"linked_plots": linked_plots.duplicate()
	})
	_log("debug", "farm", "🔧", "Added persistent gate '%s' to plot %s (linked: %d plots)" % [gate_type, grid_position, linked_plots.size()])


func clear_persistent_gates() -> void:
	"""Remove ALL persistent gate infrastructure from this plot."""
	var count = persistent_gates.size()
	persistent_gates.clear()
	if count > 0:
		_log("debug", "farm", "🔧", "Cleared %d persistent gates from plot %s" % [count, grid_position])


func has_active_gate(gate_type: String) -> bool:
	"""Check if this plot has an active gate of the specified type."""
	for gate in persistent_gates:
		if gate.get("type", "") == gate_type and gate.get("active", false):
			return true
	return false


func get_active_gates() -> Array[Dictionary]:
	"""Get all active persistent gates on this plot."""
	var active: Array[Dictionary] = []
	for gate in persistent_gates:
		if gate.get("active", false):
			active.append(gate)
	return active
