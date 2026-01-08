class_name TestBiome
extends BiomeBase

## TestBiome: Isolated quantum bath for unassigned plots
## - No physics/evolution (no Hamiltonian, no Lindblad)
## - Bath with all known emojis
## - Visual: Small grey circle around plot

# Unique identifier for this test biome
var test_biome_id: int = 0
var plot_position: Vector2i = Vector2i.ZERO

func _init(id: int, pos: Vector2i) -> void:
	test_biome_id = id
	plot_position = pos

	# Visual properties - small grey circle
	visual_color = Color(0.5, 0.5, 0.5, 0.15)
	visual_label = ""  # No label
	visual_oval_width = 50.0  # Small circle
	visual_oval_height = 50.0
	visual_center_offset = Vector2.ZERO  # Will be set to plot position

func _initialize_bath() -> void:
	print("🧪 Initializing TestBiome #%d at %s..." % [test_biome_id, plot_position])

	bath = QuantumBath.new()

	# Initialize with ALL known emojis from the autoload singleton
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if icon_registry == null:
		push_error("🧪 TestBiome: IconRegistry not available!")
		# Fallback to basic emojis
		bath.initialize_with_emojis(["🌾", "👥"])
	else:
		var all_emojis = icon_registry.get_all_emojis()
		bath.initialize_with_emojis(all_emojis)
		print("  ✅ TestBiome bath: %d emojis, 0 icons (no evolution)" % all_emojis.size())

	bath.initialize_uniform()  # Start in uniform superposition

	# NO ICONS - no physics, no evolution
	bath.active_icons = []

func get_biome_type() -> String:
	return "TestBiome_%d" % test_biome_id
