extends Node2D

## Quick visual rendering test - SKIPS ATLAS to diagnose rendering issues

const TestBootManager = preload("res://Tests/TestBootManager.gd")
const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")

var boot_manager: TestBootManager = null
var biomes: Dictionary = {}
var batcher = null
var lookahead_engine = null
var force_graph: QuantumForceGraph = null
var frame = 0
var window_ready: bool = false

func _ready():
	print("\n" + "=".repeat(70))
	print("QUICK VISUAL TEST - NO ATLAS")
	print("=".repeat(70))

	# Create boot manager
	boot_manager = TestBootManager.new()
	boot_manager.boot_progress.connect(_on_boot_progress)

	# Wait for window
	print("\n[PHASE 0] Waiting for window...")

func _on_boot_progress(stage: String, message: String):
	print("[%s] %s" % [stage, message])

func _process(delta):
	frame += 1

	# Wait for window
	if not window_ready:
		if frame % 30 == 0:
			var window_size = DisplayServer.window_get_size()
			if window_size.x > 0 and window_size.y > 0:
				window_ready = true
				print("Window ready! Starting boot (skipping atlas)...")
				_start_boot_no_atlas()
			else:
				print("Waiting for window... %s" % window_size)
		return

	# Boot complete - just queue redraw
	queue_redraw()

	if frame % 60 == 0 and force_graph:
		var fps = Engine.get_frames_per_second()
		var bubble_count = force_graph.quantum_nodes.size()
		print("[F%d] %.0f FPS | %d bubbles" % [frame, fps, bubble_count])

func _start_boot_no_atlas():
	"""Boot with SKIP_VISUALIZATION to prevent atlas building hang"""
	print("\n[BOOT] Starting biomes (atlas disabled)...")

	var biome_names = [
		"CyberDebtMegacity",
		"StellarForges",
		"VolcanicWorlds",
		"BioticFlux"
	]

	# Call boot_biomes with skip_visualization=true (line 4 param)
	var result = await boot_manager.boot_biomes(self, biome_names, true)  # SKIP atlas!

	if result.get("success", false):
		biomes = result.get("biomes", {})
		batcher = result.get("batcher")
		lookahead_engine = result.get("lookahead_engine")

		print("\n[VIZ] Creating QuantumForceGraph (text fallback for emojis)...")
		force_graph = QuantumForceGraph.new()
		force_graph.name = "ForceGraph"
		add_child(force_graph)
		force_graph.setup(biomes, null, null)
		force_graph.biome_evolution_batcher = batcher
		force_graph.render_all_biomes = true
		force_graph.update_layout(true)

		# Manually create emoji/bubble atlas stubs (use text fallback)
		var EmojiAtlasBatcherClass = preload("res://Core/Visualization/EmojiAtlasBatcher.gd")
		var emoji_atlas = EmojiAtlasBatcherClass.new()
		emoji_atlas._atlas_built = false  # Force text fallback
		force_graph.emoji_atlas_batcher = emoji_atlas

		var BubbleAtlasBatcherClass = preload("res://Core/Visualization/BubbleAtlasBatcher.gd")
		var bubble_atlas = BubbleAtlasBatcherClass.new()
		bubble_atlas.build_atlas()  # This should work (no SubViewport)
		force_graph.set_bubble_atlas_batcher(bubble_atlas)

		print("\n[RUNNING] Ready! Bubbles using text fallback for emojis")
		print("  Bubbles: %d" % force_graph.quantum_nodes.size())
		print("  Emoji rendering: TEXT FALLBACK (no atlas)")
	else:
		print("[BOOT FAILED] %s" % result.get("error", "unknown"))

func _draw():
	if force_graph:
		# Just a timestamp
		var pos = Vector2(10, 30)
		var text = "Frame %d | %.0f FPS" % [frame, Engine.get_frames_per_second()]
		draw_string(ThemeDB.fallback_font, pos, text)
