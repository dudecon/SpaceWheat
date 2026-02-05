class_name ActionDispatcher
extends RefCounted

## ActionDispatcher - Central action dispatch with handler delegation
##
## Replaces 48 _action_* wrapper methods with a dispatch table.
## Maps action names to handler classes and methods.
##
## Usage:
##   var dispatcher = ActionDispatcher.new()
##   dispatcher.action_completed.connect(_on_action_completed)
##   var result = dispatcher.execute("apply_pauli_x", farm, positions, {})

# Handler preloads
const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")
const MeasurementHandler = preload("res://UI/Handlers/MeasurementHandler.gd")
const LindbladHandler = preload("res://UI/Handlers/LindbladHandler.gd")
const BiomeHandler = preload("res://UI/Handlers/BiomeHandler.gd")
const IconHandler = preload("res://UI/Handlers/IconHandler.gd")
const SystemHandler = preload("res://UI/Handlers/SystemHandler.gd")
const ProbeHandler = preload("res://UI/Handlers/ProbeHandler.gd")

# Signals
signal action_completed(action: String, success: bool, message: String, result: Dictionary)


## ============================================================================
## DISPATCH TABLE
## ============================================================================
## Format: action_name -> [handler_name, method_name, success_message_template]
## Templates can use {key} placeholders that will be replaced with result values.

const DISPATCH_TABLE = {
	# ═══════════════════════════════════════════════════════════════════════════
	# PROBE ACTIONS (Tool 1)
	# ═══════════════════════════════════════════════════════════════════════════
	"explore": ["ProbeHandler", "explore", "Discovered {explored_count} registers"],
	"measure": ["ProbeHandler", "measure", "Measured {measured_count} terminals"],
	"pop": ["ProbeHandler", "pop", "Harvested {popped_count} terminals (+{total_credits} credits)"],

	# ═══════════════════════════════════════════════════════════════════════════
	# GATE ACTIONS - Single Qubit (Tool 2)
	# ═══════════════════════════════════════════════════════════════════════════
	"apply_pauli_x": ["GateActionHandler", "apply_pauli_x", "Applied Pauli-X to {applied_count} qubits"],
	"apply_pauli_y": ["GateActionHandler", "apply_pauli_y", "Applied Pauli-Y to {applied_count} qubits"],
	"apply_pauli_z": ["GateActionHandler", "apply_pauli_z", "Applied Pauli-Z to {applied_count} qubits"],
	"apply_hadamard": ["GateActionHandler", "apply_hadamard", "Applied Hadamard to {applied_count} qubits"],
	"apply_s_gate": ["GateActionHandler", "apply_s_gate", "Applied S-gate to {applied_count} qubits"],
	"apply_t_gate": ["GateActionHandler", "apply_t_gate", "Applied T-gate to {applied_count} qubits"],
	"apply_sdg_gate": ["GateActionHandler", "apply_sdg_gate", "Applied S-dagger to {applied_count} qubits"],
	"apply_rx_gate": ["GateActionHandler", "apply_rx_gate", "Applied Rx-gate to {applied_count} qubits"],
	"apply_ry_gate": ["GateActionHandler", "apply_ry_gate", "Applied Ry-gate to {applied_count} qubits"],
	"apply_ry": ["GateActionHandler", "apply_ry_gate", "Applied Ry-gate to {applied_count} qubits"],
	"apply_rz_gate": ["GateActionHandler", "apply_rz_gate", "Applied Rz-gate to {applied_count} qubits"],

	# ═══════════════════════════════════════════════════════════════════════════
	# GATE ACTIONS - Two Qubit (Tool 3)
	# ═══════════════════════════════════════════════════════════════════════════
	"apply_cnot": ["GateActionHandler", "apply_cnot", "Applied CNOT to {pair_count} pairs"],
	"apply_cz": ["GateActionHandler", "apply_cz", "Applied CZ to {pair_count} pairs"],
	"apply_swap": ["GateActionHandler", "apply_swap", "Applied SWAP to {pair_count} pairs"],
	"create_bell_pair": ["GateActionHandler", "create_bell_pair", "Created Bell pair"],
	"disentangle": ["GateActionHandler", "disentangle", "Disentangled {disentangled_count} qubits"],
	"inspect_entanglement": ["GateActionHandler", "inspect_entanglement", "Inspected entanglement"],
	"cluster": ["GateActionHandler", "cluster", "Built cluster with {entanglement_count} entanglements"],

	# ═══════════════════════════════════════════════════════════════════════════
	# MEASUREMENT ACTIONS
	# ═══════════════════════════════════════════════════════════════════════════
	"measure_trigger": ["MeasurementHandler", "measure_trigger", "Set trigger with {target_count} targets"],
	"remove_gates": ["MeasurementHandler", "remove_gates", "Removed {removed_count} gate configs"],

	# ═══════════════════════════════════════════════════════════════════════════
	# BIOME ACTIONS (BUILD Tool 1)
	# ═══════════════════════════════════════════════════════════════════════════
	"clear_biome_assignment": ["BiomeHandler", "clear_biome_assignment", "Cleared {cleared_count} plots"],
	"inspect_plot": ["BiomeHandler", "inspect_plot", "Inspected {count} plots"],
	"inject_vocabulary": ["BiomeHandler", "inject_vocabulary", "Injected {north_emoji}/{south_emoji} into {biome}"],
	"explore_biome": ["BiomeHandler", "explore_biome", "Discovered {biome_name}!"],

	# ═══════════════════════════════════════════════════════════════════════════
	# ICON ACTIONS (BUILD Tool 2)
	# ═══════════════════════════════════════════════════════════════════════════
	"icon_swap": ["IconHandler", "icon_swap", "Swapped icons on {swap_count} plots"],
	"icon_clear": ["IconHandler", "icon_clear", "Cleared icons on {clear_count} plots"],

	# ═══════════════════════════════════════════════════════════════════════════
	# LINDBLAD ACTIONS (BUILD Tool 3)
	# ═══════════════════════════════════════════════════════════════════════════
	"lindblad_drive": ["LindbladHandler", "lindblad_drive", "Drive on {driven_count} plots"],
	"lindblad_decay": ["LindbladHandler", "lindblad_decay", "Decay on {decayed_count} plots"],
	"lindblad_transfer": ["LindbladHandler", "lindblad_transfer", "Transfer: {from_emoji} -> {to_emoji}"],
	"pump_to_wheat": ["LindbladHandler", "pump_to_wheat", "Pumped wheat on {pump_count} plots"],

	# ═══════════════════════════════════════════════════════════════════════════
	# SYSTEM ACTIONS (BUILD Tool 4)
	# ═══════════════════════════════════════════════════════════════════════════
	"system_reset": ["SystemHandler", "system_reset", "Reset {biome_name} to ground state"],
	"system_snapshot": ["SystemHandler", "system_snapshot", "Snapshot: {biome_name} (dim={dimension})"],
	"system_debug": ["SystemHandler", "system_debug", "Debug mode toggled"],
	"peek_state": ["SystemHandler", "peek_state", "State peeked"],

}


## ============================================================================
## EXECUTE ACTION
## ============================================================================

func execute(
	action: String,
	farm,
	positions: Array[Vector2i],
	extra: Dictionary = {}
) -> Dictionary:
	"""Execute an action through the dispatch table.

	Args:
		action: Action name (e.g., "apply_pauli_x")
		farm: Farm instance
		positions: Selected plot positions
		extra: Extra parameters (e.g., current_selection, mill_state)

	Returns:
		Result dictionary from handler
	"""
	if not DISPATCH_TABLE.has(action):
		var result = {
			"success": false,
			"error": "unknown_action",
			"message": "Unknown action: %s" % action
		}
		action_completed.emit(action, false, result.message, result)
		return result

	var dispatch = DISPATCH_TABLE[action]
	var handler_name = dispatch[0]
	var method_name = dispatch[1]
	var success_template = dispatch[2]

	# Get handler and call method
	var result = _call_handler(handler_name, method_name, farm, positions, extra)

	# Format message
	var msg = ""
	if result.success:
		msg = _format_message(success_template, result)
	else:
		msg = result.get("message", "Action failed")

	action_completed.emit(action, result.success, msg, result)
	return result


func _call_handler(
	handler_name: String,
	method_name: String,
	farm,
	positions: Array[Vector2i],
	extra: Dictionary
) -> Dictionary:
	"""Call the appropriate handler method."""
	match handler_name:
		"ProbeHandler":
			return _call_probe_handler(method_name, farm, positions, extra)
		"GateActionHandler":
			return _call_gate_handler(method_name, farm, positions)
		"MeasurementHandler":
			return _call_measurement_handler(method_name, farm, positions)
		"BiomeHandler":
			return _call_biome_handler(method_name, farm, positions, extra)
		"IconHandler":
			return _call_icon_handler(method_name, farm, positions, extra)
		"LindbladHandler":
			return _call_lindblad_handler(method_name, farm, positions)
		"SystemHandler":
			return _call_system_handler(method_name, farm, positions, extra)
		_:
			return {"success": false, "error": "unknown_handler", "message": "Unknown handler: %s" % handler_name}


func _call_probe_handler(method_name: String, farm, positions: Array[Vector2i], extra: Dictionary) -> Dictionary:
	"""Route to ProbeHandler methods."""
	var terminal_pool = farm.terminal_pool if farm else null
	var economy = farm.economy if farm else null
	var current_selection = extra.get("current_selection", Vector2i.ZERO)

	match method_name:
		"explore":
			return ProbeHandler.explore(farm, terminal_pool, positions)
		"measure":
			return ProbeHandler.measure(farm, terminal_pool, positions)
		"pop":
			return ProbeHandler.pop(farm, terminal_pool, economy, positions)
		_:
			return {"success": false, "error": "unknown_method"}


func _call_gate_handler(method_name: String, farm, positions: Array[Vector2i]) -> Dictionary:
	"""Route to GateActionHandler methods."""
	match method_name:
		"apply_pauli_x":
			return GateActionHandler.apply_pauli_x(farm, positions)
		"apply_pauli_y":
			return GateActionHandler.apply_pauli_y(farm, positions)
		"apply_pauli_z":
			return GateActionHandler.apply_pauli_z(farm, positions)
		"apply_hadamard":
			return GateActionHandler.apply_hadamard(farm, positions)
		"apply_s_gate":
			return GateActionHandler.apply_s_gate(farm, positions)
		"apply_t_gate":
			return GateActionHandler.apply_t_gate(farm, positions)
		"apply_sdg_gate":
			return GateActionHandler.apply_sdg_gate(farm, positions)
		"apply_rx_gate":
			return GateActionHandler.apply_rx_gate(farm, positions)
		"apply_ry_gate":
			return GateActionHandler.apply_ry_gate(farm, positions)
		"apply_rz_gate":
			return GateActionHandler.apply_rz_gate(farm, positions)
		"apply_cnot":
			return GateActionHandler.apply_cnot(farm, positions)
		"apply_cz":
			return GateActionHandler.apply_cz(farm, positions)
		"apply_swap":
			return GateActionHandler.apply_swap(farm, positions)
		"create_bell_pair":
			return GateActionHandler.create_bell_pair(farm, positions)
		"disentangle":
			return GateActionHandler.disentangle(farm, positions)
		"inspect_entanglement":
			return GateActionHandler.inspect_entanglement(farm, positions)
		"cluster":
			return GateActionHandler.cluster(farm, positions)
		_:
			return {"success": false, "error": "unknown_method"}


func _call_measurement_handler(method_name: String, farm, positions: Array[Vector2i]) -> Dictionary:
	"""Route to MeasurementHandler methods."""
	match method_name:
		"measure_trigger":
			return MeasurementHandler.measure_trigger(farm, positions)
		"remove_gates":
			return MeasurementHandler.remove_gates(farm, positions)
		_:
			return {"success": false, "error": "unknown_method"}


func _call_biome_handler(method_name: String, farm, positions: Array[Vector2i], extra: Dictionary) -> Dictionary:
	"""Route to BiomeHandler methods."""
	match method_name:
		"clear_biome_assignment":
			return BiomeHandler.clear_biome_assignment(farm, positions)
		"inspect_plot":
			return BiomeHandler.inspect_plot(farm, positions)
		"inject_vocabulary":
			var vocab_pair = extra.get("vocab_pair", {})
			return BiomeHandler.inject_vocabulary(farm, positions, vocab_pair)
		"explore_biome":
			return BiomeHandler.explore_biome(farm, positions)
		_:
			return {"success": false, "error": "unknown_method"}


func _call_icon_handler(method_name: String, farm, positions: Array[Vector2i], extra: Dictionary) -> Dictionary:
	"""Route to IconHandler methods."""
	var gsm = extra.get("game_state_manager")

	match method_name:
		"icon_swap":
			return IconHandler.icon_swap(farm, positions)
		"icon_clear":
			return IconHandler.icon_clear(farm, positions)
		"icon_assign":
			var emoji = extra.get("emoji", "")
			return IconHandler.icon_assign(farm, positions, emoji, gsm)
		_:
			return {"success": false, "error": "unknown_method"}


func _call_lindblad_handler(method_name: String, farm, positions: Array[Vector2i]) -> Dictionary:
	"""Route to LindbladHandler methods."""
	match method_name:
		"lindblad_drive":
			return LindbladHandler.lindblad_drive(farm, positions)
		"lindblad_decay":
			return LindbladHandler.lindblad_decay(farm, positions)
		"lindblad_transfer":
			return LindbladHandler.lindblad_transfer(farm, positions)
		"pump_to_wheat":
			return LindbladHandler.pump_to_wheat(farm, positions)
		_:
			return {"success": false, "error": "unknown_method"}


func _call_system_handler(method_name: String, farm, positions: Array[Vector2i], extra: Dictionary) -> Dictionary:
	"""Route to SystemHandler methods."""
	var current_selection = extra.get("current_selection", Vector2i.ZERO)

	match method_name:
		"system_reset":
			return SystemHandler.system_reset(farm, positions, current_selection)
		"system_snapshot":
			return SystemHandler.system_snapshot(farm, positions, current_selection)
		"system_debug":
			return SystemHandler.system_debug(farm, positions, current_selection)
		"peek_state":
			return SystemHandler.peek_state(farm, positions)
		_:
			return {"success": false, "error": "unknown_method"}


## ============================================================================
## MESSAGE FORMATTING
## ============================================================================

func _format_message(template: String, result: Dictionary) -> String:
	"""Format success message template with result values."""
	var msg = template
	for key in result:
		var placeholder = "{%s}" % key
		if msg.contains(placeholder):
			msg = msg.replace(placeholder, str(result[key]))
	return msg


## ============================================================================
## SPECIAL ACTIONS (not in dispatch table)
## ============================================================================

func execute_assign_biome(farm, biome_name: String, positions: Array[Vector2i]) -> Dictionary:
	"""Execute biome assignment action."""
	var result = BiomeHandler.assign_plots_to_biome(farm, positions, biome_name)
	var msg = ""
	if result.success:
		msg = "%d plots -> %s" % [result.assigned_count, biome_name]
	else:
		msg = result.get("message", "Assignment failed")
	action_completed.emit("assign_to_%s" % biome_name, result.success, msg, result)
	return result


func execute_icon_assign(farm, emoji: String, positions: Array[Vector2i], gsm = null) -> Dictionary:
	"""Execute icon assignment action."""
	var result = IconHandler.icon_assign(farm, positions, emoji, gsm)
	var msg = ""
	if result.success:
		msg = "Added %s/%s to quantum system" % [result.get("north_emoji", "?"), result.get("south_emoji", "?")]
	else:
		msg = result.get("message", "Assignment failed")
	action_completed.emit("icon_assign_%s" % emoji, result.success, msg, result)
	return result
