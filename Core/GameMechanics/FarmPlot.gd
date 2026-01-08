class_name FarmPlot
extends "res://Core/GameMechanics/BasePlot.gd"

## FarmPlot - Player-interactive plots in the farm grid
## Base class for all plots the player can apply tools to
## Handles quantum evolution, entanglement, and generic plot mechanics
## Subclasses: WheatPlot (crops with constraints)

const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")

# Plot type
enum PlotType { WHEAT, TOMATO, MUSHROOM, MILL, MARKET, KITCHEN, ENERGY_TAP, FIRE, WATER, FLOUR, VEGETATION, RABBIT, WOLF, BREAD }
@export var plot_type: PlotType = PlotType.WHEAT

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
	plot_type = PlotType.WHEAT  # Default plot type


## Helper Functions


func get_plot_emojis() -> Dictionary:
	"""Get the dual-emoji pair for this plot type"""
	match plot_type:
		PlotType.WHEAT:
			return {"north": "🌾", "south": "👥"}  # Wheat ↔ Labor (agriculture)
		PlotType.TOMATO:
			return {"north": "🍅", "south": "🌌"}  # Tomato ↔ Cosmic Chaos (counter-axial: life vs entropy)
		PlotType.MUSHROOM:
			return {"north": "🍄", "south": "🍂"}  # Mushroom ↔ Detritus (decomposition cycle)
		PlotType.MILL:
			return {"north": "🏭", "south": "💨"}  # Mill ↔ Flour
		PlotType.MARKET:
			return {"north": "🏪", "south": "💰"}  # Market ↔ Credits
		PlotType.KITCHEN:
			return {"north": "🍳", "south": "🍞"}  # Kitchen ↔ Bread
		PlotType.ENERGY_TAP:
			return {"north": "🚰", "south": "⚡"}  # Energy Tap ↔ Power
		# Kitchen ingredients (quantum baking qubits)
		PlotType.FIRE:
			return {"north": "🔥", "south": "❄️"}  # Temperature: Hot ↔ Cold (qubit 1)
		PlotType.WATER:
			return {"north": "💧", "south": "🏜️"}  # Moisture: Wet ↔ Dry (qubit 2)
		PlotType.FLOUR:
			return {"north": "💨", "south": "🌾"}  # Substance: Flour ↔ Grain (qubit 3)
		# Forest organisms (ecosystem dynamics)
		PlotType.VEGETATION:
			return {"north": "🌿", "south": "🍂"}  # Vegetation ↔ Detritus (growth/decay)
		PlotType.RABBIT:
			return {"north": "🐇", "south": "🍂"}  # Rabbit ↔ Detritus (life/death)
		PlotType.WOLF:
			return {"north": "🐺", "south": "🍂"}  # Wolf ↔ Detritus (predator/decay)
		# Market commodities (trading goods)
		PlotType.BREAD:
			return {"north": "🍞", "south": "💨"}  # Bread ↔ Flour (product/ingredient)
		_:
			return {"north": "?", "south": "?"}


func get_semantic_emoji() -> String:
	"""Get the dominant emoji based on quantum state (Model B version)"""
	if not is_planted:
		var emojis = get_plot_emojis()
		return emojis["north"]  # Default to north emoji

	# Model B: Determine emoji based on purity from parent biome
	var purity = get_purity()
	if purity > 0.5:
		return measured_outcome if measured_outcome else get_basis_labels()[0]
	else:
		return measured_outcome if measured_outcome else get_basis_labels()[0]


## Growth & Evolution


func grow(delta: float, biome = null, territory_manager = null, icon_network = null, conspiracy_network = null) -> float:
	"""Evolve quantum state with energy growth from biome (Model B version)"""
	if not is_planted:
		return 0.0

	# Model B: Quantum evolution is handled by parent biome's quantum computer
	# This method is called each frame for plot growth logic

	# Process energy tap if applicable (Manifest Section 4.1)
	if plot_type == PlotType.ENERGY_TAP:
		process_energy_tap(delta, biome)

	return 0.0


func process_energy_tap(delta: float, biome = null) -> void:
	"""Process energy tap drain and accumulate resources

	Energy taps drain target emojis via Lindblad operators to sink state.
	This method reads the sink flux from the bath and converts it to harvestable resources.

	Manifest Section 4.1: Energy taps use L_e = |sink⟩⟨e| drain operators.
	Flux is tracked during bath evolution in QuantumBath.sink_flux_per_emoji.

	Args:
		delta: Time step in seconds
		biome: BiomeBase reference for accessing bath
	"""
	if plot_type != PlotType.ENERGY_TAP or not tap_target_emoji:
		return

	if not biome or not biome.bath:
		return

	# Read flux from bath (Manifest Section 4.1)
	var flux = biome.bath.get_sink_flux(tap_target_emoji)

	if flux > 0.0:
		# Convert flux to classical resource (1 flux = 10 resource units)
		var resource_gain = flux * 10.0

		tap_accumulated_resource += resource_gain
		tap_last_flux_check = biome.bath.bath_time

		# Debug output (can be removed in production)
		if resource_gain > 0.01:
			print("   ⚡ Tap %s: drained %.4f flux from %s → +%.2f resource (total: %.2f)" % [
				plot_id, flux, tap_target_emoji, resource_gain, tap_accumulated_resource
			])


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
