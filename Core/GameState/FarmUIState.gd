class_name FarmUIState
extends RefCounted

## FarmUIState - Simplified Abstraction Layer
## PHASE 5: Focused on economy aggregation and save/load snapshots
## Plot updates now handled directly by PlotGridDisplay → Farm signals
## Biome updates ready for future UI integration

# Economy snapshot (for ResourcePanel)
var wheat: int = 100
var credits: int = 50  # 💰 emoji-credits balance (from production chain)
var flour: int = 0  # Intermediate product (wheat → flour → 💰)
var resources: Dictionary = {}  # {emoji: amount}

# Plot states (for save/load snapshots only - not for real-time updates)
var plot_states: Dictionary = {}  # Vector2i -> PlotUIData

# Biome info (for BiomeInfoDisplay)
var biome_data: BiomeUIData = null

# Signals (reactive updates)
signal economy_updated(wheat: int, resources: Dictionary)
signal credits_changed(new_amount: int)  # 💰 balance changed
signal flour_changed(new_amount: int)  # Intermediate product changed
signal grid_refreshed()  # Bulk refresh (save/load) - KEPT for snapshot functionality


## ============================================================================
## NESTED DATA CLASSES (Display Snapshots)
## ============================================================================

class PlotUIData:
	"""Everything PlotTile needs to render a plot"""
	var position: Vector2i
	var is_planted: bool = false
	var plot_type: String = "empty"  # "wheat", "mushroom", "tomato", "empty"

	# Quantum state (for visualization)
	var north_emoji: String = "🌾"
	var south_emoji: String = "👥"
	var north_probability: float = 0.5
	var south_probability: float = 0.5

	# Visual properties
	var is_entangled: bool = false
	var has_been_measured: bool = false


class BiomeUIData:
	"""Everything BiomeInfoDisplay needs"""
	var temperature: float = 300.0
	var is_sun: bool = true
	var sun_moon_phase: float = 0.0
	var energy_strength: float = 0.5


## ============================================================================
## TRANSFORMATION METHODS (Farm → UIState)
## ============================================================================

func update_economy(economy: Node) -> void:
	"""Transform FarmEconomy state → UI display data"""
	var old_credits = credits
	var old_flour = flour

	wheat = economy.get_resource("🌾")
	credits = economy.get_resource("💰")
	flour = economy.get_resource("💨")

	resources = {
		"👥": economy.get_resource("👥"),
		"💨": economy.get_resource("💨"),
		"🌻": economy.get_resource("🌻"),
		"🍄": economy.get_resource("🍄"),
		"🍂": economy.get_resource("🍂"),
		"🏰": economy.get_resource("👑")
	}

	# Emit signals for credits and flour changes
	if old_credits != credits:
		credits_changed.emit(credits)
	if old_flour != flour:
		flour_changed.emit(flour)

	economy_updated.emit(wheat, resources)


func update_plot(position: Vector2i, plot) -> void:
	"""Transform WheatPlot state → PlotUIData (for save/load snapshots only)

	PHASE 5: This is only called during grid_refreshed (save/load).
	Real-time plot updates now flow directly: Farm.plot_planted → PlotGridDisplay
	"""
	var ui_data = PlotUIData.new()
	ui_data.position = position
	ui_data.is_planted = plot.is_active()
	ui_data.plot_type = _get_plot_type_string(plot.plot_type)

	var emojis = plot.get_plot_emojis()
	ui_data.north_emoji = emojis.get("north", "")
	ui_data.south_emoji = emojis.get("south", "")

	ui_data.has_been_measured = plot.get_is_measured()

	plot_states[position] = ui_data
	# PHASE 5: Removed plot_updated.emit() - real-time updates now go directly to PlotGridDisplay


func update_biome(biome: Node) -> void:
	"""Transform Biome state → BiomeUIData"""
	if not biome:
		return

	biome_data = BiomeUIData.new()
	biome_data.temperature = biome.base_temperature
	biome_data.is_sun = biome.is_currently_sun()
	# Use sun_qubit.theta for phase instead of sun_moon_phase (which doesn't exist)
	biome_data.sun_moon_phase = biome.sun_qubit.theta if biome.sun_qubit else 0.0
	biome_data.energy_strength = biome.get_energy_strength()


func refresh_all(farm: Node) -> void:
	"""Bulk update - repopulate entire UIState from farm"""
	update_economy(farm.economy)

	# Iterate through all grid positions
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot:
				update_plot(pos, plot)

	# Note: Biome state updates are now handled individually by each biome
	# via their own update cycles and visual rendering
	grid_refreshed.emit()


## ============================================================================
## HELPER METHODS
## ============================================================================

func _get_plot_type_string(plot_type_enum: int) -> String:
	"""Convert WheatPlot.PlotType enum to string"""
	match plot_type_enum:
		0: return "wheat"
		1: return "tomato"
		2: return "mushroom"
		_: return "empty"
