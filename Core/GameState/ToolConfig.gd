class_name ToolConfig
extends RefCounted
## ToolConfig - Shared configuration for game tools (1-6)
##
## Single source of truth for tool definitions, actions, and labels.
## Used by: FarmInputHandler, ToolSelectionRow, ActionPreviewRow

const TOOL_ACTIONS = {
	1: {  # GROWER Tool - Core farming (80% of gameplay)
		"name": "Grower",
		"emoji": "🌱",
		"Q": {"action": "submenu_plant", "label": "Plant ▸", "emoji": "🌾", "submenu": "plant"},
		"E": {"action": "entangle_batch", "label": "Entangle (Bell φ+)", "emoji": "🔗"},
		"R": {"action": "measure_and_harvest", "label": "Measure + Harvest", "emoji": "✂️"},
	},
	2: {  # QUANTUM Tool - Persistent gate infrastructure (survives harvest)
		"name": "Quantum",
		"emoji": "⚛️",
		"Q": {"action": "cluster", "label": "Build Gate (2=Bell, 3+=Cluster)", "emoji": "🔗"},
		"E": {"action": "measure_trigger", "label": "Set Measure Trigger", "emoji": "👁️"},
		"R": {"action": "measure_batch", "label": "Measure", "emoji": "👁️"},
	},
	3: {  # INDUSTRY Tool - Economy & automation
		"name": "Industry",
		"emoji": "🏭",
		"Q": {"action": "submenu_industry", "label": "Build ▸", "emoji": "🏗️", "submenu": "industry"},
		"E": {"action": "place_market", "label": "Build Market", "emoji": "🏪"},
		"R": {"action": "place_kitchen", "label": "Build Kitchen", "emoji": "🍳"},
	},
	4: {  # BIOME EVOLUTION CONTROLLER - Research-grade quantum control
		"name": "Biome Control",
		"emoji": "⚡",
		"Q": {"action": "submenu_energy_tap", "label": "Energy Tap ▸", "emoji": "🚰", "submenu": "energy_tap"},
		"E": {"action": "submenu_pump_reset", "label": "Pump/Reset ▸", "emoji": "🔄", "submenu": "pump_reset"},
		"R": {"action": "tune_decoherence", "label": "Tune Decoherence", "emoji": "🌊"},
	},
	5: {  # GATES Tool - Quantum gate operations
		"name": "Gates",
		"emoji": "🔄",
		"Q": {"action": "submenu_single_gates", "label": "1-Qubit ▸", "emoji": "⚛️", "submenu": "single_gates"},
		"E": {"action": "submenu_two_gates", "label": "2-Qubit ▸", "emoji": "🔗", "submenu": "two_gates"},
		"R": {"action": "remove_gates", "label": "Remove Gates", "emoji": "💔"},
	},
	6: {  # BIOME Tool - Ecosystem management
		"name": "Biome",
		"emoji": "🌍",
		"Q": {"action": "submenu_biome_assign", "label": "Assign Biome ▸", "emoji": "🔄", "submenu": "biome_assign"},
		"E": {"action": "clear_biome_assignment", "label": "Clear Assignment", "emoji": "❌"},
		"R": {"action": "inspect_plot", "label": "Inspect Plot", "emoji": "🔍"},
	},
}


# Submenu definitions - QER actions within a submenu context
const SUBMENUS = {
	"plant": {
		"name": "Plant Type",
		"emoji": "🌱",
		"parent_tool": 1,
		"dynamic": true,  # Generate based on selected plot's biome
		"Q": {"action": "plant_wheat", "label": "Wheat", "emoji": "🌾"},
		"E": {"action": "plant_mushroom", "label": "Mushroom", "emoji": "🍄"},
		"R": {"action": "plant_tomato", "label": "Tomato", "emoji": "🍅"},
	},
	"industry": {
		"name": "Build Type",
		"emoji": "🏗️",
		"parent_tool": 3,
		"Q": {"action": "place_mill", "label": "Mill", "emoji": "🏭"},
		"E": {"action": "place_market", "label": "Market", "emoji": "🏪"},
		"R": {"action": "place_kitchen", "label": "Kitchen", "emoji": "🍳"},
	},
	"energy_tap": {
		"name": "Energy Tap Target",
		"emoji": "🚰",
		"parent_tool": 4,
		"Q": {"action": "tap_fire", "label": "Fire Tap (Kitchen)", "emoji": "🔥"},
		"E": {"action": "tap_water", "label": "Water Tap (Forest)", "emoji": "💧"},
		"R": {"action": "tap_flour", "label": "Flour Tap (Market)", "emoji": "💨"},
	},
	"pump_reset": {
		"name": "Pump & Reset Operations",
		"emoji": "🔄",
		"parent_tool": 4,
		"Q": {"action": "pump_to_wheat", "label": "Pump to Wheat", "emoji": "🌾"},
		"E": {"action": "reset_to_pure", "label": "Reset Pure", "emoji": "✨"},
		"R": {"action": "reset_to_mixed", "label": "Reset Mixed", "emoji": "🌈"},
	},
	"single_gates": {
		"name": "1-Qubit Gates",
		"emoji": "⚛️",
		"parent_tool": 5,
		"Q": {"action": "apply_pauli_x", "label": "Pauli-X (Flip)", "emoji": "↔️"},
		"E": {"action": "apply_hadamard", "label": "Hadamard (H)", "emoji": "🌀"},
		"R": {"action": "apply_pauli_z", "label": "Pauli-Z (Phase)", "emoji": "⚡"},
	},
	"two_gates": {
		"name": "2-Qubit Gates",
		"emoji": "🔗",
		"parent_tool": 5,
		"Q": {"action": "apply_cnot", "label": "CNOT", "emoji": "⊕"},
		"E": {"action": "apply_cz", "label": "CZ (Control-Z)", "emoji": "⚡"},
		"R": {"action": "apply_swap", "label": "SWAP", "emoji": "⇄"},
	},
	"biome_assign": {
		"name": "Assign to Biome",
		"emoji": "🔄",
		"parent_tool": 6,
		"dynamic": true,  # Generate from farm.grid.biomes registry
		# Fallback definitions (if generation fails)
		"Q": {"action": "assign_to_BioticFlux", "label": "BioticFlux", "emoji": "🌾"},
		"E": {"action": "assign_to_Market", "label": "Market", "emoji": "🏪"},
		"R": {"action": "assign_to_Forest", "label": "Forest", "emoji": "🌲"},
	},
}


static func get_tool(tool_num: int) -> Dictionary:
	"""Get tool definition by number (1-6)."""
	return TOOL_ACTIONS.get(tool_num, {})


static func get_submenu(submenu_name: String) -> Dictionary:
	"""Get submenu definition by name."""
	return SUBMENUS.get(submenu_name, {})


static func get_dynamic_submenu(submenu_name: String, farm, current_selection: Vector2i = Vector2i.ZERO) -> Dictionary:
	"""Generate dynamic submenu from game state (discovered vocabulary, current selection)

	For submenus marked with "dynamic": true, generates Q/E/R actions
	at runtime based on available game options (e.g., discovered emojis, selected plot's biome).

	Args:
		submenu_name: Name of submenu to generate
		farm: Farm instance (provides access to FarmGrid for vocabulary)
		current_selection: Currently selected plot position (for context-aware menus)

	Returns:
		Dictionary with Q/E/R actions, or base submenu if not dynamic
	"""
	var base_submenu = get_submenu(submenu_name)

	# Only process dynamic submenus
	if not base_submenu.get("dynamic", false):
		return base_submenu

	# Generate based on submenu type
	match submenu_name:
		"plant":
			return _generate_plant_submenu(base_submenu, farm, current_selection)
		"energy_tap":
			return _generate_energy_tap_submenu(base_submenu, farm)
		"biome_assign":
			return _generate_biome_assign_submenu(base_submenu, farm)
		_:
			push_warning("Unknown dynamic submenu: %s" % submenu_name)
			return base_submenu


static func _generate_plant_submenu(base: Dictionary, farm, current_selection: Vector2i) -> Dictionary:
	"""Generate plant submenu based on selected plot's biome

	Context-aware planting:
	- Kitchen plots → Q=Fire, E=Water, R=Flour (all Kitchen plots show same menu)
	- Other plots → Q=Wheat, E=Mushroom, R=Tomato (default)

	Args:
		base: Base submenu structure
		farm: Farm instance for biome lookup
		current_selection: Currently selected plot position

	Returns:
		Dictionary with Q/E/R actions appropriate for the plot's biome
	"""
	var generated = base.duplicate(true)

	# Get biome name for selected plot
	var biome_name = ""
	if farm and farm.grid and farm.grid.plot_biome_assignments.has(current_selection):
		biome_name = farm.grid.plot_biome_assignments[current_selection]

	# Generate menu based on biome
	match biome_name:
		"Kitchen":
			# Kitchen-specific plant menu: Q=Fire, E=Water, R=Flour
			# All Kitchen plots show the same menu (player chooses which ingredient)
			generated["Q"] = {"action": "plant_fire", "label": "Fire", "emoji": "🔥"}
			generated["E"] = {"action": "plant_water", "label": "Water", "emoji": "💧"}
			generated["R"] = {"action": "plant_flour", "label": "Flour", "emoji": "💨"}
			generated["name"] = "Kitchen Ingredients"
			print("  🍳 Kitchen plot → Fire/Water/Flour menu")

		"Forest":
			# Forest-specific plant menu: Q=Vegetation, E=Rabbit, R=Wolf
			# Plant forest organisms to build ecosystem dynamics
			generated["Q"] = {"action": "plant_vegetation", "label": "Vegetation", "emoji": "🌿"}
			generated["E"] = {"action": "plant_rabbit", "label": "Rabbit", "emoji": "🐇"}
			generated["R"] = {"action": "plant_wolf", "label": "Wolf", "emoji": "🐺"}
			generated["name"] = "Forest Organisms"
			print("  🌲 Forest plot → Vegetation/Rabbit/Wolf menu")

		"Market":
			# Market-specific plant menu: Q=Wheat, E=Flour, R=Bread
			# Commodity production chain for trading
			generated["Q"] = {"action": "plant_wheat", "label": "Wheat", "emoji": "🌾"}
			generated["E"] = {"action": "plant_flour", "label": "Flour", "emoji": "💨"}
			generated["R"] = {"action": "plant_bread", "label": "Bread", "emoji": "🍞"}
			generated["name"] = "Market Commodities"
			print("  📈 Market plot → Wheat/Flour/Bread menu")

		"BioticFlux":
			# BioticFlux-specific plant menu: Q=Wheat, E=Mushroom, R=Tomato
			# Standard agricultural crops with biotic cycling
			generated["Q"] = {"action": "plant_wheat", "label": "Wheat", "emoji": "🌾"}
			generated["E"] = {"action": "plant_mushroom", "label": "Mushroom", "emoji": "🍄"}
			generated["R"] = {"action": "plant_tomato", "label": "Tomato", "emoji": "🍅"}
			generated["name"] = "BioticFlux Crops"
			print("  🌾 BioticFlux plot → Wheat/Mushroom/Tomato menu")

		_:
			# Default plant menu for unassigned/other biomes
			generated["Q"] = {"action": "plant_wheat", "label": "Wheat", "emoji": "🌾"}
			generated["E"] = {"action": "plant_mushroom", "label": "Mushroom", "emoji": "🍄"}
			generated["R"] = {"action": "plant_tomato", "label": "Tomato", "emoji": "🍅"}
			generated["name"] = "Plant Type"
			print("  📦 Default plot → Wheat/Mushroom/Tomato menu")

	return generated


static func _generate_energy_tap_submenu(base: Dictionary, farm) -> Dictionary:
	"""Generate energy tap submenu from discovered vocabulary

	Maps first 3 discovered emojis to Q/E/R buttons. Handles edge cases:
	- 0 emojis: All buttons disabled with helpful message
	- 1-2 emojis: Enable available, lock unused with 🔒
	- 3+ emojis: Show first 3 (pagination future enhancement)
	"""
	# Start with base structure
	var generated = base.duplicate(true)

	# Get available emojis from vocabulary
	var available_emojis: Array[String] = []
	if farm and farm.grid:
		available_emojis = farm.grid.get_available_tap_emojis()

	# Edge case: No emojis discovered
	if available_emojis.is_empty():
		# All buttons disabled with message
		generated["Q"] = {"action": "", "label": "No Vocabulary", "emoji": "❓"}
		generated["E"] = {"action": "", "label": "Grow Crops", "emoji": "🌱"}
		generated["R"] = {"action": "", "label": "To Discover", "emoji": "📚"}
		generated["_disabled"] = true  # Signal to UI to disable all buttons
		return generated

	# Map first 3 discovered emojis to Q/E/R
	var keys = ["Q", "E", "R"]
	for i in range(min(3, available_emojis.size())):
		var emoji = available_emojis[i]
		var key = keys[i]
		generated[key] = {
			"action": "tap_" + _emoji_to_action_name(emoji),
			"label": "Tap %s" % emoji,
			"emoji": emoji
		}

	# Gray out unused buttons if <3 emojis
	for i in range(available_emojis.size(), 3):
		var key = keys[i]
		generated[key] = {
			"action": "",
			"label": "Locked",
			"emoji": "🔒"
		}

	return generated


static func _emoji_to_action_name(emoji: String) -> String:
	"""Convert emoji to action name for dynamic tap actions"""
	# Map emoji to friendly action names
	match emoji:
		"🌾": return "wheat"
		"🍄": return "mushroom"
		"🍅": return "tomato"
		_:
			# Dynamic emoji - use hash-based name
			return "emoji_%d" % emoji.hash()


static func _generate_biome_assign_submenu(base: Dictionary, farm) -> Dictionary:
	"""Generate biome assignment submenu from registered biomes

	Maps first 3 registered biomes to Q/E/R buttons. Handles edge cases:
	- 0 biomes: Shouldn't happen, show error state
	- 1-2 biomes: Enable available, lock unused with 🔒
	- 3+ biomes: Show first 3 (pagination future enhancement)
	"""
	var generated = base.duplicate(true)

	# Get registered biomes
	var biome_names: Array[String] = []
	if farm and farm.grid and farm.grid.biomes:
		# Convert untyped keys() to typed Array[String]
		var raw_keys = farm.grid.biomes.keys()
		for key in raw_keys:
			biome_names.append(str(key))

	# Edge case: No biomes (shouldn't happen)
	if biome_names.is_empty():
		generated["Q"] = {"action": "", "label": "No Biomes!", "emoji": "❌"}
		generated["E"] = {"action": "", "label": "Error", "emoji": "⚠️"}
		generated["R"] = {"action": "", "label": "Contact Dev", "emoji": "🐛"}
		generated["_disabled"] = true
		return generated

	# Map first 3 biomes to Q/E/R
	var keys = ["Q", "E", "R"]
	for i in range(min(3, biome_names.size())):
		var biome_name = biome_names[i]
		var key = keys[i]

		# Get biome emoji (first emoji from producible_emojis, or default)
		var biome = farm.grid.biomes[biome_name]
		var biome_emoji = "🌍"  # Default
		if biome and biome.producible_emojis.size() > 0:
			biome_emoji = biome.producible_emojis[0]

		generated[key] = {
			"action": "assign_to_%s" % biome_name,
			"label": biome_name,
			"emoji": biome_emoji
		}

	# Lock unused buttons if <3 biomes
	for i in range(biome_names.size(), 3):
		var key = keys[i]
		generated[key] = {
			"action": "",
			"label": "Empty",
			"emoji": "⬜"
		}

	return generated


static func get_tool_name(tool_num: int) -> String:
	"""Get tool name by number."""
	return TOOL_ACTIONS.get(tool_num, {}).get("name", "Unknown")


static func get_action(tool_num: int, key: String) -> Dictionary:
	"""Get action definition for a tool and key (Q/E/R)."""
	var tool = TOOL_ACTIONS.get(tool_num, {})
	return tool.get(key, {})


static func get_action_label(tool_num: int, key: String) -> String:
	"""Get action label for UI display."""
	var action = get_action(tool_num, key)
	return action.get("label", "")


static func get_action_emoji(tool_num: int, key: String) -> String:
	"""Get action emoji for UI display."""
	var action = get_action(tool_num, key)
	return action.get("emoji", "")
