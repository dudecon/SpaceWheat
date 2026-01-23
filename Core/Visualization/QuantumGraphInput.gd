class_name QuantumGraphInput
extends RefCounted

## Quantum Graph Input Handler
##
## Handles user input on the quantum force graph:
## - Bubble taps (selection, measurement)
## - Bubble swipes (drag operations)
## - Hit detection


signal bubble_tapped(node)
signal bubble_swiped(node, direction)
signal node_swiped_to(from_grid_pos: Vector2i, to_grid_pos: Vector2i)

# Swipe tracking state
var _swipe_start_pos: Vector2 = Vector2.ZERO
var _swipe_start_node = null
var _is_swiping: bool = false
const SWIPE_THRESHOLD: float = 30.0  # Minimum distance to register swipe


func get_node_at_position(pos: Vector2, quantum_nodes: Array):
	"""Get quantum node at screen position (for hover/click).

	Args:
	    pos: Screen position to check
	    quantum_nodes: Array of QuantumNode instances

	Returns:
	    QuantumNode at position, or null if none found
	"""
	for node in quantum_nodes:
		if not node.visible:
			continue

		var distance = node.position.distance_to(pos)
		if distance <= node.radius:
			return node

	return null


func handle_input(event: InputEvent, ctx: Dictionary) -> bool:
	"""Handle input events on the quantum graph.

	Args:
	    event: The input event
	    ctx: Context dictionary with {quantum_nodes, etc.}

	Returns:
	    true if event was handled
	"""
	var quantum_nodes = ctx.get("quantum_nodes", [])

	if event is InputEventMouseButton:
		return _handle_mouse_button(event, quantum_nodes)

	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event, quantum_nodes)

	if event is InputEventScreenTouch:
		return _handle_touch(event, quantum_nodes)

	if event is InputEventScreenDrag:
		return _handle_screen_drag(event, quantum_nodes)

	return false


func _handle_mouse_button(event: InputEventMouseButton, quantum_nodes: Array) -> bool:
	"""Handle mouse button events."""
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false

	if event.pressed:
		# Start potential swipe
		_swipe_start_pos = event.position
		_swipe_start_node = get_node_at_position(event.position, quantum_nodes)
		_is_swiping = _swipe_start_node != null
		return _is_swiping
	else:
		# Release - check if it was a swipe or tap
		if _is_swiping and _swipe_start_node:
			var end_node = get_node_at_position(event.position, quantum_nodes)
			var distance = _swipe_start_pos.distance_to(event.position)

			if end_node and end_node != _swipe_start_node and distance >= SWIPE_THRESHOLD:
				# Swipe from one node to another
				node_swiped_to.emit(_swipe_start_node.grid_position, end_node.grid_position)
				bubble_swiped.emit(_swipe_start_node, (event.position - _swipe_start_pos).normalized())
			elif distance < SWIPE_THRESHOLD:
				# Was a tap, not a swipe
				bubble_tapped.emit(_swipe_start_node)

		_is_swiping = false
		_swipe_start_node = null
		return true

	return false


func _handle_mouse_motion(event: InputEventMouseMotion, quantum_nodes: Array) -> bool:
	"""Handle mouse motion for swipe tracking."""
	# Just track - actual swipe detection happens on release
	return false


func _handle_touch(event: InputEventScreenTouch, quantum_nodes: Array) -> bool:
	"""Handle touch events."""
	if event.pressed:
		# Start potential swipe
		_swipe_start_pos = event.position
		_swipe_start_node = get_node_at_position(event.position, quantum_nodes)
		_is_swiping = _swipe_start_node != null
		return _is_swiping
	else:
		# Release - check if it was a swipe or tap
		if _is_swiping and _swipe_start_node:
			var end_node = get_node_at_position(event.position, quantum_nodes)
			var distance = _swipe_start_pos.distance_to(event.position)

			if end_node and end_node != _swipe_start_node and distance >= SWIPE_THRESHOLD:
				# Swipe from one node to another
				node_swiped_to.emit(_swipe_start_node.grid_position, end_node.grid_position)
				bubble_swiped.emit(_swipe_start_node, (event.position - _swipe_start_pos).normalized())
			elif distance < SWIPE_THRESHOLD:
				# Was a tap, not a swipe
				bubble_tapped.emit(_swipe_start_node)

		_is_swiping = false
		_swipe_start_node = null
		return true

	return false


func _handle_screen_drag(event: InputEventScreenDrag, quantum_nodes: Array) -> bool:
	"""Handle screen drag for swipe tracking."""
	# Just track - actual swipe detection happens on release
	return false


func highlight_node(node) -> void:
	"""Highlight a quantum node (called when classical plot hovered).

	Currently a placeholder - visual effects handled by rendering.
	"""
	pass


func get_stats(quantum_nodes: Array, node_by_plot_id: Dictionary) -> Dictionary:
	"""Get statistics about the quantum graph.

	Args:
	    quantum_nodes: Array of all quantum nodes
	    node_by_plot_id: Dictionary mapping plot_id to nodes

	Returns:
	    Dictionary with {total_nodes, active_nodes, total_entanglements}
	"""
	var active_nodes = 0
	var total_entanglements = 0

	for node in quantum_nodes:
		if node.plot and node.plot.is_planted and node.plot.quantum_state:
			active_nodes += 1
			total_entanglements += node.plot.entangled_plots.size()

	return {
		"total_nodes": quantum_nodes.size(),
		"active_nodes": active_nodes,
		"total_entanglements": total_entanglements / 2  # Bidirectional
	}


func print_snapshot(quantum_nodes: Array, node_by_plot_id: Dictionary, reason: String = "") -> void:
	"""Print a snapshot of the current graph state."""
	var stats = get_stats(quantum_nodes, node_by_plot_id)

	print("\n⚛️ ===== QUANTUM GRAPH SNAPSHOT =====")
	if reason != "":
		print("Reason: %s" % reason)
	print("Total nodes: %d" % stats.total_nodes)
	print("Active (planted): %d" % stats.active_nodes)
	print("Entanglements: %d" % stats.total_entanglements)

	if stats.total_entanglements > 0:
		print("Entangled pairs:")
		var printed_pairs = {}
		for node in quantum_nodes:
			if not node.plot:
				continue
			for partner_id in node.plot.entangled_plots.keys():
				var partner_node = node_by_plot_id.get(partner_id)
				if partner_node:
					var ids = [node.plot_id, partner_id]
					ids.sort()
					var pair_key = "%s_%s" % [ids[0], ids[1]]
					if not printed_pairs.has(pair_key):
						print("  %s ↔ %s" % [node.grid_position, partner_node.grid_position])
						printed_pairs[pair_key] = true

	print("===================================\n")
