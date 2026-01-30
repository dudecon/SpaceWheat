extends PanelContainer

## Semantic Context Indicator Panel
##
## Displays the current semantic octant (region) for the active biome.
## Shows:
## - Region name and emoji
## - Region description
## - Current phase space position
## - Modifiers active in this region
## - Adjacent regions (for navigation hints)

const SemanticOctant = preload("res://Core/QuantumSubstrate/SemanticOctant.gd")

# UI components (created dynamically)
var region_label: Label
var emoji_label: Label
var description_label: Label
var position_label: Label
var modifiers_label: Label
var adjacent_label: Label

# Update frequency
var update_timer: float = 0.0
var update_interval: float = 0.5  # Update every 0.5 seconds

# Farm/biome reference (injected)
var farm = null
var current_biome = null

# Phase space axes (which emojis define the 3 axes)
var emoji_axes: Array[String] = []

# Current region (cached for change detection)
var _current_region: SemanticOctant.Region = SemanticOctant.Region.ASCETIC
var _region_changed_signal: Signal


func _ready():
	# Set panel style
	custom_minimum_size = Vector2(300, 220)

	# Create main container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header row with emoji and name
	var header = HBoxContainer.new()
	vbox.add_child(header)

	emoji_label = Label.new()
	emoji_label.text = "🧘"
	emoji_label.add_theme_font_size_override("font_size", 28)
	header.add_child(emoji_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	header.add_child(spacer)

	region_label = Label.new()
	region_label.text = "Ascetic"
	region_label.add_theme_font_size_override("font_size", 18)
	header.add_child(region_label)

	# Description
	description_label = Label.new()
	description_label.text = "Minimalist, conservative, preservation."
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.modulate = Color(0.8, 0.8, 0.8)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(280, 40)
	vbox.add_child(description_label)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Position indicator
	position_label = Label.new()
	position_label.text = "Position: (0.30, 0.40, 0.25)"
	position_label.add_theme_font_size_override("font_size", 10)
	position_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(position_label)

	# Modifiers
	var mod_header = Label.new()
	mod_header.text = "Active Modifiers:"
	mod_header.add_theme_font_size_override("font_size", 11)
	vbox.add_child(mod_header)

	modifiers_label = Label.new()
	modifiers_label.text = "Growth: 0.6x  |  Yield: 0.7x  |  Decay: 0.5x"
	modifiers_label.add_theme_font_size_override("font_size", 10)
	modifiers_label.modulate = Color(0.9, 0.9, 0.7)
	vbox.add_child(modifiers_label)

	# Adjacent regions
	var adj_header = Label.new()
	adj_header.text = "Adjacent Regions:"
	adj_header.add_theme_font_size_override("font_size", 11)
	vbox.add_child(adj_header)

	adjacent_label = Label.new()
	adjacent_label.text = "↑ Sage  |  ↗ Guardian  |  → Warrior"
	adjacent_label.add_theme_font_size_override("font_size", 10)
	adjacent_label.modulate = Color(0.7, 0.8, 0.9)
	vbox.add_child(adjacent_label)


func set_farm(farm_ref):
	"""Inject farm reference to access biomes"""
	farm = farm_ref


func set_biome(biome_ref):
	"""Directly set which biome to monitor"""
	current_biome = biome_ref
	_detect_axes()


func set_emoji_axes(axes: Array[String]):
	"""Set which 3 emojis define the phase space axes"""
	emoji_axes = axes


func _process(dt: float):
	"""Update display periodically"""
	update_timer += dt

	if update_timer >= update_interval:
		update_timer = 0.0
		_update_display()


func _detect_axes():
	"""Auto-detect phase space axes from biome's attractor analyzer"""
	if current_biome and current_biome.attractor_analyzer:
		emoji_axes = current_biome.attractor_analyzer.selected_emojis.duplicate()
	elif current_biome and current_biome.viz_cache:
		# Fallback: use first 3 emojis from viz_cache metadata
		var all_emojis = current_biome.viz_cache.get_emojis()
		emoji_axes.clear()
		for i in range(min(3, all_emojis.size())):
			emoji_axes.append(all_emojis[i])


func _update_display():
	"""Update all UI elements"""
	var biome = _get_current_biome()
	if not biome:
		_show_no_context()
		return

	# Auto-detect axes if not set
	if emoji_axes.is_empty():
		_detect_axes()

	if emoji_axes.size() < 3:
		_show_no_context()
		return

	# Get current position in phase space
	var position = Vector3(
		biome.get_emoji_probability(emoji_axes[0]),
		biome.get_emoji_probability(emoji_axes[1]),
		biome.get_emoji_probability(emoji_axes[2])
	)

	# Detect region
	var region = SemanticOctant.detect_region(position)
	var region_changed = (region != _current_region)
	_current_region = region

	# Update UI
	emoji_label.text = SemanticOctant.get_region_emoji(region)
	region_label.text = SemanticOctant.get_region_name(region)
	region_label.modulate = SemanticOctant.get_region_color(region)

	description_label.text = SemanticOctant.get_region_description(region)

	position_label.text = "Position: (%.2f, %.2f, %.2f) [%s, %s, %s]" % [
		position.x, position.y, position.z,
		emoji_axes[0], emoji_axes[1], emoji_axes[2]
	]

	# Modifiers
	var mods = SemanticOctant.get_region_modifiers(region)
	modifiers_label.text = "Growth: %.1fx  |  Yield: %.1fx  |  Decay: %.1fx  |  Extract: %.1fx" % [
		mods.growth_rate, mods.harvest_yield, mods.coherence_decay, mods.energy_extraction
	]

	# Adjacent regions
	var adjacent = SemanticOctant.get_adjacent_regions(region)
	var adj_names: Array[String] = []
	for adj_region in adjacent:
		adj_names.append("%s %s" % [
			SemanticOctant.get_region_emoji(adj_region),
			SemanticOctant.get_region_name(adj_region)
		])
	adjacent_label.text = "  |  ".join(adj_names)

	# Tooltip with detailed info
	tooltip_text = """Semantic Context: %s

%s

Phase Space Axes:
  X: %s (Energy/Activity)
  Y: %s (Growth/Stability)
  Z: %s (Wealth/Resources)

Current Position: (%.3f, %.3f, %.3f)

Modifiers in this region affect:
- Crop growth rate
- Harvest yield
- Quantum coherence decay
- Energy extraction efficiency

Move to adjacent regions by shifting population
toward or away from threshold (0.5).""" % [
		SemanticOctant.get_region_name(region),
		SemanticOctant.get_region_description(region),
		emoji_axes[0] if emoji_axes.size() > 0 else "?",
		emoji_axes[1] if emoji_axes.size() > 1 else "?",
		emoji_axes[2] if emoji_axes.size() > 2 else "?",
		position.x, position.y, position.z
	]


func _show_no_context():
	"""Show placeholder when no context available"""
	emoji_label.text = "❓"
	region_label.text = "No Context"
	region_label.modulate = Color.GRAY
	description_label.text = "No biome or quantum state available"
	position_label.text = "Position: ---"
	modifiers_label.text = "---"
	adjacent_label.text = "---"


func _get_current_biome():
	"""Get the current/active biome"""
	# Direct reference takes priority
	if current_biome:
		return current_biome

	# Try to get from farm
	if not farm:
		return null

	# Check for multi-biome structure
	if "biomes" in farm and farm.biomes and not farm.biomes.is_empty():
		for biome_name in farm.biomes:
			var biome = farm.biomes[biome_name]
			if biome:
				return biome

	# Fallback: single biome
	if "biome" in farm and farm.biome:
		return farm.biome

	return null


func get_current_region() -> SemanticOctant.Region:
	"""Get the current semantic region (for external use)"""
	return _current_region


func get_current_modifiers() -> Dictionary:
	"""Get the current region's modifiers (for gameplay systems)"""
	return SemanticOctant.get_region_modifiers(_current_region)
