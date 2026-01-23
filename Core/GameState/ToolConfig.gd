class_name ToolConfig
extends RefCounted
## ToolConfig - v2 Tool Architecture Configuration
##
## Defines PLAY mode (4 tools) and BUILD mode (4 tools) with F-cycling support.
## Implements "Quantum Tomography Paradigm" - plots as probes into quantum soup.
##
## Key Changes from v1:
##   - EXPLORE replaces PLANT as primary action (discover, don't create)
##   - F-cycling for mode expansion within tools (GATES, ENTANGLE)
##   - Tab toggles BUILD/PLAY modes
##   - Spacebar pauses/resumes evolution

## Current game mode ("play" or "build")
static var current_mode: String = "play"

## F-cycling mode indices per tool (mode_tool_num → current mode index)
## Key format: "play_2" or "build_4" to track modes per mode+tool combo
static var tool_mode_indices: Dictionary = {
	"play_2": 0,  # GATES: 0=convert, 1=phase
	"play_3": 0,  # ENTANGLE: 0=link, 1=manage
	"play_4": 0,  # INDUSTRY: 0=build, 1=harvest
	"build_4": 0  # QUANTUM: 0=system, 1=phase, 2=rotation
}

# ============================================================================
# PLAY MODE TOOLS - Primary gameplay (Tab = "play")
# ============================================================================
#
# Tool Organization Philosophy:
#   Tool 1 (PROBE): Core loop - EXPLORE → MEASURE → POP (80% of gameplay)
#   Tool 2 (GATES): 1-qubit gates - probability control for resource conversion
#   Tool 3 (ENTANGLE): 2-qubit gates - create and manage entanglement
#   Tool 4 (INDUSTRY): Economy - buildings and automation
#
# F-Cycling: Tools 2 and 3 have multiple banks accessible via F key
#   - Bank 1: Most useful gates (default)
#   - Bank 2: Advanced/niche gates

const PLAY_TOOLS = {
	1: {  # PROBE - Core loop (80% of gameplay)
		"name": "Probe",
		"emoji": "🔬",
		"icon": "res://Assets/UI/Science/Probe.svg",
		"description": "Explore quantum soup, measure, harvest",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "explore", "label": "Explore", "emoji": "🔍",
				  "icon": "res://Assets/UI/Science/Explore.svg"},
			"E": {"action": "measure", "label": "Measure", "emoji": "👁️",
				  "icon": "res://Assets/UI/Science/Measure.svg"},
			"R": {"action": "pop", "label": "Pop/Harvest", "emoji": "✂️",
				  "icon": "res://Assets/UI/Science/Pop-Harvest.svg"}
		}
	},
	2: {  # GATES - 1-qubit gates with F-cycling
		"name": "Gates",
		"emoji": "⚡",
		"icon": "res://Assets/UI/Q-Bit/Unitary.svg",
		"description": "1-qubit gates for probability control",
		"has_f_cycling": true,
		"modes": ["convert", "phase"],
		"mode_labels": ["Convert", "Phase"],
		"actions": {
			"convert": {  # Bank 1: Most useful for gameplay (default)
				"Q": {"action": "apply_pauli_x", "label": "X Flip", "emoji": "↔️",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-X.svg",
					  "hint": "Swap north↔south emoji"},
				"E": {"action": "apply_hadamard", "label": "H Superpose", "emoji": "🌀",
					  "icon": "res://Assets/UI/Q-Bit/Hadamard.svg",
					  "hint": "Reset to 50/50"},
				"R": {"action": "apply_ry", "label": "Ry Tune", "emoji": "🎚️",
					  "icon": "res://Assets/UI/Tools/Quantum/RY.svg",
					  "hint": "Dial exact probability"}
			},
			"phase": {  # Bank 2: Phase gates (advanced)
				"Q": {"action": "apply_pauli_z", "label": "Z Phase", "emoji": "📐",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-Z.svg",
					  "hint": "Phase flip |1⟩"},
				"E": {"action": "apply_s_gate", "label": "S π/2", "emoji": "🌙",
					  "icon": "res://Assets/UI/Tools/Quantum/S.svg",
					  "hint": "Quarter phase turn"},
				"R": {"action": "apply_t_gate", "label": "T π/4", "emoji": "✨",
					  "icon": "res://Assets/UI/Tools/Quantum/T.svg",
					  "hint": "Eighth phase turn"}
			}
		}
	},
	3: {  # ENTANGLE - 2-qubit gates with F-cycling
		"name": "Entangle",
		"emoji": "🔗",
		"icon": "res://Assets/UI/Tools/Entangle/Entangle.svg",
		"description": "2-qubit gates for entanglement",
		"has_f_cycling": true,
		"modes": ["link", "manage"],
		"mode_labels": ["Link", "Manage"],
		"actions": {
			"link": {  # Bank 1: Core entanglement gates (default)
				"Q": {"action": "apply_cnot", "label": "CNOT", "emoji": "🔗",
					  "icon": "res://Assets/UI/Tools/Entangle/Entangle.svg",
					  "hint": "Flip target if control=|1⟩"},
				"E": {"action": "apply_swap", "label": "SWAP", "emoji": "🔄",
					  "icon": "res://Assets/UI/Icon/Swap.svg",
					  "hint": "Exchange two qubit states"},
				"R": {"action": "apply_cz", "label": "CZ", "emoji": "⚡",
					  "icon": "res://Assets/UI/Tools/Entangle/Trigger.svg",
					  "hint": "Phase kick on |11⟩"}
			},
			"manage": {  # Bank 2: Entanglement management
				"Q": {"action": "create_bell_pair", "label": "Bell Pair", "emoji": "💑",
					  "icon": "res://Assets/UI/Tools/Entangle/Cluster.svg",
					  "hint": "Create maximally entangled pair"},
				"E": {"action": "disentangle", "label": "Disentangle", "emoji": "✂️",
					  "icon": "res://Assets/UI/Tools/Entangle/Disentangle.svg",
					  "hint": "Break entanglement"},
				"R": {"action": "inspect_entanglement", "label": "Inspect", "emoji": "🔍",
					  "icon": "res://Assets/UI/Biome/BiomeInspect.svg",
					  "hint": "View entanglement graph"}
			}
		}
	},
	4: {  # INDUSTRY - Economy & automation (F-cycle: Build → Harvest)
		"name": "Industry",
		"emoji": "🏭",
		"icon": "res://Assets/UI/Industry/Industry.svg",
		"description": "Economy & automation",
		"has_f_cycling": true,
		"modes": ["build", "harvest"],
		"mode_labels": ["Build", "Harvest"],
		"actions": {
			"build": {  # Mode 0: Place buildings (default)
				"Q": {"action": "submenu_mill_power", "label": "Mill ▸", "emoji": "⚙️",
					  "icon": "res://Assets/UI/Industry/Mill.svg",
					  "hint": "Place mill (coupling injector)", "submenu": "mill_power"},
				"E": {"action": "place_market", "label": "Market", "emoji": "🏪",
					  "icon": "res://Assets/UI/Industry/Market.svg",
					  "hint": "Place market (sell for 💰)"},
				"R": {"action": "place_kitchen", "label": "Kitchen", "emoji": "🍳",
					  "icon": "res://Assets/UI/Industry/Kitchen.svg",
					  "hint": "Place kitchen (3 plots)"}
			},
			"harvest": {  # Mode 1: Harvest from buildings
				"Q": {"action": "harvest_flour", "label": "Harvest 💨", "emoji": "💨",
					  "icon": "res://Assets/UI/Science/Pop-Harvest.svg",
					  "hint": "Harvest flour when P(💨) high"},
				"E": {"action": "market_sell", "label": "Sell 💰", "emoji": "💰",
					  "icon": "res://Assets/UI/Industry/Market.svg",
					  "hint": "Quantum sale for credits"},
				"R": {"action": "bake_bread", "label": "Bake 🍞", "emoji": "🍞",
					  "icon": "res://Assets/UI/Industry/Kitchen.svg",
					  "hint": "Bake bread (💧+🔥+💨)"}
			}
		}
	}
}

# ============================================================================
# BUILD MODE TOOLS - World configuration (Tab = "build")
# ============================================================================

const BUILD_TOOLS = {
	1: {  # BIOME - Ecosystem management
		"name": "Biome",
		"emoji": "🌍",
		"icon": "res://Assets/UI/Biome/Biome.svg",
		"description": "Assign plots to biomes, configure ecosystems",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "submenu_biome_assign", "label": "Assign Biome ▸", "emoji": "🔄",
				  "icon": "res://Assets/UI/Biome/BiomeAssign.svg", "submenu": "biome_assign"},
			"E": {"action": "clear_biome_assignment", "label": "Clear Assignment", "emoji": "❌",
				  "icon": "res://Assets/UI/Biome/BiomeClear.svg"},
			"R": {"action": "inspect_plot", "label": "Inspect Plot", "emoji": "🔍",
				  "icon": "res://Assets/UI/Biome/BiomeInspect.svg"}
		}
	},
	2: {  # ICON - Icon/emoji configuration
		"name": "Icon",
		"emoji": "⚙️",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"description": "Configure icons and emoji associations",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "submenu_icon_assign", "label": "Assign Icon ▸", "emoji": "🎨",
				  "icon": "res://Assets/UI/Icon/Assign.svg", "submenu": "icon_assign"},
			"E": {"action": "icon_swap", "label": "Swap N/S", "emoji": "🔃",
				  "icon": "res://Assets/UI/Icon/Swap.svg"},
			"R": {"action": "icon_clear", "label": "Clear Icon", "emoji": "⬜",
				  "icon": "res://Assets/UI/Icon/Clear.svg"}
		}
	},
	3: {  # LINDBLAD - Dissipation control
		"name": "Lindblad",
		"emoji": "🔬",
		"icon": "res://Assets/UI/Tools/Lindblad/Lindblad.svg",
		"description": "Configure Lindblad operators and dissipation",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "lindblad_drive", "label": "Drive (+pop)", "emoji": "📈",
				  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg"},
			"E": {"action": "lindblad_decay", "label": "Decay (-pop)", "emoji": "📉",
				  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg"},
			"R": {"action": "lindblad_transfer", "label": "Transfer", "emoji": "↔️",
				  "icon": "res://Assets/UI/Tools/Lindblad/Transfer.svg"}
		}
	},
	4: {  # QUANTUM - System control + Gate configuration (F-cycles)
		"name": "Quantum",
		"emoji": "⚛️",
		"icon": "res://Assets/UI/Tools/Quantum/Quantum.svg",
		"description": "System control and gate configuration",
		"has_f_cycling": true,
		"modes": ["system", "phase", "rotation"],
		"mode_labels": ["System", "Phase Gates", "Rotation"],
		"actions": {
			"system": {  # Mode 0: System control
				"Q": {"action": "system_reset", "label": "Reset Bath", "emoji": "🔄",
					  "icon": "res://Assets/UI/Tools/Quantum/Reset Bath.svg"},
				"E": {"action": "system_snapshot", "label": "Snapshot", "emoji": "📸",
					  "icon": "res://Assets/UI/Tools/Quantum/Snapshot.svg"},
				"R": {"action": "system_debug", "label": "Debug View", "emoji": "🐛",
					  "icon": "res://Assets/UI/Tools/Quantum/Debug.svg"}
			},
			"phase": {  # Mode 1: Phase gates (S, T, S†)
				"Q": {"action": "apply_s_gate", "label": "S (π/2)", "emoji": "🌙",
					  "icon": "res://Assets/UI/Tools/Quantum/S.svg"},
				"E": {"action": "apply_t_gate", "label": "T (π/4)", "emoji": "✨",
					  "icon": "res://Assets/UI/Tools/Quantum/T.svg"},
				"R": {"action": "apply_sdg_gate", "label": "S† (-π/2)", "emoji": "🌑",
					  "icon": "res://Assets/UI/Tools/Quantum/ST-.svg"}
			},
			"rotation": {  # Mode 2: Rotation gates
				"Q": {"action": "apply_rx_gate", "label": "Rx (θ)", "emoji": "↔️",
					  "icon": "res://Assets/UI/Tools/Quantum/RX.svg"},
				"E": {"action": "apply_ry_gate", "label": "Ry (θ)", "emoji": "↕️",
					  "icon": "res://Assets/UI/Tools/Quantum/RY.svg"},
				"R": {"action": "apply_rz_gate", "label": "Rz (θ)", "emoji": "🔄",
					  "icon": "res://Assets/UI/Tools/Quantum/RZ.svg"}
			}
		}
	}
}

# ============================================================================
# SUBMENUS (shared between modes)
# ============================================================================

const SUBMENUS = {
	"biome_assign": {
		"name": "Assign to Biome",
		"emoji": "🔄",
		"icon": "res://Assets/UI/Biome/BiomeAssign.svg",
		"parent_tool": 1,
		"parent_mode": "build",
		"dynamic": true,
		# Fallback definitions (icons added dynamically from biome data)
		"Q": {"action": "assign_to_BioticFlux", "label": "BioticFlux", "emoji": "🌾"},
		"E": {"action": "assign_to_Market", "label": "Market", "emoji": "🏪"},
		"R": {"action": "assign_to_Forest", "label": "Forest", "emoji": "🌲"},
	},
	"icon_assign": {
		"name": "Assign Icon",
		"emoji": "🎨",
		"icon": "res://Assets/UI/Icon/Assign.svg",
		"parent_tool": 2,
		"parent_mode": "build",
		"dynamic": true,
		"Q": {"action": "icon_assign_wheat", "label": "Wheat", "emoji": "🌾"},
		"E": {"action": "icon_assign_mushroom", "label": "Mushroom", "emoji": "🍄"},
		"R": {"action": "icon_assign_tomato", "label": "Tomato", "emoji": "🍅"},
	},
	# Mill two-stage submenus (power source → conversion)
	"mill_power": {
		"name": "Mill Power",
		"emoji": "⚡",
		"icon": "res://Assets/UI/Industry/Mill.svg",
		"parent_tool": 4,
		"parent_mode": "play",
		"dynamic": false,
		"Q": {"action": "mill_select_power_water", "label": "Water", "emoji": "💧"},
		"E": {"action": "mill_select_power_wind", "label": "Wind", "emoji": "🌬️"},
		"R": {"action": "mill_select_power_fire", "label": "Fire", "emoji": "🔥"},
	},
	"mill_conversion": {
		"name": "Mill Conversion",
		"emoji": "⚙️",
		"icon": "res://Assets/UI/Industry/Mill.svg",
		"parent_tool": 4,
		"parent_mode": "play",
		"dynamic": false,
		"Q": {"action": "mill_convert_flour", "label": "Flour", "emoji": "🌾→💨"},
		"E": {"action": "mill_convert_lumber", "label": "Lumber", "emoji": "🌲→🪵"},
		"R": {"action": "mill_convert_energy", "label": "Energy", "emoji": "🍂→⚡"},
	}
}

# ============================================================================
# MODE MANAGEMENT
# ============================================================================

static func toggle_mode() -> String:
	"""Toggle between play and build modes. Returns new mode."""
	current_mode = "build" if current_mode == "play" else "play"
	return current_mode


static func get_mode() -> String:
	"""Get current mode (play or build)."""
	return current_mode


static func set_mode(mode: String) -> void:
	"""Set current mode."""
	if mode in ["play", "build"]:
		current_mode = mode


# ============================================================================
# F-CYCLING (MODE EXPANSION WITHIN TOOLS)
# ============================================================================

static func _get_mode_key(tool_num: int) -> String:
	"""Get dictionary key for tool mode tracking."""
	return "%s_%d" % [current_mode, tool_num]


static func cycle_tool_mode(tool_num: int) -> int:
	"""Cycle F-mode for a tool. Returns new mode index, or -1 if no cycling."""
	var tools = PLAY_TOOLS if current_mode == "play" else BUILD_TOOLS
	var tool_def = tools.get(tool_num, {})

	if not tool_def.get("has_f_cycling", false):
		return -1

	var modes = tool_def.get("modes", [])
	if modes.is_empty():
		return -1

	var mode_key = _get_mode_key(tool_num)
	var current_index = tool_mode_indices.get(mode_key, 0)
	var new_index = (current_index + 1) % modes.size()
	tool_mode_indices[mode_key] = new_index

	return new_index


static func get_tool_mode_index(tool_num: int) -> int:
	"""Get current F-mode index for a tool."""
	var mode_key = _get_mode_key(tool_num)
	return tool_mode_indices.get(mode_key, 0)


static func get_tool_mode_name(tool_num: int) -> String:
	"""Get current F-mode name for a tool."""
	var tools = PLAY_TOOLS if current_mode == "play" else BUILD_TOOLS
	var tool_def = tools.get(tool_num, {})

	if not tool_def.get("has_f_cycling", false):
		return ""

	var modes = tool_def.get("modes", [])
	var mode_key = _get_mode_key(tool_num)
	var index = tool_mode_indices.get(mode_key, 0)

	if index < modes.size():
		return modes[index]
	return ""


static func get_tool_mode_label(tool_num: int) -> String:
	"""Get current F-mode label for UI display."""
	var tools = PLAY_TOOLS if current_mode == "play" else BUILD_TOOLS
	var tool_def = tools.get(tool_num, {})

	if not tool_def.get("has_f_cycling", false):
		return ""

	var mode_labels = tool_def.get("mode_labels", [])
	var mode_key = _get_mode_key(tool_num)
	var index = tool_mode_indices.get(mode_key, 0)

	if index < mode_labels.size():
		return mode_labels[index]
	return ""


static func reset_tool_modes() -> void:
	"""Reset all tool modes to default (index 0)."""
	for key in tool_mode_indices:
		tool_mode_indices[key] = 0


# ============================================================================
# TOOL ACCESS (v2 API)
# ============================================================================

static func get_current_tools() -> Dictionary:
	"""Get tools for current mode."""
	return PLAY_TOOLS if current_mode == "play" else BUILD_TOOLS


static func get_tool(tool_num: int) -> Dictionary:
	"""Get tool definition by number (1-4)."""
	var tools = get_current_tools()
	return tools.get(tool_num, {})


static func get_tool_name(tool_num: int) -> String:
	"""Get tool name by number."""
	return get_tool(tool_num).get("name", "Unknown")


static func get_tool_emoji(tool_num: int) -> String:
	"""Get tool emoji by number."""
	return get_tool(tool_num).get("emoji", "?")


static func get_tool_icon_path(tool_num: int) -> String:
	"""Get tool icon path by number. Returns empty string if no icon."""
	return get_tool(tool_num).get("icon", "")


static func has_f_cycling(tool_num: int) -> bool:
	"""Check if tool supports F-cycling."""
	return get_tool(tool_num).get("has_f_cycling", false)


# ============================================================================
# ACTION ACCESS (v2 API with F-cycling support)
# ============================================================================

static func get_action(tool_num: int, key: String) -> Dictionary:
	"""Get action definition for a tool and key (Q/E/R).

	For tools with F-cycling, returns action from current mode.
	"""
	var tool_def = get_tool(tool_num)
	if tool_def.is_empty():
		return {}

	# Handle F-cycling tools
	if tool_def.get("has_f_cycling", false):
		var mode_name = get_tool_mode_name(tool_num)
		var mode_actions = tool_def.get("actions", {}).get(mode_name, {})
		return mode_actions.get(key, {})

	# Non-cycling tools have direct actions
	var actions = tool_def.get("actions", {})
	return actions.get(key, {})


static func get_action_label(tool_num: int, key: String) -> String:
	"""Get action label for UI display."""
	return get_action(tool_num, key).get("label", "")


static func get_action_emoji(tool_num: int, key: String) -> String:
	"""Get action emoji for UI display."""
	return get_action(tool_num, key).get("emoji", "")


static func get_action_name(tool_num: int, key: String) -> String:
	"""Get action name (for dispatching to handlers)."""
	return get_action(tool_num, key).get("action", "")


static func get_action_icon(tool_num: int, key: String) -> String:
	"""Get action icon path for UI display."""
	return get_action(tool_num, key).get("icon", "")


static func get_all_actions(tool_num: int) -> Dictionary:
	"""Get all Q/E/R actions for a tool (respecting F-cycling mode)."""
	return {
		"Q": get_action(tool_num, "Q"),
		"E": get_action(tool_num, "E"),
		"R": get_action(tool_num, "R")
	}


# ============================================================================
# SUBMENU ACCESS
# ============================================================================

static func get_submenu(submenu_name: String) -> Dictionary:
	"""Get submenu definition by name."""
	return SUBMENUS.get(submenu_name, {})


static func is_submenu_action(tool_num: int, key: String) -> bool:
	"""Check if action opens a submenu."""
	var action = get_action(tool_num, key)
	return action.has("submenu")


static func get_submenu_name_for_action(tool_num: int, key: String) -> String:
	"""Get submenu name if action opens one."""
	return get_action(tool_num, key).get("submenu", "")


static func get_dynamic_submenu(submenu_name: String, farm, current_selection: Vector2i = Vector2i.ZERO) -> Dictionary:
	"""Generate dynamic submenu from game state.

	For submenus marked with "dynamic": true, generates Q/E/R actions
	at runtime based on available game options.
	"""
	var base_submenu = get_submenu(submenu_name)

	if not base_submenu.get("dynamic", false):
		return base_submenu

	match submenu_name:
		"biome_assign":
			return _generate_biome_assign_submenu(base_submenu, farm)
		"icon_assign":
			return _generate_icon_assign_submenu(base_submenu, farm, current_selection)
		_:
			push_warning("Unknown dynamic submenu: %s" % submenu_name)
			return base_submenu


static func _generate_biome_assign_submenu(base: Dictionary, farm) -> Dictionary:
	"""Generate biome assignment submenu from registered biomes."""
	var generated = base.duplicate(true)

	var biome_names: Array[String] = []
	if farm and farm.grid and farm.grid.biomes:
		for key in farm.grid.biomes.keys():
			biome_names.append(str(key))

	if biome_names.is_empty():
		generated["Q"] = {"action": "", "label": "No Biomes!", "emoji": "❌"}
		generated["E"] = {"action": "", "label": "Error", "emoji": "⚠️"}
		generated["R"] = {"action": "", "label": "", "emoji": ""}
		generated["_disabled"] = true
		return generated

	var keys = ["Q", "E", "R"]
	for i in range(min(3, biome_names.size())):
		var biome_name = biome_names[i]
		var key = keys[i]

		var biome_emoji = "🌍"
		if farm.grid.biomes.has(biome_name):
			var biome = farm.grid.biomes[biome_name]
			if biome and biome.producible_emojis.size() > 0:
				biome_emoji = biome.producible_emojis[0]

		generated[key] = {
			"action": "assign_to_%s" % biome_name,
			"label": biome_name,
			"emoji": biome_emoji
		}

	for i in range(biome_names.size(), 3):
		generated[keys[i]] = {"action": "", "label": "Empty", "emoji": "⬜"}

	return generated


static func _generate_icon_assign_submenu(base: Dictionary, farm, current_selection: Vector2i) -> Dictionary:
	"""Generate icon assignment submenu from player vocabulary.

	Only shows emojis the player has learned (vocabulary system).
	This restricts planting to known vocabulary.
	"""
	var generated = base.duplicate(true)

	# Get player vocabulary from GameStateManager
	var player_vocab: Array = []
	var gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		player_vocab = gsm.current_state.get_known_emojis()  # Derived from known_pairs

	if player_vocab.is_empty():
		generated["Q"] = {"action": "", "label": "No Vocab!", "emoji": "📖"}
		generated["E"] = {"action": "", "label": "Complete Quests", "emoji": "📜"}
		generated["R"] = {"action": "", "label": "", "emoji": ""}
		generated["_disabled"] = true
		return generated

	# Use player vocabulary (what they've learned from quests)
	# Need to show pairs, so get the known_pairs directly
	var known_pairs: Array = []
	if gsm and gsm.current_state:
		known_pairs = gsm.current_state.known_pairs

	var keys = ["Q", "E", "R"]

	for i in range(min(3, known_pairs.size())):
		var pair = known_pairs[i]
		var north = pair.get("north", "?")
		var south = pair.get("south", "?")
		generated[keys[i]] = {
			"action": "icon_assign_%s" % north,
			"label": "%s/%s" % [north, south],
			"emoji": north
		}

	for i in range(known_pairs.size(), 3):
		generated[keys[i]] = {"action": "", "label": "Empty", "emoji": "⬜"}

	# Store full pairs for F-cycling if more than 3
	if known_pairs.size() > 3:
		generated["_extra_pairs"] = known_pairs.slice(3)

	return generated


# ============================================================================
# BACKWARD COMPATIBILITY (v1 migration support)
# ============================================================================

## v1 TOOL_ACTIONS format for gradual migration
const TOOL_ACTIONS = PLAY_TOOLS  # Alias for compatibility

static func get_tool_count() -> int:
	"""Get number of tools in current mode."""
	return 4  # v2 always has 4 tools per mode
