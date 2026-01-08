class_name MergedEcosystem_Biome
extends BiomeBase

## Example Merged Biome: BioticFlux + Forest
##
## Demonstrates compositional bath construction by merging emoji sets
## from multiple base biomes. The bath automatically gets the composite
## Icon dynamics (Hamiltonian + Lindblad operators) from all included emojis.

func _ready():
	# Visual configuration
	visual_label = "🌲🌾 Merged"
	visual_color = Color(0.4, 0.7, 0.5, 0.3)  # Green blend
	visual_center_offset = Vector2(0, 0)
	visual_oval_width = 400.0  # Larger oval for merged ecosystem
	visual_oval_height = 250.0

	super._ready()

func _initialize_bath() -> void:
	"""Initialize bath by merging BioticFlux + Forest emoji sets

	This demonstrates the compositional architecture:
	1. Each base biome defines its emoji list
	2. merge_emoji_sets() creates the union
	3. initialize_bath_from_emojis() builds composite operators from Icons
	"""

	# BioticFlux emoji set (typed array)
	var bioticflux_emojis: Array[String] = ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]

	# Forest emoji set (simplified - full forest has 22 emojis) (typed array)
	var forest_emojis: Array[String] = ["🌲", "🐺", "🐰", "🦌", "🌿", "💧", "⛰", "🍂"]

	# Merge (union with dedup - 🍂 appears in both)
	var merged_emojis = BiomeBase.merge_emoji_sets(bioticflux_emojis, forest_emojis)

	print("🌲🌾 Merging ecosystems: %d + %d = %d emojis" % [
		bioticflux_emojis.size(),
		forest_emojis.size(),
		merged_emojis.size()
	])

	# Initialize bath with merged set
	# Icons automatically provide composite Hamiltonian + Lindblad
	initialize_bath_from_emojis(merged_emojis, {
		# BioticFlux weights
		"☀": 0.15,
		"🌙": 0.10,
		"🌾": 0.12,
		"🍄": 0.12,
		"💀": 0.05,

		# Forest weights
		"🌲": 0.10,
		"🐺": 0.05,
		"🐰": 0.08,
		"🦌": 0.05,
		"🌿": 0.08,
		"💧": 0.05,
		"⛰": 0.03,

		# Shared (organic matter)
		"🍂": 0.12
	})

	# Register emoji pairings for planting
	register_emoji_pair("🌾", "👥")  # Wheat farming
	register_emoji_pair("🍄", "🍂")  # Mushroom composting
	register_emoji_pair("🐺", "🐰")  # Predator-prey
	register_emoji_pair("🌲", "🌿")  # Forest growth
	register_emoji_pair("☀", "🌙")  # Day-night cycle

	# Register producible resources
	producible_emojis = ["🌾", "🍄", "🌿", "🐰"]  # Can harvest these

	print("✅ Merged ecosystem initialized: %d total emojis" % bath.emoji_list.size())


func get_biome_type() -> String:
	return "MergedEcosystem"


func get_display_name() -> String:
	return "Merged Ecosystem (BioticFlux + Forest)"
