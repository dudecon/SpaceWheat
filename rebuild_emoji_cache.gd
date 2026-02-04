extends SceneTree

## Headless emoji cache rebuild script
## Run with: godot --headless -s rebuild_emoji_cache.gd

func _init():
	print("[CacheRebuild] Starting headless emoji atlas cache rebuild...")

	# Load EmojiRegistry to get all emojis
	const EmojiRegistry = preload("res://Core/Biomes/EmojiRegistry.gd")
	var registry = EmojiRegistry.new()

	var biome_emojis = registry.get_biome_emojis()
	var faction_emojis = registry.get_faction_emojis()

	print("[CacheRebuild] Found %d biome emojis" % biome_emojis.size())
	print("[CacheRebuild] Found %d faction emojis" % faction_emojis.size())

	# Merge emoji lists
	var emoji_set = {}
	for emoji in biome_emojis:
		emoji_set[emoji] = true
	for emoji in faction_emojis:
		emoji_set[emoji] = true

	var all_emojis = emoji_set.keys()
	print("[CacheRebuild] Total unique: %d emojis" % all_emojis.size())

	# In headless mode, we can't actually render emojis to textures
	# But we can create a minimal cache that marks the cache as invalid
	# This will force a rebuild on first GUI launch

	print("[CacheRebuild] ⚠️  Cannot render emojis in headless mode")
	print("[CacheRebuild] The editor will build the cache on first launch")
	print("[CacheRebuild] This may take 10-30 seconds - please wait")

	# Create a marker file to skip cache on next boot
	var cache_dir = "user://emoji_atlas_cache"
	DirAccess.make_dir_recursive_absolute(cache_dir)

	var marker_file = FileAccess.open(cache_dir.path_join("skip_cache_once.txt"), FileAccess.WRITE)
	if marker_file:
		marker_file.store_string("Skip cache load once to force rebuild")
		marker_file.close()
		print("[CacheRebuild] ✓ Created skip marker")

	print("[CacheRebuild] Done. You can now launch the editor.")
	print("[CacheRebuild] First launch will build the atlas (may be slow)")

	quit()
