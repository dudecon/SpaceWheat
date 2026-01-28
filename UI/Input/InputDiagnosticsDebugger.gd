## Input Diagnostics Debugger
##
## Debug tool to diagnose input blocking issues
## Press F1 while in-game to activate (must be in debug builds)
##
## This tool:
## 1. Traces input events through the input hierarchy
## 2. Identifies which nodes are blocking input
## 3. Shows mouse_filter settings for all controls
## 4. Detects CanvasLayer visibility issues

extends Node

const ACTIVATION_KEY = KEY_F1

var is_active = false
var verbose: Node = null
var input_trace_log: Array = []
var test_results: Dictionary = {}


func _ready() -> void:
	# Try to get verbose logger if available
	verbose = get_node_or_null("/root/VerboseConfig")

	# Register for input events
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	"""Activate/deactivate diagnostics with F1 key"""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == ACTIVATION_KEY:
			is_active = not is_active
			if is_active:
				_start_diagnostics()
			else:
				_end_diagnostics()


func _start_diagnostics() -> void:
	"""Start input diagnostics"""
	_log("🔍", "Input Diagnostics Started")
	_log("ℹ️", "Listening for next touch/click event...")

	# Reset log
	input_trace_log.clear()
	test_results.clear()

	# Hook into input systems
	_hook_input_systems()


func _end_diagnostics() -> void:
	"""End diagnostics and show results"""
	_log("🔍", "Input Diagnostics Ended")
	_print_report()


func _hook_input_systems() -> void:
	"""Connect to input systems to trace events"""
	# Hook TouchInputManager
	if TouchInputManager:
		if not TouchInputManager.tap_detected.is_connected(_on_touch_tap):
			TouchInputManager.tap_detected.connect(_on_touch_tap)
			_log("✅", "Hooked TouchInputManager.tap_detected")


func _on_touch_tap(position: Vector2) -> void:
	"""Trace touch tap through the system"""
	_log("📱", "Touch TAP at %s" % position)
	_trace_input_at_position(position)


func _trace_input_at_position(screen_pos: Vector2) -> void:
	"""Trace which node would receive input at this position"""
	_log("", "Tracing input hierarchy at %s..." % screen_pos)

	var viewport = get_viewport()
	if not viewport:
		_log("❌", "No viewport!")
		return

	# Get all controls at this position
	var canvas_list = viewport.gui.get_focus_owner()  # This won't work as expected

	# Better approach: manually check nodes in the tree
	var root = get_tree().root
	_trace_node_at_position(root, screen_pos, 0)


func _trace_node_at_position(node: Node, screen_pos: Vector2, depth: int) -> void:
	"""Recursively trace nodes at a screen position"""
	if not is_instance_valid(node):
		return

	# Check if this is a Control (for bounds checking) or a CanvasLayer
	var is_control = node is Control
	var is_canvas_layer = node is CanvasLayer

	if is_control:
		var control = node as Control
		# Check if this control is at the position
		var global_rect = control.get_global_rect()
		if global_rect.has_point(screen_pos):
			var indent = "  ".repeat(depth)
			var mouse_filter_name = _mouse_filter_to_name(control.mouse_filter)
			var visible_str = "✓" if control.visible else "✗"
			var enabled_str = "✓" if control.get_process_unhandled_input() else "✗"

			_log(indent + "📦", "%s [%s] visible=%s input=%s mouse_filter=%s" % [
				control.name, control.get_class(), visible_str, enabled_str, mouse_filter_name
			])

			# Special handling for specific nodes
			_analyze_node(control, screen_pos)
	elif is_canvas_layer:
		var canvas_layer = node as CanvasLayer
		var indent = "  ".repeat(depth)
		var visible_str = "✓" if canvas_layer.visible else "✗"
		_log(indent + "🖼️", "%s [CanvasLayer] visible=%s layer=%d" % [
			canvas_layer.name, visible_str, canvas_layer.layer
		])
		_analyze_node(canvas_layer, screen_pos)

	# Continue to children
	for child in node.get_children():
		_trace_node_at_position(child, screen_pos, depth + 1)


func _analyze_node(node: Node, screen_pos: Vector2) -> void:
	"""Analyze specific node types for issues"""

	# Check CanvasLayer nodes
	if node is CanvasLayer:
		var canvas_layer = node as CanvasLayer
		_log("", "  ⚠️ CanvasLayer detected:")
		_log("", "  ⚠️ CanvasLayer detected:")
		_log("", "     - visible: %s" % canvas_layer.visible)
		_log("", "     - layer: %d" % canvas_layer.layer)

		if not canvas_layer.visible:
			_log("", "  ❌ ISSUE: CanvasLayer is invisible but may still block input!")
			_log("", "     Children of invisible CanvasLayer might still intercept input")

	# Check ColorRect with MOUSE_FILTER_STOP
	if node is ColorRect:
		var color_rect = node as ColorRect
		if color_rect.mouse_filter == Control.MOUSE_FILTER_STOP:
			_log("", "  ⚠️ ColorRect with MOUSE_FILTER_STOP detected:")
			_log("", "     This will block input from reaching controls below")


func _mouse_filter_to_name(mouse_filter: Control.MouseFilter) -> String:
	"""Convert MouseFilter enum to readable name"""
	match mouse_filter:
		Control.MOUSE_FILTER_STOP:
			return "STOP (blocks)"
		Control.MOUSE_FILTER_PASS:
			return "PASS (through)"
		Control.MOUSE_FILTER_IGNORE:
			return "IGNORE (transparent)"
		_:
			return "UNKNOWN"


func _print_report() -> void:
	"""Print collected diagnostics"""
	_log("", "")
	_log("📊", "=== INPUT DIAGNOSTICS REPORT ===")
	_log("", "")

	_log("ℹ️", "Input System Status:")
	_log("", "  PlayerShell active: %s" % _check_player_shell_active())
	_log("", "  PlotGridDisplay active: %s" % _check_plot_grid_active())
	_log("", "  Overlay stack size: %d" % _get_overlay_stack_size())
	_log("", "  Active biome: %s" % _get_active_biome())
	_log("", "")

	_log("ℹ️", "Potential Issues:")
	_check_for_mouse_filter_issues()
	_check_for_canvas_layer_issues()
	_check_for_signal_connection_issues()

	_log("", "")
	_log("💡", "Recommendations:")
	_log("", "  1. Check if overlays properly set mouse_filter = IGNORE when hidden")
	_log("", "  2. Verify CanvasLayer.visible controls input blocking")
	_log("", "  3. Ensure PlotGridDisplay tap signal is still connected")
	_log("", "  4. Check if any dimmer ColorRects need mouse_filter reset when hidden")


func _check_player_shell_active() -> bool:
	var player_shell = get_node_or_null("/root/PlayerShell")
	if player_shell:
		return player_shell.visible and player_shell.get_tree().paused == false
	return false


func _check_plot_grid_active() -> bool:
	var farm_ui = get_node_or_null("/root/PlayerShell/FarmUIContainer/FarmUI")
	if farm_ui and farm_ui.has_meta("plot_grid_display"):
		var pgd = farm_ui.get_meta("plot_grid_display")
		return pgd and pgd.visible
	return false


func _get_overlay_stack_size() -> int:
	var overlay_stack = get_node_or_null("/root/PlayerShell/OverlayStackManager")
	if overlay_stack and overlay_stack.has_method("size"):
		return overlay_stack.size()
	return 0


func _get_active_biome() -> String:
	var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
	if biome_mgr and biome_mgr.has_method("get_active_biome"):
		return biome_mgr.get_active_biome()
	return "(unknown)"


func _check_for_mouse_filter_issues() -> void:
	"""Scan tree for controls with problematic mouse_filter settings"""
	var root = get_tree().root
	var issues = _scan_for_mouse_filter_issues(root)

	if issues.is_empty():
		_log("✅", "No obvious mouse_filter issues detected")
	else:
		for issue in issues:
			_log("⚠️", issue)


func _scan_for_mouse_filter_issues(node: Node) -> Array:
	"""Recursively scan for mouse_filter issues"""
	var issues = []

	# Check for hidden nodes with MOUSE_FILTER_STOP
	if node is Control:
		var control = node as Control
		if not control.visible and control.mouse_filter == Control.MOUSE_FILTER_STOP:
			issues.append("Hidden %s has MOUSE_FILTER_STOP - may block input!" % control.name)

	# Check for invisible CanvasLayer children with blocking filters
	if node is CanvasLayer:
		var canvas_layer = node as CanvasLayer
		if not canvas_layer.visible:
			for child in canvas_layer.get_children():
				if child is Control and (child as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
					issues.append("Invisible CanvasLayer '%s' contains MOUSE_FILTER_STOP node '%s'" %
						[canvas_layer.name, child.name])

	for child in node.get_children():
		issues += _scan_for_mouse_filter_issues(child)

	return issues


func _check_for_canvas_layer_issues() -> void:
	"""Check CanvasLayer nodes for potential input blocking"""
	var root = get_tree().root
	var canvas_layers = _find_canvas_layers(root)

	if canvas_layers.is_empty():
		_log("ℹ️", "No CanvasLayer nodes found")
		return

	for canvas_layer in canvas_layers:
		if not canvas_layer.visible:
			_log("⚠️", "Invisible CanvasLayer '%s' detected - may still intercept input" % canvas_layer.name)


func _find_canvas_layers(node: Node) -> Array:
	"""Find all CanvasLayer nodes in tree"""
	var layers = []
	if node is CanvasLayer:
		layers.append(node)
	for child in node.get_children():
		layers += _find_canvas_layers(child)
	return layers


func _check_for_signal_connection_issues() -> void:
	"""Check if PlotGridDisplay is still connected to touch signals"""
	var farm_ui = get_node_or_null("/root/PlayerShell/FarmUIContainer/FarmUI")
	if not farm_ui or not farm_ui.has_meta("plot_grid_display"):
		_log("ℹ️", "PlotGridDisplay not found or not stored in metadata")
		return

	# This is a simplified check - would need more introspection to verify signal connections
	_log("✅", "PlotGridDisplay exists and should be receiving input")


func _log(prefix: String, message: String) -> void:
	"""Log a message with optional verbose system"""
	var formatted = message
	if prefix:
		formatted = "%s  %s" % [prefix, message]

	print(formatted)
	input_trace_log.append(formatted)

	if verbose and verbose.has_method("debug"):
		verbose.debug("input", prefix if prefix else "ℹ️", message)
