extends Control

## Performance HUD - Display QuantumForceGraph profiling data in real-time
## Shows bottlenecks and frame timing breakdowns from GPU V2 system

const PANEL_BG_COLOR: Color = Color(0.08, 0.10, 0.18, 0.92)
const PANEL_BORDER_COLOR: Color = Color(0.9, 0.4, 0.4, 0.7)  # Red border for perf warnings
const PANEL_PADDING: int = 8
const UPDATE_INTERVAL: int = 30  # Update display every 30 frames (~0.5s at 60fps)

var graph_ref = null  # QuantumForceGraph reference
var frame_counter: int = 0

# Performance logging to file (silent console mode)
var _perf_log_file: FileAccess = null
var _perf_log_path: String = ""

# UI elements
var panel: PanelContainer
var vbox: VBoxContainer
var header_label: Label
var process_label: Label
var draw_label: Label
var budget_label: Label
var bottleneck_label: Label

func _ready() -> void:
	_build_ui()
	set_process(true)
	_open_perf_log()

func _exit_tree() -> void:
	"""Close performance log file on cleanup."""
	if _perf_log_file:
		_perf_log_file.close()
		_perf_log_file = null

func _open_perf_log() -> void:
	"""Open performance log file for writing."""
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")

	# Use absolute path to logs directory
	var log_dir = ProjectSettings.globalize_path("res://logs")

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(log_dir):
		DirAccess.make_dir_absolute(log_dir)

	_perf_log_path = "%s/perf_godot_%s.log" % [log_dir, timestamp]
	_perf_log_file = FileAccess.open(_perf_log_path, FileAccess.WRITE)
	if _perf_log_file:
		_perf_log_file.store_line("=== Godot Performance Log Started: %s ===" % Time.get_datetime_string_from_system())
		_perf_log_file.store_line("Frame | FPS | TIME_PROCESS (ms) | TIME_PHYSICS (ms) | Nodes | Orphans")
		_perf_log_file.store_line("=".repeat(80))
		VerboseConfig.info("perf_hud", "📝", "Logging to: %s" % _perf_log_path)
	else:
		VerboseConfig.warn("perf_hud", "📝", "Failed to open log file: %s" % _perf_log_path)

func _log_perf(message: String) -> void:
	"""Write performance data to log file (silent - no console spam)."""
	if _perf_log_file:
		_perf_log_file.store_line(message)
		_perf_log_file.flush()  # Ensure data is written immediately

func _process(_delta: float) -> void:
	frame_counter += 1

	# Update display every UPDATE_INTERVAL frames
	if frame_counter % UPDATE_INTERVAL != 0:
		return

	# Find graph if not yet referenced
	if not graph_ref:
		_locate_graph()

	if not graph_ref:
		_show_no_data()
		return

	# Get performance data from QuantumForceGraph
	_update_display()

func _locate_graph() -> void:
	"""Find QuantumForceGraph in the scene tree."""
	var root = get_tree().root if get_tree() else null
	if not root:
		VerboseConfig.error("perf_hud", "🔬", "ERROR: No scene tree root")
		return

	# Try FarmView → QuantumForceGraph (direct - no controller)
	var farm_view = root.get_node_or_null("/root/FarmView")
	if not farm_view:
		# FarmView might be under Farm
		var farm = root.get_node_or_null("/root/Farm")
		if farm:
			farm_view = farm.get_node_or_null("FarmView")

	if farm_view:
		VerboseConfig.debug("perf_hud", "🔬", "Found FarmView at: %s" % farm_view.get_path())
		if "quantum_viz" in farm_view and farm_view.quantum_viz:
			# quantum_viz is now QuantumForceGraph directly (no controller middleman)
			graph_ref = farm_view.quantum_viz
			VerboseConfig.debug("perf_hud", "🔬", "✅ Found QuantumForceGraph (direct): %s" % graph_ref.get_path())
			return
		else:
			VerboseConfig.error("perf_hud", "🔬", "ERROR: FarmView has no quantum_viz")
	else:
		VerboseConfig.error("perf_hud", "🔬", "ERROR: Could not find FarmView")

	# Fallback: search for QuantumForceGraph directly
	VerboseConfig.debug("perf_hud", "🔬", "Searching for QuantumForceGraph in root children...")
	for child in root.get_children():
		VerboseConfig.debug("perf_hud", "🔬", "  - %s" % child.name)
		if child.name == "QuantumForceGraph":
			graph_ref = child
			VerboseConfig.debug("perf_hud", "🔬", "✅ Found QuantumForceGraph via fallback: %s" % graph_ref.get_path())
			return

	VerboseConfig.error("perf_hud", "🔬", "ERROR: QuantumForceGraph not found anywhere!")

func _update_display() -> void:
	"""Update performance display with current data."""
	var fps = Engine.get_frames_per_second()

	# Collect Godot engine metrics
	var time_process = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0  # Convert to ms
	var time_physics = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphan_nodes = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	# Log detailed metrics to file (silent - no console spam)
	_log_perf("%6d | %3d | %8.2f | %8.2f | %5d | %5d" % [
		frame_counter, fps, time_process, time_physics, node_count, orphan_nodes
	])

	# If graph is available, also show graph-specific data
	if not graph_ref or not "_perf_samples" in graph_ref:
		_show_engine_metrics_only(fps, time_process, time_physics, node_count)
		return

	var samples = graph_ref._perf_samples

	# Calculate averages
	var avg = {}
	for key in samples:
		var sample_array = samples[key]
		if sample_array.size() > 0:
			var total = 0.0
			for s in sample_array:
				total += s
			avg[key] = total / sample_array.size() / 1000.0  # Convert to ms
		else:
			avg[key] = 0.0

	# Get Godot engine performance metrics
	var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var render_cpu = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var render_primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var render_draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	# Get batcher stats (if available)
	var batcher_stats = ""
	var batcher = get_node_or_null("/root/GameStateManager/Farm/BiomeEvolutionBatcher") if get_tree() else null
	if not batcher:
		# Try alternate path
		var farm = get_node_or_null("/root/Farm")
		if farm and "biome_evolution_batcher" in farm:
			batcher = farm.biome_evolution_batcher

	if batcher:
		var batch_queue_size = batcher.lookahead_batch_queue.size() if "lookahead_batch_queue" in batcher else 0
		var batches_in_flight = batcher._batches_in_flight.size() if "_batches_in_flight" in batcher else 0
		var buffer_state = ""
		if "_buffer_state" in batcher:
			var state_val = batcher._buffer_state
			buffer_state = ["RECOVERY", "COAST"][state_val] if state_val < 2 else "UNKNOWN"
		batcher_stats = " | Batches: queue=%d in_flight=%d state=%s" % [batch_queue_size, batches_in_flight, buffer_state]

	# Print to console for easy grepping
	var frame_num = graph_ref.frame_count if "frame_count" in graph_ref else 0
	VerboseConfig.debug("perf_hud", "🔬", "═══════════════════════════════════════════════════════════")
	VerboseConfig.debug("perf_hud", "🔬", "Frame %d | FPS: %.0f%s" % [frame_num, fps, batcher_stats])
	VerboseConfig.debug("perf_hud", "🔬", "ENGINE: process=%.2fms physics=%.2fms" % [process_time, physics_time])

	# Update header
	header_label.text = "🔬 Performance (Frame %d | %.0f FPS)" % [frame_num, fps]

	# Frame budget (use ENGINE metrics for accuracy)
	var frame_ms = 1000.0 / fps if fps > 0 else 100.0
	var graph_process = avg.get("process_total", 0)
	var graph_draw = avg.get("draw_total", 0)
	var graph_total = graph_process + graph_draw

	# Calculate what's NOT tracked by QuantumForceGraph
	# This includes: UI processing, input handling, other nodes, engine overhead
	var other_process = maxf(0, process_time - graph_process)
	var ui_and_other = other_process  # Everything except QuantumForceGraph

	var budget_pct = (process_time / 16.67) * 100.0

	budget_label.text = "📊 Budget: %.1fms / 16.67ms (%d%%)\n   Graph: %.1fms | UI+Other: %.1fms | Physics: %.1fms" % [
		process_time, int(budget_pct), graph_total, ui_and_other, physics_time
	]

	# _process breakdown
	var process_ms = avg.get("process_total", 0)
	var process_viewport = avg.get("process_viewport", 0)
	var process_context = avg.get("process_context", 0)
	var process_visuals = avg.get("process_visuals", 0)
	var process_forces = avg.get("process_forces", 0)

	process_label.text = "⚙️ Process: %.1fms total\n" % process_time
	process_label.text += "   Graph: %.2fms\n" % graph_total
	process_label.text += "   UI+Other: %.2fms\n" % ui_and_other
	process_label.text += "   Physics: %.2fms" % physics_time

	# _draw breakdown
	var draw_ms = avg.get("draw_total", 0)
	var draw_bubble = avg.get("draw_bubble", 0)
	var draw_edge = avg.get("draw_edge", 0)
	var draw_flush = avg.get("draw_flush", 0)
	var draw_region = avg.get("draw_region", 0)

	draw_label.text = "🎨 Draw: %.2fms\n" % draw_ms
	draw_label.text += "   Bubbles: %.2fms\n" % draw_bubble
	draw_label.text += "   Edges: %.2fms\n" % draw_edge
	draw_label.text += "Rendering: %d calls" % int(render_draw_calls)

	# Identify bottlenecks
	var bottlenecks: Array = []

	# Graph-specific bottlenecks
	if process_visuals > 2.0:
		bottlenecks.append("🚨 Graph Visuals: %.1fms" % process_visuals)
	if process_context + avg.get("draw_context", 0) > 1.0:
		bottlenecks.append("🚨 Context Build: %.1fms" % (process_context + avg.get("draw_context", 0)))
	if draw_edge > 3.0:
		bottlenecks.append("🚨 Edge Rendering: %.1fms" % draw_edge)
	if draw_bubble > 5.0:
		bottlenecks.append("🚨 Bubble Rendering: %.1fms" % draw_bubble)

	# System-level bottlenecks
	if ui_and_other > 10.0:
		bottlenecks.append("🚨 UI+Input: %.1fms" % ui_and_other)
	if physics_time > 10.0:
		bottlenecks.append("🚨 Physics: %.1fms" % physics_time)
	if render_draw_calls > 1000:
		bottlenecks.append("🚨 Draw Calls: %d" % int(render_draw_calls))

	# Get UI component breakdown
	var ui_tracker = get_node_or_null("/root/UIPerformanceTracker")
	var ui_breakdown = {}
	if ui_tracker:
		ui_breakdown = ui_tracker.get_all_averages()

	# Print console summary
	VerboseConfig.debug("perf_hud", "🔬", "Total: %.1fms (Graph:%.1f UI:%.1f Phys:%.1f)" % [
		process_time, graph_total, ui_and_other, physics_time
	])
	VerboseConfig.debug("perf_hud", "🔬", "Graph._process: %.2fms (viewport:%.2f ctx:%.2f vis:%.2f forces:%.2f)" % [
		process_ms, process_viewport, process_context, process_visuals, process_forces
	])
	VerboseConfig.debug("perf_hud", "🔬", "Graph._draw: %.2fms (bubble:%.2f edge:%.2f region:%.2f flush:%.2f)" % [
		draw_ms, draw_bubble, draw_edge, draw_region, draw_flush
	])
	VerboseConfig.debug("perf_hud", "🔬", "Rendering: %d objs, %d primitives, %d draw calls" % [
		int(render_cpu), int(render_primitives), int(render_draw_calls)
	])

	# Print UI component breakdown if available
	if not ui_breakdown.is_empty():
		VerboseConfig.debug("perf_hud", "🔬", "UI Components:")
		var sorted_ui = ui_breakdown.keys()
		sorted_ui.sort_custom(func(a, b): return ui_breakdown[a] > ui_breakdown[b])
		for component in sorted_ui:
			var time_ms = ui_breakdown[component]
			if time_ms > 0.01:  # Lower threshold to see all components
				VerboseConfig.debug("perf_hud", "🔬", "   %s: %.2fms" % [component, time_ms])

	# Print Godot's built-in node timing data
	VerboseConfig.debug("perf_hud", "🔬", "Top expensive nodes (Godot internal):")
	var root = get_tree().root
	_profile_node_tree(root, 0, 3)  # Profile up to 3 levels deep

	if bottlenecks.size() > 0:
		VerboseConfig.warn("perf_hud", "🔬", "⚠️  BOTTLENECKS: " + ", ".join(bottlenecks))
		bottleneck_label.text = "⚠️ Bottlenecks:\n   " + "\n   ".join(bottlenecks)
		bottleneck_label.visible = true
		# Change border color to red when bottlenecks detected
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = Color(0.9, 0.2, 0.2, 0.9)
	else:
		VerboseConfig.debug("perf_hud", "🔬", "✅ No bottlenecks detected")
		bottleneck_label.visible = false
		# Green border when all good
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = Color(0.2, 0.9, 0.4, 0.7)

	VerboseConfig.debug("perf_hud", "🔬", "═══════════════════════════════════════════════════════════")

func _show_engine_metrics_only(fps: int, time_process: float, time_physics: float, node_count: int) -> void:
	"""Display engine metrics when graph data is unavailable."""
	header_label.text = "⚡ Engine Metrics (Frame %d)" % frame_counter
	process_label.text = "TIME_PROCESS: %.2fms" % time_process
	draw_label.text = "TIME_PHYSICS: %.2fms" % time_physics
	budget_label.text = "Nodes: %d | FPS: %d" % [node_count, fps]

	# Show bottleneck warnings
	var target_frame_time = 16.67  # 60 FPS target
	if time_process > target_frame_time:
		bottleneck_label.text = "🚨 Process %.2fms over budget" % time_process
		bottleneck_label.visible = true
	else:
		bottleneck_label.text = "✅ Frame budget OK"
		bottleneck_label.visible = true


func _show_no_data() -> void:
	"""Display 'no data' message."""
	header_label.text = "🔬 Performance"
	budget_label.text = "No data available"
	process_label.text = "(Waiting for QuantumForceGraph...)"
	draw_label.text = ""
	bottleneck_label.visible = false

func _build_ui() -> void:
	"""Build the HUD UI elements."""
	anchors_preset = Control.PRESET_TOP_RIGHT
	offset_left = -320  # 300px width + 20px margin
	offset_top = 16
	offset_right = -16
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 200)

	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG_COLOR
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = PANEL_BORDER_COLOR
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)

	vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)

	# Create labels
	header_label = _create_label("🔬 Performance", Color(0.95, 0.95, 0.95), true)
	budget_label = _create_label("Loading...", Color(1.0, 0.8, 0.3))
	process_label = _create_label("", Color(0.8, 0.9, 1.0))
	draw_label = _create_label("", Color(0.9, 0.8, 1.0))
	bottleneck_label = _create_label("", Color(1.0, 0.4, 0.4))
	bottleneck_label.visible = false

	vbox.add_child(header_label)
	vbox.add_child(_create_separator())
	vbox.add_child(budget_label)
	vbox.add_child(_create_separator())
	vbox.add_child(process_label)
	vbox.add_child(draw_label)
	vbox.add_child(_create_separator())
	vbox.add_child(bottleneck_label)

	margin.add_child(vbox)
	panel.add_child(margin)
	add_child(panel)

func _profile_node_tree(node: Node, depth: int, max_depth: int) -> void:
	"""Recursively profile node tree to find expensive nodes.

	Shows which nodes have _process and _draw methods that might be costly.
	"""
	if depth > max_depth:
		return

	var indent = "  ".repeat(depth)

	# Check if node has _process or _draw
	var has_process = node.has_method("_process")
	var has_draw = node.has_method("_draw")

	if (has_process or has_draw) and node is CanvasItem:
		var node_type = node.get_class()
		var marker = ""
		if has_process:
			marker += "P"
		if has_draw:
			marker += "D"

		# Only show Control nodes (UI elements)
		if node is Control:
			VerboseConfig.debug("perf_hud", "🔬", " %s[%s] %s (%s)" % [indent, marker, node.name, node_type])

	# Recurse to children
	for child in node.get_children():
		_profile_node_tree(child, depth + 1, max_depth)


func _create_label(text_value: String, color: Color, bold: bool = false) -> Label:
	"""Create a styled label."""
	var label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", color)
	label.text = text_value

	# Use monospace font for better alignment
	var font_size = 13 if bold else 11
	label.add_theme_font_size_override("font_size", font_size)

	return label

func _create_separator() -> HSeparator:
	"""Create a visual separator."""
	var sep = HSeparator.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.4, 0.3)
	sep.add_theme_stylebox_override("separator", style)
	return sep
