class_name GateSelectionSubmenu
extends RefCounted

## Gate Selection Submenu
## Dynamic submenu for Tool 3 Gate Mode Q action
## Shows available entangling gates based on selection count
##
## Selection-aware options:
## - 2 qubits: Bell, CNOT, CZ, SWAP
## - 3+ qubits: GHZ, Cluster, plus 2-qubit options

const BaseSubmenu = preload("res://UI/Core/Submenus/BaseSubmenu.gd")


static func generate_submenu(biome, farm, selection: Array, page: int = 0) -> Dictionary:
	"""Generate gate selection submenu.

	Args:
		biome: Current biome (for context)
		farm: Farm instance
		selection: Array of selected positions (Vector2i) in ORDER
		page: Page for F-cycling

	Returns:
		Submenu with gate options appropriate for selection count
	"""
	if selection.size() < 2:
		return BaseSubmenu.empty_submenu(
			"gate_selection",
			"Build Gate",
			"Select 2+ qubits"
		)

	var options = _collect_options(selection)
	options = _sort_options(options)

	var pagination = BaseSubmenu.paginate(options, page)
	var actions = BaseSubmenu.build_actions(pagination.page_options, _build_gate_action)

	return BaseSubmenu.build_result(
		"gate_selection",
		"Build Gate",
		pagination,
		actions,
		{"selection_count": selection.size()}
	)


static func _collect_options(selection: Array) -> Array:
	"""Collect available gate types based on selection count."""
	var count = selection.size()
	var options: Array = []

	# 2-qubit gates (always available when 2+ selected)
	options.append({
		"gate_type": "bell",
		"label": "Bell",
		"hint": "(|00>+|11>)/sqrt2",
		"emoji": ")(",
		"icon": "res://Assets/UI/Q-Bit/CNOT.svg",
		"qubits_required": 2,
		"enabled": count >= 2
	})

	options.append({
		"gate_type": "cnot",
		"label": "CNOT",
		"hint": "Flip target if control=1",
		"emoji": "->",
		"icon": "res://Assets/UI/Q-Bit/CNOT.svg",
		"qubits_required": 2,
		"enabled": count >= 2
	})

	options.append({
		"gate_type": "cz",
		"label": "CZ",
		"hint": "Phase if both=1",
		"emoji": "CZ",
		"icon": "res://Assets/UI/Q-Bit/CZ.svg",
		"qubits_required": 2,
		"enabled": count >= 2
	})

	options.append({
		"gate_type": "swap",
		"label": "SWAP",
		"hint": "Exchange qubit states",
		"emoji": "<>",
		"icon": "res://Assets/UI/Q-Bit/SWAP.svg",
		"qubits_required": 2,
		"enabled": count >= 2
	})

	# Multi-qubit gates (3+)
	if count >= 3:
		options.append({
			"gate_type": "ghz",
			"label": "GHZ",
			"hint": "(|000>+|111>)/sqrt2 (%d qubits)" % count,
			"emoji": "GHZ",
			"icon": "res://Assets/UI/Q-Bit/GHZ.svg",
			"qubits_required": count,
			"enabled": true
		})

		options.append({
			"gate_type": "cluster",
			"label": "Cluster",
			"hint": "Linear cluster (%d qubits)" % count,
			"emoji": "---",
			"icon": "res://Assets/UI/Q-Bit/Cluster.svg",
			"qubits_required": count,
			"enabled": true
		})

	return options


static func _sort_options(options: Array) -> Array:
	"""Sort options - enabled first, then by qubit requirement."""
	# First sort by qubits required (ascending)
	options = BaseSubmenu.sort_by_field(options, "qubits_required", false)
	# Then put enabled options first
	options = BaseSubmenu.sort_enabled_first(options)
	return options


static func _build_gate_action(option: Dictionary) -> Dictionary:
	"""Build action data for a gate option."""
	return {
		"action": "build_gate",
		"gate_type": option.get("gate_type", "bell"),
		"label": option.get("label", ""),
		"hint": option.get("hint", ""),
		"emoji": option.get("emoji", ""),
		"icon": option.get("icon", ""),
		"enabled": option.get("enabled", true),
		"qubits_required": option.get("qubits_required", 2)
	}
