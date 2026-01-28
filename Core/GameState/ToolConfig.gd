extends RefCounted
## Note: No class_name - accessed via preload for backward compatibility

## ToolConfig - Time Scale Ratchet Tool Architecture
##
## Tool groups organized by temporal granularity:
##
## | Group | Time Scale   | Physics     | Character                                |
## |-------|--------------|-------------|------------------------------------------|
## | 1     | Continuous   | Unitary     | Smooth, reversible quantum gates         |
## | 2     | Dissipative  | Lindbladian | Energy exchange, "vampire" in/out        |
## | 3     | Discrete     | Measurement | Collapse, harvest, build gates           |
## | [4]   | Meta         | System      | Vocabulary inject/remove, biome config   |
##
## Key Layout:
##   1 2 3 [4]  = Tool group selection (time scale ratchet)
##   Q E R      = Action keys (DOWN, NEUTRAL, UP)
##   F          = Mode cycling within tool group
##
## Direction Philosophy:
##   Q = DOWN  (dig into, bind, construct)
##   E = NEUTRAL (observe, balance, transfer)
##   R = UP    (extract, harvest, remove)

## Current tool group (1-4) - Default to Measure (3) for main gameplay loop
static var current_group: int = 3

## Current mode index within each group (for F-cycling)
static var group_mode_indices: Dictionary = {
	1: 0,  # Unitary: X, Y, Z axis
	2: 0,  # Lindbladian: thermal, dephase, damp
	3: 0,  # Measure: probe, gate, build
	4: 0   # Meta: (no modes)
}

# ============================================================================
# TOOL GROUP DEFINITIONS - Time Scale Ratchet
# ============================================================================

const TOOL_GROUPS = {
	# =========================================================================
	# GROUP 1: UNITARY (~) - Continuous
	# Pure quantum gates. Smooth, reversible. Sim runs.
	# =========================================================================
	1: {
		"name": "Unitary",
		"emoji": "~",
		"icon": "res://Assets/UI/Q-Bit/Unitary.svg",
		"time_scale": "continuous",
		"description": "Smooth, reversible quantum gates",
		"has_f_cycling": true,
		"modes": ["X", "Y", "Z"],
		"mode_labels": ["X", "Y", "Z"],
		"mode_emojis": ["X", "Y", "Z"],
		"pauses_sim": false,
		"actions": {
			"X": {
				"Q": {"action": "rotate_down", "label": "-", "emoji": "-",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-X.svg",
					  "hint": "Rotate X axis down"},
				"E": {"action": "hadamard", "label": "H", "emoji": "H",
					  "icon": "res://Assets/UI/Q-Bit/Hadamard.svg",
					  "hint": "Hadamard superposition"},
				"R": {"action": "rotate_up", "label": "+", "emoji": "+",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-X.svg",
					  "hint": "Rotate X axis up"}
			},
			"Y": {
				"Q": {"action": "rotate_down", "label": "-", "emoji": "-",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-Y.svg",
					  "hint": "Rotate Y axis down"},
				"E": {"action": "hadamard", "label": "H", "emoji": "H",
					  "icon": "res://Assets/UI/Q-Bit/Hadamard.svg",
					  "hint": "Hadamard superposition"},
				"R": {"action": "rotate_up", "label": "+", "emoji": "+",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-Y.svg",
					  "hint": "Rotate Y axis up"}
			},
			"Z": {
				"Q": {"action": "rotate_down", "label": "-", "emoji": "-",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-Z.svg",
					  "hint": "Rotate Z axis down"},
				"E": {"action": "hadamard", "label": "H", "emoji": "H",
					  "icon": "res://Assets/UI/Q-Bit/Hadamard.svg",
					  "hint": "Hadamard superposition"},
				"R": {"action": "rotate_up", "label": "+", "emoji": "+",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-Z.svg",
					  "hint": "Rotate Z axis up"}
			}
		}
	},

	# =========================================================================
	# GROUP 2: LINDBLADIAN (V) - Dissipative
	# "Vampire" - energy in/out of quantum space. Vocabulary harvest.
	# =========================================================================
	2: {
		"name": "Lindblad",
		"emoji": "V",
		"icon": "res://Assets/UI/Tools/Lindblad/Lindblad.svg",
		"time_scale": "dissipative",
		"description": "Energy exchange with environment",
		"has_f_cycling": true,
		"modes": ["thermal", "dephase", "damp"],
		"mode_labels": ["~", ".", "|"],
		"mode_emojis": ["~", ".", "|"],
		"pauses_sim": false,
		"held_context": true,
		"actions": {
			"thermal": {
				"Q": {"action": "drain", "label": "Drain", "emoji": "v",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Dissipate excess to classical"},
				"E": {"action": "transfer", "label": "Xfer", "emoji": "<>",
					  "icon": "res://Assets/UI/Tools/Lindblad/Transfer.svg",
					  "hint": "Transfer population between qubits"},
				"R": {"action": "pump", "label": "Pump", "emoji": "^",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Drive energy into quantum state"}
			},
			"dephase": {
				"Q": {"action": "drain", "label": "Drain", "emoji": "v",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Dephasing drain"},
				"E": {"action": "transfer", "label": "Xfer", "emoji": "<>",
					  "icon": "res://Assets/UI/Tools/Lindblad/Transfer.svg",
					  "hint": "Dephasing transfer"},
				"R": {"action": "pump", "label": "Pump", "emoji": "^",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Dephasing pump"}
			},
			"damp": {
				"Q": {"action": "drain", "label": "Drain", "emoji": "v",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Amplitude damping drain"},
				"E": {"action": "transfer", "label": "Xfer", "emoji": "<>",
					  "icon": "res://Assets/UI/Tools/Lindblad/Transfer.svg",
					  "hint": "Amplitude damping transfer"},
				"R": {"action": "pump", "label": "Pump", "emoji": "^",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Amplitude damping pump"}
			}
		}
	},

	# =========================================================================
	# GROUP 3: MEASURE (O) - Discrete
	# Main gameplay loop. F-cycles: probe -> gate -> build
	# Gates and buildings merged conceptually (classical layer bubbles)
	# =========================================================================
	3: {
		"name": "Measure",
		"emoji": "O",
		"icon": "res://Assets/UI/Science/Measure.svg",
		"time_scale": "discrete",
		"description": "Collapse, harvest, build infrastructure",
		"has_f_cycling": true,
		"modes": ["probe", "gate", "build"],
		"mode_labels": ["?", ")(", "#"],
		"mode_emojis": ["?", ")(", "#"],
		"pauses_sim": true,
		"actions": {
			# PROBE MODE: Main quantum observation loop
			"probe": {
			"Q": {"action": "explore", "label": "Explore", "emoji": "?",
				  "icon": "res://Assets/UI/Science/Explore.svg",
				  "hint": "Bind terminal (dig DOWN)"},
			"E": {"action": "measure", "label": "Measure", "emoji": "!",
				  "icon": "res://Assets/UI/Science/Measure.svg",
				  "hint": "Collapse state (observe)"},
			"R": {"action": "reap", "label": "Reap", "emoji": "^",
				  "icon": "res://Assets/UI/Science/Pop-Harvest.svg",
				  "hint": "Harvest & unbind terminal",
				  "shift_action": "harvest_all", "shift_label": "Harvest All"}
			},
			# GATE MODE: Entanglement infrastructure
			"gate": {
				"Q": {"action": "build_gate", "label": "Build", "emoji": ")(",
					  "icon": "res://Assets/UI/Q-Bit/CNOT.svg",
					  "hint": "Build gate (bell/cluster/cnot)"},
				"E": {"action": "inspect", "label": "Inspect", "emoji": "[]",
					  "icon": "res://Assets/UI/Science/Explore.svg",
					  "hint": "Inspect entanglement"},
				"R": {"action": "remove_gates", "label": "Remove", "emoji": "X",
					  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
					  "hint": "Remove gate infrastructure"}
			},
			# BUILD MODE: Gate infrastructure (merged with industry structures)
			"build": {
				"Q": {"action": "build_gate", "label": "Build", "emoji": ")(",
					  "icon": "res://Assets/UI/Q-Bit/CNOT.svg",
					  "hint": "Build gate infrastructure"},
				"E": {"action": "inspect", "label": "Inspect", "emoji": "[]",
					  "icon": "res://Assets/UI/Science/Explore.svg",
					  "hint": "Inspect gate infrastructure"},
				"R": {"action": "remove_gates", "label": "Remove", "emoji": "X",
					  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
					  "hint": "Remove gate infrastructure"}
			}
		}
	},

	# =========================================================================
	# GROUP 4: META (*) - System/Vocabulary
	# Biome configuration, vocabulary manipulation
	# =========================================================================
	4: {
		"name": "Meta",
		"emoji": "*",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "meta",
		"description": "Vocabulary and biome configuration",
		"has_f_cycling": false,
		"pauses_sim": true,
		"actions": {
			"Q": {"action": "inject_vocabulary", "label": "+Vocab", "emoji": "+",
				  "icon": "res://Assets/UI/Biome/BiomeAssign.svg",
				  "hint": "Inject vocabulary into biome",
				  "submenu": "vocab_injection"},
			"E": {"action": "explore_biome", "label": "Explore", "emoji": "?",
				  "icon": "res://Assets/UI/Science/Explore.svg",
				  "hint": "Explore and unlock a new biome"},
			"R": {"action": "remove_vocabulary", "label": "-Vocab", "emoji": "-",
				  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
				  "hint": "Remove vocabulary from biome"}
		}
	}
}

# ============================================================================
# GROUP MANAGEMENT
# ============================================================================

static func select_group(group_num: int) -> void:
	"""Select a tool group (1-4)."""
	if group_num >= 1 and group_num <= 4:
		current_group = group_num


static func get_current_group() -> int:
	"""Get current tool group number."""
	return current_group


static func get_group(group_num: int) -> Dictionary:
	"""Get tool group definition by number (1-4)."""
	return TOOL_GROUPS.get(group_num, {})


static func get_current_group_def() -> Dictionary:
	"""Get current tool group definition."""
	return TOOL_GROUPS.get(current_group, {})


static func get_group_name(group_num: int) -> String:
	"""Get group name by number."""
	return get_group(group_num).get("name", "Unknown")


static func get_group_emoji(group_num: int) -> String:
	"""Get group emoji by number."""
	return get_group(group_num).get("emoji", "?")


static func get_group_icon_path(group_num: int) -> String:
	"""Get group icon path by number."""
	return get_group(group_num).get("icon", "")


static func does_group_pause_sim(group_num: int) -> bool:
	"""Check if group pauses simulation."""
	return get_group(group_num).get("pauses_sim", false)


static func get_group_time_scale(group_num: int) -> String:
	"""Get time scale type for group."""
	return get_group(group_num).get("time_scale", "")


# ============================================================================
# F-CYCLING (MODE EXPANSION WITHIN GROUPS)
# ============================================================================

static func has_f_cycling(group_num: int) -> bool:
	"""Check if group supports F-cycling."""
	return get_group(group_num).get("has_f_cycling", false)


static func cycle_group_mode(group_num: int) -> int:
	"""Cycle F-mode for a group. Returns new mode index, or -1 if no cycling."""
	var group_def = get_group(group_num)

	if not group_def.get("has_f_cycling", false):
		return -1

	var modes = group_def.get("modes", [])
	if modes.is_empty():
		return -1

	var current_index = group_mode_indices.get(group_num, 0)
	var new_index = (current_index + 1) % modes.size()
	group_mode_indices[group_num] = new_index

	return new_index


static func get_group_mode_index(group_num: int) -> int:
	"""Get current F-mode index for a group."""
	return group_mode_indices.get(group_num, 0)


static func get_group_mode_name(group_num: int) -> String:
	"""Get current F-mode name for a group."""
	var group_def = get_group(group_num)

	if not group_def.get("has_f_cycling", false):
		return ""

	var modes = group_def.get("modes", [])
	var index = group_mode_indices.get(group_num, 0)

	if index < modes.size():
		return modes[index]
	return ""


static func get_group_mode_label(group_num: int) -> String:
	"""Get current F-mode label for UI display."""
	var group_def = get_group(group_num)

	if not group_def.get("has_f_cycling", false):
		return ""

	var mode_labels = group_def.get("mode_labels", [])
	var index = group_mode_indices.get(group_num, 0)

	if index < mode_labels.size():
		return mode_labels[index]
	return ""


static func get_group_mode_emoji(group_num: int) -> String:
	"""Get current F-mode emoji for UI display."""
	var group_def = get_group(group_num)

	if not group_def.get("has_f_cycling", false):
		return ""

	var mode_emojis = group_def.get("mode_emojis", [])
	var index = group_mode_indices.get(group_num, 0)

	if index < mode_emojis.size():
		return mode_emojis[index]
	return ""


static func reset_group_modes() -> void:
	"""Reset all group modes to default (index 0)."""
	for key in group_mode_indices:
		group_mode_indices[key] = 0


# ============================================================================
# ACTION ACCESS
# ============================================================================

static func get_action(group_num: int, key: String) -> Dictionary:
	"""Get action definition for a group and key (Q/E/R).

	For groups with F-cycling, returns action from current mode.
	"""
	var group_def = get_group(group_num)
	if group_def.is_empty():
		return {}

	# Handle F-cycling groups
	if group_def.get("has_f_cycling", false):
		var mode_name = get_group_mode_name(group_num)
		var mode_actions = group_def.get("actions", {}).get(mode_name, {})
		return mode_actions.get(key, {})

	# Non-cycling groups have direct actions
	var actions = group_def.get("actions", {})
	return actions.get(key, {})


static func get_action_label(group_num: int, key: String) -> String:
	"""Get action label for UI display."""
	return get_action(group_num, key).get("label", "")


static func get_action_emoji(group_num: int, key: String) -> String:
	"""Get action emoji for UI display."""
	return get_action(group_num, key).get("emoji", "")


static func get_action_name(group_num: int, key: String) -> String:
	"""Get action name (for dispatching to handlers)."""
	return get_action(group_num, key).get("action", "")


static func get_action_icon(group_num: int, key: String) -> String:
	"""Get action icon path for UI display."""
	return get_action(group_num, key).get("icon", "")


static func get_all_actions(group_num: int) -> Dictionary:
	"""Get all Q/E/R actions for a group (respecting F-cycling mode)."""
	return {
		"Q": get_action(group_num, "Q"),
		"E": get_action(group_num, "E"),
		"R": get_action(group_num, "R")
	}


# ============================================================================
# BACKWARD COMPATIBILITY - Legacy v2 API
# ============================================================================

## Legacy mode tracking (play/build modes deprecated)
static var current_mode: String = "play"

## Legacy tool mode indices
static var tool_mode_indices: Dictionary = {}

## Alias for backward compatibility
const TOOL_ACTIONS = TOOL_GROUPS
const PLAY_TOOLS = TOOL_GROUPS
const BUILD_TOOLS = TOOL_GROUPS

static func toggle_mode() -> String:
	"""Legacy: Toggle mode. Now a no-op, returns 'play'."""
	return "play"


static func get_mode() -> String:
	"""Legacy: Get current mode. Returns 'play'."""
	return "play"


static func set_mode(_mode: String) -> void:
	"""Legacy: Set mode. No-op."""
	pass


static func get_current_tools() -> Dictionary:
	"""Legacy: Get tools. Returns TOOL_GROUPS."""
	return TOOL_GROUPS


static func get_tool(tool_num: int) -> Dictionary:
	"""Legacy: Get tool by number. Maps to get_group."""
	return get_group(tool_num)


static func get_tool_name(tool_num: int) -> String:
	"""Legacy: Get tool name."""
	return get_group_name(tool_num)


static func get_tool_emoji(tool_num: int) -> String:
	"""Legacy: Get tool emoji."""
	return get_group_emoji(tool_num)


static func get_tool_icon_path(tool_num: int) -> String:
	"""Legacy: Get tool icon path."""
	return get_group_icon_path(tool_num)


static func cycle_tool_mode(tool_num: int) -> int:
	"""Legacy: Cycle tool mode."""
	return cycle_group_mode(tool_num)


static func get_tool_mode_index(tool_num: int) -> int:
	"""Legacy: Get tool mode index."""
	return get_group_mode_index(tool_num)


static func get_tool_mode_name(tool_num: int) -> String:
	"""Legacy: Get tool mode name."""
	return get_group_mode_name(tool_num)


static func get_tool_mode_label(tool_num: int) -> String:
	"""Legacy: Get tool mode label."""
	return get_group_mode_label(tool_num)


static func reset_tool_modes() -> void:
	"""Legacy: Reset tool modes."""
	reset_group_modes()


static func get_tool_count() -> int:
	"""Legacy: Get tool count."""
	return 4


# ============================================================================
# BACKWARD COMPATIBILITY - Legacy Submenu API (for FarmInputHandler/ActionValidator)
# ============================================================================

## Legacy submenu definitions (deprecated - use F-cycling in QuantumInstrumentInput)
const SUBMENUS = {}

static func get_submenu(submenu_name_or_tool = null, action_key: String = "") -> Dictionary:
	"""Legacy: Get submenu by name or (tool, key) pair. Returns empty dict (submenus deprecated)."""
	return {}


static func get_dynamic_submenu(_arg1 = null, _arg2 = null, _arg3 = null) -> Dictionary:
	"""Legacy: Get dynamic submenu. Returns empty dict (submenus deprecated)."""
	return {}
