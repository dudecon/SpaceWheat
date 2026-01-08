class_name MinimalTestBiome
extends BiomeBase

## Minimal Hand-Crafted Test Biome
## Just 3 emojis: Sun, Wheat, Water
## Tests the bare minimum compositional setup

func _ready():
	visual_label = "☀🌾💧 Minimal"
	visual_color = Color(0.9, 0.9, 0.5, 0.3)  # Light yellow
	visual_center_offset = Vector2(-200, 0)
	visual_oval_width = 200.0
	visual_oval_height = 120.0

	super._ready()

func _initialize_bath() -> void:
	"""Minimal 3-emoji ecosystem"""

	# Just 3 emojis - hand picked (typed array)
	var emojis: Array[String] = ["☀", "🌾", "💧"]

	# Equal weights
	var weights = {
		"☀": 0.33,
		"🌾": 0.33,
		"💧": 0.34
	}

	# One-liner compositional init
	initialize_bath_from_emojis(emojis, weights)

	# Register pairings for planting
	register_emoji_pair("🌾", "💧")  # Wheat vs water
	register_emoji_pair("☀", "🌾")   # Sun vs wheat

	# Producible
	producible_emojis = ["🌾"]

	print("✅ Minimal biome: %d emojis" % bath.emoji_list.size())

func get_biome_type() -> String:
	return "MinimalTest"

func get_display_name() -> String:
	return "Minimal Test (3 emojis)"
