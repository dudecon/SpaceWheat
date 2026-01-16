extends SceneTree

## Claude's Quest Logbook Playtest
## Goal: Learn 1 vocabulary from each faction
## Run with: godot --headless -s Tests/claude_quest_logbook.gd

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

# Game references
var farm = null
var quest_manager = null
var economy = null
var plot_pool = null

# Logbook
var logbook: Array = []
var quests_completed: int = 0
var vocabulary_by_faction: Dictionary = {}  # faction -> [emojis learned]
var total_harvests: Dictionary = {}  # emoji -> count
var starting_vocabulary: Array = []  # Track what we started with

# Frame tracking
var frame: int = 0
var game_ready: bool = false
var current_quest: Dictionary = {}
var farming_cycles: int = 0
var max_farming_cycles: int = 3000

func _init():
	print("")
	print("═".repeat(70))
	print("  CLAUDE'S QUEST LOGBOOK")
	print("  Goal: Learn vocabulary from as many factions as possible")
	print("═".repeat(70))
	print("")


func _process(_delta) -> bool:
	frame += 1

	if frame == 5:
		_load_scene()

	if game_ready:
		_play_game()

	return false


func _load_scene():
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)

		var boot = root.get_node_or_null("/root/BootManager")
		if boot:
			boot.game_ready.connect(_on_game_ready)


func _on_game_ready():
	if game_ready:
		return
	game_ready = true

	_log("📖 LOGBOOK STARTED", "Game loaded, ready to quest!")

	# Find components
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
		economy = farm.economy if farm else null
		plot_pool = farm.plot_pool if farm else null

	# Quest manager is on PlayerShell
	var player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		quest_manager = player_shell.quest_manager if player_shell.get("quest_manager") else null

	# Connect quest manager to economy
	if quest_manager and economy:
		if quest_manager.has_method("connect_to_economy"):
			quest_manager.connect_to_economy(economy)
			_log("🔗 CONNECTED", "Quest manager linked to economy")

	# Record starting vocabulary
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		starting_vocabulary = gsm.current_state.known_emojis.duplicate()

	_log("🎮 SYSTEMS ONLINE", "Farm: %s, Economy: %s, Quests: %s | Starting vocab: %s" % [
		farm != null, economy != null, quest_manager != null, starting_vocabulary
	])

	# Start first quest
	_accept_new_quest()


func _play_game():
	farming_cycles += 1

	# Safety limit
	if farming_cycles > max_farming_cycles:
		_finish_playtest()
		return

	# Every 10 frames, do a farming action
	if farming_cycles % 10 == 0:
		_do_farming_cycle()

	# Every 50 frames, check quest progress
	if farming_cycles % 50 == 0:
		_check_quest_progress()

	# Every 100 frames, try to complete quest
	if farming_cycles % 100 == 0:
		if _try_complete_quest():
			_accept_new_quest()


func _do_farming_cycle():
	if not farm or not plot_pool:
		return

	# Get a biome to farm in
	var biome = null
	if farm.grid and farm.grid.biomes:
		for biome_name in farm.grid.biomes:
			biome = farm.grid.biomes[biome_name]
			break

	if not biome:
		return

	# Try EXPLORE → MEASURE → POP cycle
	var unbound = plot_pool.get_unbound_count()
	var active = plot_pool.get_active_terminals()
	var measured = plot_pool.get_measured_terminals()

	# Priority: POP > MEASURE > EXPLORE
	if measured.size() > 0:
		var terminal = measured[0]
		var result = ProbeActions.action_pop(terminal, plot_pool, economy)
		if result.success:
			var emoji = result.get("resource", "?")
			total_harvests[emoji] = total_harvests.get(emoji, 0) + 1
	elif active.size() > 0:
		var terminal = active[0]
		ProbeActions.action_measure(terminal, biome)
	elif unbound > 0:
		ProbeActions.action_explore(plot_pool, biome)


func _check_quest_progress():
	if current_quest.is_empty():
		return

	var resource = current_quest.get("resource", "")
	var needed = current_quest.get("quantity", 1)
	var have = economy.get_resource(resource) if economy else 0

	if have > 0 and farming_cycles % 200 == 0:
		print("  📊 Quest progress: %s %d/%d" % [resource, have, needed])


func _try_complete_quest() -> bool:
	if current_quest.is_empty():
		return false

	var quest_id = current_quest.get("id", -1)
	if quest_id < 0:
		return false

	# Check if we can complete it
	if quest_manager and quest_manager.has_method("check_quest_completion"):
		if not quest_manager.check_quest_completion(quest_id):
			return false

	# Try to complete via quest manager
	var success = false
	if quest_manager and quest_manager.has_method("complete_quest"):
		success = quest_manager.complete_quest(quest_id)

	if success:
		var faction = current_quest.get("faction", "Unknown")
		var resource = current_quest.get("resource", "?")
		var quantity = current_quest.get("quantity", 1)

		quests_completed += 1

		# Track vocabulary by faction - only newly learned emojis
		var gsm = root.get_node_or_null("/root/GameStateManager")
		if gsm and gsm.current_state:
			var known = gsm.current_state.known_emojis
			if not vocabulary_by_faction.has(faction):
				vocabulary_by_faction[faction] = []
			# Add only NEW emojis (not in starting vocabulary)
			for emoji in known:
				if emoji not in starting_vocabulary and emoji not in vocabulary_by_faction[faction]:
					vocabulary_by_faction[faction].append(emoji)
					_log("📖 NEW VOCABULARY", "Learned %s from %s" % [emoji, faction])

		_log("✅ QUEST COMPLETE", "Faction: %s | Delivered: %s x%d" % [
			faction, resource, quantity
		])

		current_quest = {}
		return true

	return false


func _accept_new_quest():
	if not quest_manager:
		_log("⚠️ NO QUEST MANAGER", "Cannot accept quests")
		return

	# Get a biome to generate quests for
	var biome = null
	if farm and farm.grid and farm.grid.biomes:
		for biome_name in farm.grid.biomes:
			biome = farm.grid.biomes[biome_name]
			break

	if not biome:
		_log("⚠️ NO BIOME", "Cannot generate quests without biome")
		return

	# Generate quests from all factions for this biome
	var available = []
	if quest_manager.has_method("offer_all_faction_quests"):
		available = quest_manager.offer_all_faction_quests(biome)

	if available.is_empty():
		_log("📭 NO QUESTS AVAILABLE", "No factions match current vocabulary")
		return

	_log("📋 QUEST OFFERS", "Found %d quests from various factions" % available.size())

	# Try to find a quest from a faction we haven't completed yet
	var target_quest = null
	for quest in available:
		var faction = quest.get("faction", "")
		if faction and not vocabulary_by_faction.has(faction):
			target_quest = quest
			break

	# If no new faction found, take any quest
	if not target_quest and available.size() > 0:
		target_quest = available[0]

	if target_quest:
		current_quest = target_quest
		var faction = target_quest.get("faction", "Unknown")
		var quest_type = target_quest.get("type", "delivery")
		var resource = target_quest.get("resource", "?")
		var quantity = target_quest.get("quantity", 1)

		_log("📜 NEW QUEST ACCEPTED", "Faction: %s | Type: %s | Target: %s x%d" % [
			faction, quest_type, resource, quantity
		])

		# Mark as active
		if quest_manager.has_method("accept_quest"):
			quest_manager.accept_quest(target_quest)
	else:
		_log("📭 NO SUITABLE QUESTS", "All factions already served")


func _log(header: String, details: String):
	var entry = {
		"time": Time.get_datetime_string_from_system(),
		"frame": frame,
		"header": header,
		"details": details
	}
	logbook.append(entry)
	print("\n[%s] %s" % [header, details])


func _finish_playtest():
	print("")
	print("═".repeat(70))
	print("  📖 CLAUDE'S QUEST LOGBOOK - FINAL SUMMARY")
	print("═".repeat(70))
	print("")

	print("📊 STATISTICS:")
	print("   Quests Completed: %d" % quests_completed)
	print("   Factions Served: %d" % vocabulary_by_faction.size())
	print("   Total Harvests: %d" % _sum_harvests())
	print("")

	print("🏛️ VOCABULARY BY FACTION:")
	if vocabulary_by_faction.is_empty():
		print("   (none learned yet)")
	else:
		for faction in vocabulary_by_faction:
			var emojis = vocabulary_by_faction[faction]
			print("   %s: %s" % [faction, " ".join(emojis)])
	print("")

	print("🌾 HARVEST TOTALS:")
	if total_harvests.is_empty():
		print("   (none harvested)")
	else:
		for emoji in total_harvests:
			print("   %s: %d" % [emoji, total_harvests[emoji]])
	print("")

	print("📖 FULL LOGBOOK:")
	print("-".repeat(70))
	for entry in logbook:
		print("[%s] %s" % [entry.header, entry.details])
	print("-".repeat(70))
	print("")

	print("═".repeat(70))
	print("  END OF PLAYTEST")
	print("═".repeat(70))

	quit(0)


func _sum_harvests() -> int:
	var total = 0
	for emoji in total_harvests:
		total += total_harvests[emoji]
	return total


func _find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null
