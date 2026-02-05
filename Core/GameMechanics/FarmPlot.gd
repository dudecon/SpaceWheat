class_name FarmPlot
extends "res://Core/GameMechanics/BasePlot.gd"

## FarmPlot - Player-interactive plots in the farm grid
## Base class for all plots the player can apply tools to
## Handles quantum evolution, entanglement, and generic plot mechanics
## Subclasses: WheatPlot (crops with constraints)

const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")

# Plot type
# DEPRECATED (Phase 5): Use plot_type_name instead of enum
# Enum kept for backward compatibility until Phase 6
enum PlotType { WHEAT, TOMATO, MUSHROOM, MILL, MARKET, KITCHEN, ENERGY_TAP, FIRE, WATER, FLOUR, VEGETATION, RABBIT, WOLF, BREAD }
@export var plot_type: PlotType = PlotType.WHEAT  # DEPRECATED - use plot_type_name

# PHASE 5 (PARAMETRIC): String-based plot type (replaces enum)
@export var plot_type_name: String = "wheat"

# Phase constraint (for plots that restrict Bloch sphere movement)
var phase_constraint: PhaseConstraint = null

# Quantum evolution parameters (can be overridden by subclasses)
var theta_drift_rate: float = 0.1
var theta_entangled_target: float = PI / 2.0  # Target for entangled (superposition)
var theta_isolated_target: float = 0.0  # Target for isolated (certain state)

# Harvest bonuses (for crops)
var entanglement_bonus: float = 0.20  # +20% yield per entangled neighbor
var berry_phase_bonus: float = 0.05  # +5% yield per replant cycle
var observer_penalty: float = 0.10  # -10% final yield if measured

# Energy tap configuration (only used if plot_type == ENERGY_TAP)
var tap_target_emoji: String = ""        # What emoji to tap (🌾, 💧, 👥, etc.)
var tap_theta: float = 3.0 * PI / 4.0   # Tap position: near south pole
var tap_phi: float = PI / 4.0            # Tap position: 45° off axis
var tap_accumulated_resource: float = 0.0  # Energy accumulated
var tap_base_rate: float = 0.5           # Base drain rate (legacy)
var tap_drain_rate: float = 0.1          # Drain rate κ (probability/sec) for Lindblad drain operators
var tap_last_flux_check: float = 0.0     # Timestamp of last flux read from bath


## Initialization


func _init():
	super._init()
	# FarmPlot-specific initialization (subclasses will override this)
	plot_type = PlotType.WHEAT  # DEPRECATED - kept for backward compatibility
	plot_type_name = "wheat"  # PHASE 5 (PARAMETRIC): String-based type


## Helper Functions


func get_plot_emojis() -> Dictionary:
	"""Get the dual-emoji pair for this plot type

	PHASE 5 (PARAMETRIC): Queries parent biome for emoji pair via plot_type_name.
	Delegates to BasePlot.get_plot_emojis() which queries biome capabilities.

	OLD (Hard-Coded): Match statement on PlotType enum
	NEW (Parametric): Query biome.get_plantable_capabilities() for plot_type_name
	"""
	# PARAMETRIC: Delegate to BasePlot which queries parent biome
	return super.get_plot_emojis()


func get_semantic_emoji() -> String:
	"""Get the dominant emoji based on quantum state."""
	if not is_active():
		var emojis = get_plot_emojis()
		return emojis.get("north", "")

	var outcome = get_measured_outcome()
	if outcome != "":
		return outcome
	return get_basis_labels()[0]


## Growth & Evolution


func grow(delta: float, biome = null, territory_manager = null, icon_network = null, conspiracy_network = null) -> float:
	"""Evolve quantum state with energy growth from biome."""
	if not is_active():
		return 0.0

	# Model B: Quantum evolution is handled by parent biome's quantum computer
	# This method is called each frame for plot growth logic
	# NOTE: energy_tap processing removed (2026-01) - system deprecated

	return 0.0


## Entanglement


func add_entanglement(other_plot_id: String, strength: float) -> void:
	"""Add entanglement with another plot"""
	if entangled_plots.size() < MAX_ENTANGLEMENTS:
		entangled_plots[other_plot_id] = strength


func clear_entanglement() -> void:
	"""Clear all entanglement relationships"""
	entangled_plots.clear()


func get_entanglement_count() -> int:
	"""Get number of entangled plots"""
	return entangled_plots.size()
