class_name DualBiome
extends BiomeBase

## Dual Biome: BioticFlux + Market Merge
## Tests 2-way emoji set merging

func _ready():
	visual_label = "🌾💰 Dual"
	visual_color = Color(0.7, 0.7, 0.3, 0.3)  # Yellow-gold blend
	visual_center_offset = Vector2(0, 200)
	visual_oval_width = 300.0
	visual_oval_height = 185.0

	super._ready()

func _initialize_bath() -> void:
	"""Merge BioticFlux + Market emoji sets"""

	# BioticFlux set (typed array)
	var bioticflux: Array[String] = ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]

	# Market set (typed array)
	var market: Array[String] = ["🐂", "🐻", "💰", "📦", "🏛️", "🏚️"]

	# Merge (no overlap - fully disjoint)
	var merged = BiomeBase.merge_emoji_sets(bioticflux, market)

	print("🌾💰 Dual merge: %d + %d = %d emojis" % [
		bioticflux.size(),
		market.size(),
		merged.size()
	])

	# Initialize with balanced weights
	initialize_bath_from_emojis(merged, {
		# BioticFlux
		"☀": 0.12,
		"🌙": 0.08,
		"🌾": 0.10,
		"🍄": 0.10,
		"💀": 0.05,
		"🍂": 0.05,

		# Market
		"🐂": 0.12,
		"🐻": 0.12,
		"💰": 0.10,
		"📦": 0.08,
		"🏛️": 0.04,
		"🏚️": 0.04
	})

	# Register pairings from both biomes
	register_emoji_pair("🌾", "👥")   # Wheat (BioticFlux)
	register_emoji_pair("🍄", "🍂")   # Mushroom (BioticFlux)
	register_emoji_pair("🐂", "🐻")   # Bull/Bear (Market)
	register_emoji_pair("💰", "📦")   # Money/Goods (Market)

	# Producible from both
	producible_emojis = ["🌾", "🍄", "💰"]

	print("✅ Dual biome: %d total emojis" % bath.emoji_list.size())

func get_biome_type() -> String:
	return "Dual"

func get_display_name() -> String:
	return "Dual (BioticFlux + Market)"
