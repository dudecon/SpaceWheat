class_name TripleBiome
extends BiomeBase

## Triple Biome: BioticFlux + Market + Kitchen Merge
## Tests 3-way emoji set merging with some overlaps

func _ready():
	visual_label = "🌾💰🍞 Triple"
	visual_color = Color(0.6, 0.6, 0.6, 0.3)  # Mixed gray
	visual_center_offset = Vector2(200, 0)
	visual_oval_width = 350.0
	visual_oval_height = 216.0

	super._ready()

func _initialize_bath() -> void:
	"""Merge BioticFlux + Market + Kitchen emoji sets"""

	# BioticFlux set (typed array)
	var bioticflux: Array[String] = ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]

	# Market set (typed array)
	var market: Array[String] = ["🐂", "🐻", "💰", "📦", "🏛️", "🏚️"]

	# Kitchen set (note: 🌾 overlaps with BioticFlux!) (typed array)
	var kitchen: Array[String] = ["🔥", "❄️", "🍞", "🌾"]

	# Triple merge (cascade)
	var step1 = BiomeBase.merge_emoji_sets(bioticflux, market)
	var merged = BiomeBase.merge_emoji_sets(step1, kitchen)

	print("🌾💰🍞 Triple merge: %d + %d + %d = %d emojis" % [
		bioticflux.size(),
		market.size(),
		kitchen.size(),
		merged.size()
	])
	print("  (Overlap: 🌾 shared between BioticFlux and Kitchen)")

	# Initialize with balanced weights
	initialize_bath_from_emojis(merged, {
		# BioticFlux
		"☀": 0.10,
		"🌙": 0.06,
		"🌾": 0.12,  # Shared with Kitchen
		"🍄": 0.08,
		"💀": 0.04,
		"🍂": 0.04,

		# Market
		"🐂": 0.10,
		"🐻": 0.10,
		"💰": 0.08,
		"📦": 0.06,
		"🏛️": 0.03,
		"🏚️": 0.03,

		# Kitchen
		"🔥": 0.06,
		"❄️": 0.06,
		"🍞": 0.04
	})

	# Register pairings from all three biomes
	register_emoji_pair("🌾", "👥")   # Wheat (BioticFlux)
	register_emoji_pair("🍄", "🍂")   # Mushroom (BioticFlux)
	register_emoji_pair("🐂", "🐻")   # Bull/Bear (Market)
	register_emoji_pair("💰", "📦")   # Money/Goods (Market)
	register_emoji_pair("🔥", "❄️")   # Fire/Cold (Kitchen)
	register_emoji_pair("🍞", "🌾")   # Bread/Wheat (Kitchen)

	# Producible from all three
	producible_emojis = ["🌾", "🍄", "💰", "🍞"]

	print("✅ Triple biome: %d total emojis" % bath.emoji_list.size())

func get_biome_type() -> String:
	return "Triple"

func get_display_name() -> String:
	return "Triple (BioticFlux + Market + Kitchen)"
