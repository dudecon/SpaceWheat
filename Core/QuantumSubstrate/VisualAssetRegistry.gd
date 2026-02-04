extends Node

## VisualAssetRegistry: Central registry for emoji → visual asset mappings
##
## Provides automatic fallback chain: SVG glyph → emoji text
## All emoji strings remain source of truth in game logic
##
## Usage:
##   var texture = VisualAssetRegistry.get_texture("🌾")
##   if texture:
##       draw_texture_rect(texture, rect, false, color)
##   else:
##       draw_string(font, pos, "🌾", ...)  # Automatic fallback
##
## Adding new mappings:
##   Just add one line in _load_asset_mappings():
##   register("🆕", "res://Assets/UI/Category/NewGlyph.svg")

# Cache of loaded textures (emoji → CompressedTexture2D)
var _texture_cache: Dictionary = {}

# Mapping registry (emoji → res:// path)
var _emoji_to_svg: Dictionary = {}

# Fallback font for emoji text rendering
var _fallback_font: Font = null

# Stats tracking
var _load_attempts: int = 0
var _load_successes: int = 0
var _load_failures: int = 0


func _ready():
	_fallback_font = ThemeDB.fallback_font
	print("🎨 VisualAssetRegistry initializing...")
	_load_asset_mappings()
	print("🎨 Registered %d emoji→SVG mappings" % _emoji_to_svg.size())


func _load_asset_mappings():
	"""Register all available emoji → SVG path mappings.

	Organization:
	- Resources: Economic/harvestable items (Wheat, Flour, Lumber, Power)
	- Elements: Nature forces (Fire, Water, Wind)
	- Celestial: Day/night cycle (Sun, Moon)
	- Nature: Biome elements (Vegetation, Seedling, Decay, Forest)
	- Tools: Conceptual tools (coming soon)
	- Economic: Faction/economy (coming soon)
	"""

	# === TIER 1: Resources & Nature (13 glyphs) ===

	# Resources (economic/harvestable)
	register("💨", "res://Assets/UI/Resources/Flour.svg")
	register("🌾", "res://Assets/UI/Resources/Wheat.svg")
	register("🪵", "res://Assets/UI/Resources/Lumber.svg")
	register("⚡", "res://Assets/UI/Resources/Power.svg")

	# Elements (mill power sources + nature forces)
	register("🔥", "res://Assets/UI/Elements/Fire.svg")
	register("💧", "res://Assets/UI/Elements/Water.svg")
	register("🌬️", "res://Assets/UI/Elements/Wind.svg")

	# Celestial (quantum axes - sun/moon qubit)
	register("☀", "res://Assets/UI/Celestial/Sun.svg")
	register("🌙", "res://Assets/UI/Celestial/Moon.svg")

	# Nature (biome ecosystem)
	register("🌿", "res://Assets/UI/Nature/Vegetation.svg")
	register("🌱", "res://Assets/UI/Nature/Seedling.svg")
	register("🍂", "res://Assets/UI/Nature/Decay.svg")
	register("🌲", "res://Assets/UI/Nature/Forest.svg")

	# === TIER 2: Conceptual Tools (8 glyphs) ===
	# Core tool identifiers from ToolConfig
	register("🔬", "res://Assets/UI/Tools/Spec.svg")        # Tool 0: Probe/Measure
	register("🔗", "res://Assets/UI/Tools/Fabric.svg")      # Tool 3: Entangle
	register("⚙️", "res://Assets/UI/Tools/Efficiency.svg")  # Tool 5: Icon Config, Mill operations
	register("🏭", "res://Assets/UI/Tools/Station.svg")     # Tool 4: Industry

	# Additional conceptual glyphs
	register("🛠️", "res://Assets/UI/Tools/Tools.svg")       # Generic tools
	register("💻", "res://Assets/UI/Tools/Code.svg")        # Code/programming

	# === TIER 3: Economic/Faction Systems (8 glyphs) ===
	# High-frequency faction emojis (from factions.json)
	register("💰", "res://Assets/UI/Economic/Wealth.svg")   # 9 factions - CRITICAL
	register("📡", "res://Assets/UI/Economic/Signal.svg")   # 8 factions - communication
	register("⚖️", "res://Assets/UI/Economic/Justice.svg")  # 6 factions - balance/law
	register("🗝️", "res://Assets/UI/Economic/Lock.svg")     # 5 factions - access/keys

	# Additional economic/governance glyphs
	register("🔒", "res://Assets/UI/Economic/Lock.svg")     # Lock emoji (same glyph as key)
	register("👥", "res://Assets/UI/Economic/Authority.svg") # Authority/people (3 factions)
	register("⚖", "res://Assets/UI/Economic/Law.svg")       # Law (alt justice glyph)


func register(emoji: String, svg_path: String) -> void:
	"""Register an emoji → SVG path mapping.

	Args:
	    emoji: The emoji string (source of truth identifier)
	    svg_path: res:// path to SVG file

	Note: If file doesn't exist, warning is logged but registration succeeds.
	      The texture will fail to load later, triggering text fallback.
	"""
	if not FileAccess.file_exists(svg_path):
		push_warning("🎨 VisualAssetRegistry: SVG not found (will use emoji fallback): %s → %s" % [emoji, svg_path])
		return  # Don't register if file doesn't exist

	_emoji_to_svg[emoji] = svg_path
	# print("  ✓ Registered: %s → %s" % [emoji, svg_path])


func get_texture(emoji: String) -> Texture2D:
	"""Get texture for emoji, loading and caching if needed.

	Returns:
	    CompressedTexture2D if SVG mapping exists and loads successfully
	    null if no mapping exists (triggers emoji text fallback)

	The null return is intentional - it enables the fallback chain:
	    var tex = VisualAssetRegistry.get_texture("🌾")
	    if tex: draw_texture(...)
	    else: draw_string(..., "🌾", ...)
	"""
	# Check cache first (fast path)
	if _texture_cache.has(emoji):
		return _texture_cache[emoji]

	# No SVG mapping registered
	if not _emoji_to_svg.has(emoji):
		return null

	# Load texture (with graceful fallback for missing files)
	var svg_path = _emoji_to_svg[emoji]
	_load_attempts += 1

	# Check if file exists before loading (prevents error spam)
	if not ResourceLoader.exists(svg_path):
		# File missing - silently fall back to emoji text rendering
		_load_failures += 1
		return null

	var texture = load(svg_path) as Texture2D
	if texture:
		_texture_cache[emoji] = texture
		_load_successes += 1
		# print("  ✓ Loaded texture: %s" % emoji)
		return texture
	else:
		push_warning("🎨 VisualAssetRegistry: Failed to load SVG (using emoji fallback): %s → %s" % [emoji, svg_path])
		_load_failures += 1
		return null


func has_texture(emoji: String) -> bool:
	"""Check if an SVG texture mapping is registered for this emoji.

	Note: Does not guarantee the texture will load successfully.
	      Use get_texture() and check for null to handle load failures.
	"""
	return _emoji_to_svg.has(emoji)


func get_fallback_font() -> Font:
	"""Get the fallback font for emoji text rendering."""
	return _fallback_font


func preload_common_textures(emoji_list: Array = []) -> void:
	"""Preload frequently used textures for performance.

	Args:
	    emoji_list: Array of emoji strings to preload
	                If empty, uses default common set

	Call this during loading screens or biome initialization.
	"""
	var common = emoji_list
	if common.is_empty():
		# Default common emojis (biome essentials)
		common = ["🌾", "👥", "🍄", "☀", "🌙", "🔥", "💧", "🌬️", "🍂", "🌲"]

	var preloaded = 0
	for emoji in common:
		if get_texture(emoji):  # Loads and caches
			preloaded += 1

	print("🎨 Preloaded %d/%d common textures" % [preloaded, common.size()])


func debug_cache_stats() -> void:
	"""Print cache statistics for debugging."""
	print("\n=== VisualAssetRegistry Stats ===")
	print("Registered mappings: %d" % _emoji_to_svg.size())
	print("Cached textures: %d" % _texture_cache.size())
	print("Load attempts: %d" % _load_attempts)
	print("Load successes: %d" % _load_successes)
	print("Load failures: %d" % _load_failures)
	if _load_attempts > 0:
		print("Success rate: %.1f%%" % (_load_successes / float(_load_attempts) * 100.0))
	print("==================================\n")


func list_unmapped_emojis(emoji_list: Array) -> Array:
	"""Returns emojis that don't have SVG mappings yet.

	Useful for identifying which emojis still need glyphs created.
	"""
	var unmapped = []
	for emoji in emoji_list:
		if not has_texture(emoji):
			unmapped.append(emoji)
	return unmapped
