extends SceneTree

## Interactive Quest Playtest - Full Gameplay Loop
## Run with: godot --script res://Tests/interactive_quest_playtest.gd
##
## This is a GUIDED INTERACTIVE playtest. You play with the keyboard while
## the script monitors your progress and provides instructions.
##
## GAMEPLAY LOOP:
##   1. Open Quest Board (C)
##   2. Select and accept a quest (UIOP to select, Q to accept)
##   3. Farm resources (Tool 1: Q=Explore, E=Measure, R=Pop)
##   4. Complete quest (C to open board, Q to complete)
##   5. Learn new vocabulary from rewards
##   6. Unlock new factions
##   7. Inject vocabulary into biomes (Tab for BUILD mode)

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

# Tutorial state
enum TutorialPhase {
	WAITING_FOR_BOOT,
	INTRO,
	OPEN_QUEST_BOARD,
	SELECT_QUEST,
	ACCEPT_QUEST,
	CLOSE_BOARD_TO_FARM,
	FARMING_LOOP,
	CHECK_QUEST_READY,
	COMPLETE_QUEST,
	VOCABULARY_REWARD,
	EXPLORE_NEW_FACTIONS,
	BUILD_MODE_INTRO,
	INJECT_VOCABULARY,
	COMPLETE
}

var current_phase: TutorialPhase = TutorialPhase.WAITING_FOR_BOOT
var phase_start_time: float = 0.0

# Game references
var farm = null
var player_shell = null
var quest_manager = null
var quest_board = null
var economy = null
var input_handler = null

# Progress tracking
var initial_vocabulary: Array = []
var quests_completed: int = 0
var vocabulary_learned: Array = []
var factions_unlocked: Array = []
var resources_harvested: Dictionary = {}

# Frame tracking
var frame_count: int = 0
var scene_loaded: bool = false
var game_ready: bool = false
var last_hint_time: float = 0.0

# UI
var hud_label: Label = null

const RIG_COMMAND_REL_PATH := "llm_inbox/rig_commands.txt"
const COMMAND_POLL_INTERVAL := 0.5

var _rig_command_abs_path: String = ""
var _command_poll_timer: float = 0.0


func _init():
	print("")
	print("=" .repeat(70))
	print("  INTERACTIVE QUEST PLAYTEST")
	print("  Full Gameplay Loop: Quests -> Vocabulary -> Biome Injection")
	print("=".repeat(70))
	print("")
	print("Loading game...")


func _ready():
	_rig_command_abs_path = ProjectSettings.globalize_path("res://") + "/" + RIG_COMMAND_REL_PATH
	_ensure_rig_command_file()
	_print_rig_command_help()


func _process(delta: float):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		_load_scene()

	if game_ready:
		_update_tutorial(delta)
		_poll_rig_commands(delta)


func _load_scene():
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true

		var boot = root.get_node_or_null("/root/BootManager")
		if boot:
			boot.game_ready.connect(_on_game_ready)
	else:
		print("ERROR: Failed to load FarmView.tscn")
		quit(1)


func _on_game_ready():
	if game_ready:
		return
	game_ready = true

	print("\nGame loaded! Setting up playtest...\n")

	_find_components()
	_connect_signals()
	_create_hud()
	_setup_initial_state()

	# Start tutorial
	_advance_phase(TutorialPhase.INTRO)


func _find_components():
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
		economy = farm.economy if farm else null

	player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		if player_shell.get("overlay_manager"):
			var overlay_mgr = player_shell.overlay_manager
			quest_board = overlay_mgr.quest_board if overlay_mgr else null

		for child in player_shell.get_children():
			if child.get_script() and child.get_script().resource_path.ends_with("FarmInputHandler.gd"):
				input_handler = child
				break

	# Find QuestManager
	if farm and farm.has_method("get_quest_manager"):
		quest_manager = farm.get_quest_manager()
	elif player_shell and player_shell.get("quest_manager"):
		quest_manager = player_shell.quest_manager
	else:
		quest_manager = _find_node(root, "QuestManager")

	print("Components found:")
	print("  Farm: %s" % (farm != null))
	print("  Economy: %s" % (economy != null))
	print("  QuestBoard: %s" % (quest_board != null))
	print("  QuestManager: %s" % (quest_manager != null))
	print("  InputHandler: %s" % (input_handler != null))


func _connect_signals():
	# Connect to quest signals
	if quest_board:
		if quest_board.has_signal("quest_accepted"):
			quest_board.quest_accepted.connect(_on_quest_accepted)
		if quest_board.has_signal("quest_completed"):
			quest_board.quest_completed.connect(_on_quest_completed)
		if quest_board.has_signal("board_opened"):
			quest_board.board_opened.connect(_on_board_opened)
		if quest_board.has_signal("board_closed"):
			quest_board.board_closed.connect(_on_board_closed)

	# Connect to economy for resource tracking
	if economy and economy.has_signal("resource_changed"):
		economy.resource_changed.connect(_on_resource_changed)

	# Connect to GameStateManager for vocabulary
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm:
		if gsm.has_signal("emoji_discovered"):
			gsm.emoji_discovered.connect(_on_emoji_discovered)


func _create_hud():
	# Create an overlay label for instructions
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	root.add_child(canvas)

	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	hud_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hud_label.add_theme_constant_override("shadow_offset_x", 2)
	hud_label.add_theme_constant_override("shadow_offset_y", 2)
	hud_label.position = Vector2(20, 20)
	hud_label.size = Vector2(400, 200)
	canvas.add_child(hud_label)


func _setup_initial_state():
	# Record initial vocabulary
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm and gsm.get("current_state") and gsm.current_state.get("known_emojis"):
		initial_vocabulary = gsm.current_state.known_emojis.duplicate()

	print("\nInitial vocabulary: %s" % [initial_vocabulary])

	# Ensure we're in PLAY mode
	ToolConfig.set_mode("play")


func _find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null


# ============================================================================
# TUTORIAL PHASES
# ============================================================================

func _advance_phase(new_phase: TutorialPhase):
	current_phase = new_phase
	phase_start_time = Time.get_ticks_msec() / 1000.0
	_print_phase_intro()


func _print_phase_intro():
	print("")
	match current_phase:
		TutorialPhase.INTRO:
			print("=" .repeat(70))
			print("  WELCOME TO SPACEWHEAT!")
			print("=".repeat(70))
			print("")
			print("This playtest will guide you through the full gameplay loop:")
			print("  1. Accept quests from factions")
			print("  2. Farm quantum resources (Explore -> Measure -> Pop)")
			print("  3. Complete quests to earn vocabulary")
			print("  4. Unlock new factions with your vocabulary")
			print("  5. Inject vocabulary into biomes (BUILD mode)")
			print("")
			print("Press any key to continue...")

		TutorialPhase.OPEN_QUEST_BOARD:
			print("-".repeat(70))
			print("  STEP 1: Open the Quest Board")
			print("-".repeat(70))
			print("")
			print("  Press [C] to open the Quest Board")
			print("")

		TutorialPhase.SELECT_QUEST:
			print("-".repeat(70))
			print("  STEP 2: Select a Quest")
			print("-".repeat(70))
			print("")
			print("  Use [U] [I] [O] [P] to select a quest slot")
			print("  Or use arrow keys / WASD to navigate")
			print("")

		TutorialPhase.ACCEPT_QUEST:
			print("-".repeat(70))
			print("  STEP 3: Accept the Quest")
			print("-".repeat(70))
			print("")
			print("  Press [Q] to Accept the selected quest")
			print("  Press [R] to Lock/Unlock the slot")
			print("")

		TutorialPhase.CLOSE_BOARD_TO_FARM:
			print("-".repeat(70))
			print("  STEP 4: Start Farming!")
			print("-".repeat(70))
			print("")
			print("  Press [ESC] or [C] to close the Quest Board")
			print("  Then farm resources to complete your quest!")
			print("")

		TutorialPhase.FARMING_LOOP:
			print("-".repeat(70))
			print("  STEP 5: Farm Resources")
			print("-".repeat(70))
			print("")
			print("  Tool 1 (Probe) is selected. Use:")
			print("    [Q] = Explore - discover quantum states")
			print("    [E] = Measure - collapse to emoji")
			print("    [R] = Pop/Harvest - collect resource")
			print("")
			print("  Select plots with the Homerow: [J][K][L][;]")
			print("  Farm until you have enough resources!")
			print("")

		TutorialPhase.CHECK_QUEST_READY:
			print("-".repeat(70))
			print("  STEP 6: Check Quest Progress")
			print("-".repeat(70))
			print("")
			print("  Press [C] to open the Quest Board")
			print("  Check if your quest is ready to complete!")
			print("")

		TutorialPhase.COMPLETE_QUEST:
			print("-".repeat(70))
			print("  STEP 7: Complete the Quest!")
			print("-".repeat(70))
			print("")
			print("  Your quest is READY!")
			print("  Press [Q] to COMPLETE and claim rewards!")
			print("")

		TutorialPhase.VOCABULARY_REWARD:
			print("-".repeat(70))
			print("  VOCABULARY UNLOCKED!")
			print("-".repeat(70))
			print("")
			print("  You learned new vocabulary from the quest!")
			print("  New emojis: %s" % [vocabulary_learned])
			print("")
			print("  This may unlock new factions...")
			print("")

		TutorialPhase.EXPLORE_NEW_FACTIONS:
			print("-".repeat(70))
			print("  STEP 8: Explore New Factions")
			print("-".repeat(70))
			print("")
			print("  Press [C] to open the Quest Board")
			print("  Press [F] to browse factions")
			print("  See what new factions are now available!")
			print("")

		TutorialPhase.BUILD_MODE_INTRO:
			print("-".repeat(70))
			print("  STEP 9: Enter BUILD Mode")
			print("-".repeat(70))
			print("")
			print("  Press [TAB] to switch to BUILD mode")
			print("  In BUILD mode you can configure biomes!")
			print("")

		TutorialPhase.INJECT_VOCABULARY:
			print("-".repeat(70))
			print("  STEP 10: Inject Vocabulary into Biome")
			print("-".repeat(70))
			print("")
			print("  Tool 2 (Icon) lets you assign emojis to plots:")
			print("    Press [2] to select Icon tool")
			print("    Press [Q] to open icon assignment submenu")
			print("    Select a plot and assign your new vocabulary!")
			print("")

		TutorialPhase.COMPLETE:
			print("=".repeat(70))
			print("  PLAYTEST COMPLETE!")
			print("=".repeat(70))
			print("")
			print("  Summary:")
			print("    Quests completed: %d" % quests_completed)
			print("    Vocabulary learned: %s" % [vocabulary_learned])
			print("    Factions unlocked: %s" % [factions_unlocked])
			print("    Resources harvested: %s" % resources_harvested)
			print("")
			print("  You've experienced the full SpaceWheat gameplay loop!")
			print("  Keep playing to unlock more vocabulary and factions.")
			print("")
			print("=".repeat(70))


func _update_tutorial(delta: float):
	var current_time = Time.get_ticks_msec() / 1000.0
	var phase_time = current_time - phase_start_time

	# Update HUD
	_update_hud()

	# Phase-specific logic
	match current_phase:
		TutorialPhase.INTRO:
			# Wait for any input, then advance
			if phase_time > 2.0:
				_advance_phase(TutorialPhase.OPEN_QUEST_BOARD)

		TutorialPhase.FARMING_LOOP:
			# Check if we have enough resources periodically
			if phase_time > 5.0 and int(phase_time) % 10 == 0:
				_check_quest_completable()

		TutorialPhase.VOCABULARY_REWARD:
			# Auto-advance after showing reward
			if phase_time > 3.0:
				if factions_unlocked.size() > 0:
					_advance_phase(TutorialPhase.EXPLORE_NEW_FACTIONS)
				else:
					_advance_phase(TutorialPhase.BUILD_MODE_INTRO)

		TutorialPhase.EXPLORE_NEW_FACTIONS:
			if phase_time > 10.0:
				_advance_phase(TutorialPhase.BUILD_MODE_INTRO)


func _update_hud():
	if not hud_label:
		return

	var lines: Array = []

	# Current phase instruction
	match current_phase:
		TutorialPhase.OPEN_QUEST_BOARD:
			lines.append("[C] Open Quest Board")
		TutorialPhase.SELECT_QUEST:
			lines.append("[UIOP] Select quest slot")
		TutorialPhase.ACCEPT_QUEST:
			lines.append("[Q] Accept quest")
		TutorialPhase.CLOSE_BOARD_TO_FARM:
			lines.append("[ESC] Close board, start farming")
		TutorialPhase.FARMING_LOOP:
			lines.append("Tool 1: [Q]Explore [E]Measure [R]Pop")
			lines.append("Select plots: [J][K][L][;] (Homerow)")
		TutorialPhase.CHECK_QUEST_READY:
			lines.append("[C] Check quest progress")
		TutorialPhase.COMPLETE_QUEST:
			lines.append("[Q] COMPLETE QUEST!")
		TutorialPhase.BUILD_MODE_INTRO:
			lines.append("[TAB] Switch to BUILD mode")
		TutorialPhase.INJECT_VOCABULARY:
			lines.append("[2] Icon tool, [Q] Assign")

	# Progress info
	lines.append("")
	lines.append("Quests: %d | Vocab: %d" % [quests_completed, vocabulary_learned.size()])

	# Resource counts
	if resources_harvested.size() > 0:
		var res_str = ""
		for emoji in resources_harvested:
			res_str += "%s:%d " % [emoji, resources_harvested[emoji]]
		lines.append(res_str)

	hud_label.text = "\n".join(lines)


func _check_quest_completable():
	# Check if current quest can be completed
	if quest_board and quest_board.has_method("get_selected_quest"):
		var quest = quest_board.get_selected_quest()
		if quest and quest.get("status") == "active":
			var resource = quest.get("resource", "")
			var quantity = quest.get("quantity", 1)
			var have = resources_harvested.get(resource, 0)
			if have >= quantity:
				print("\n  Quest ready to complete! You have %d/%d %s" % [have, quantity, resource])
				_advance_phase(TutorialPhase.CHECK_QUEST_READY)


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_board_opened():
	print("  [Quest Board opened]")
	match current_phase:
		TutorialPhase.OPEN_QUEST_BOARD:
			_advance_phase(TutorialPhase.SELECT_QUEST)
		TutorialPhase.CHECK_QUEST_READY:
			_advance_phase(TutorialPhase.COMPLETE_QUEST)


func _on_board_closed():
	print("  [Quest Board closed]")
	match current_phase:
		TutorialPhase.CLOSE_BOARD_TO_FARM:
			_advance_phase(TutorialPhase.FARMING_LOOP)


func _on_quest_accepted(quest: Dictionary):
	print("  Quest accepted: %s" % quest.get("faction", "Unknown"))
	print("    Resource: %s x%d" % [quest.get("resource", "?"), quest.get("quantity", 0)])

	match current_phase:
		TutorialPhase.ACCEPT_QUEST, TutorialPhase.SELECT_QUEST:
			_advance_phase(TutorialPhase.CLOSE_BOARD_TO_FARM)


func _on_quest_completed(quest_id: int, rewards: Dictionary):
	quests_completed += 1
	print("  Quest %d completed!" % quest_id)
	print("    Rewards: %s" % rewards)

	# Check for vocabulary rewards
	if rewards.has("vocabulary"):
		for emoji in rewards.vocabulary:
			if emoji not in vocabulary_learned:
				vocabulary_learned.append(emoji)

	_advance_phase(TutorialPhase.VOCABULARY_REWARD)


func _on_resource_changed(emoji: String, new_amount: int) -> void:
	var previous_amount = resources_harvested.get(emoji, 0)
	var delta = new_amount - previous_amount
	resources_harvested[emoji] = new_amount

	if current_phase == TutorialPhase.FARMING_LOOP and delta > 0:
		print("  Harvested: %s (+%d) → total %d" % [emoji, delta, new_amount])


func _on_emoji_discovered(emoji: String):
	print("  NEW VOCABULARY: %s" % emoji)
	if emoji not in vocabulary_learned:
		vocabulary_learned.append(emoji)


func _on_faction_unlocked(faction_name: String):
	print("  NEW FACTION UNLOCKED: %s" % faction_name)
	if faction_name not in factions_unlocked:
		factions_unlocked.append(faction_name)


func _poll_rig_commands(delta: float) -> void:
	if not game_ready:
		return

	_command_poll_timer -= delta
	if _command_poll_timer > 0.0:
		return

	_command_poll_timer = COMMAND_POLL_INTERVAL
	for command in _read_rig_commands():
		_execute_rig_command(command)


func _read_rig_commands() -> Array:
	if _rig_command_abs_path == "":
		return []

	if not FileAccess.file_exists(_rig_command_abs_path):
		return []

	var file = FileAccess.open(_rig_command_abs_path, FileAccess.READ)
	if not file:
		return []

	var text = file.get_as_text()
	file.close()

	var commands: Array = []
	for line in text.split("\n", false):
		var trimmed = line.strip_edges(true, true)
		if trimmed != "":
			commands.append(trimmed)

	if commands.size() > 0:
		_clear_rig_command_file()

	return commands


func _clear_rig_command_file() -> void:
	if _rig_command_abs_path == "":
		return

	var file = FileAccess.open(_rig_command_abs_path, FileAccess.WRITE)
	if not file:
		return

	file.store_string("")
	file.close()


func _ensure_rig_command_file() -> void:
	if _rig_command_abs_path == "":
		return

	var base_dir = _rig_command_abs_path.get_base_dir()
	if not DirAccess.dir_exists(base_dir):
		DirAccess.make_dir_recursive(base_dir)

	if not FileAccess.file_exists(_rig_command_abs_path):
		var file = FileAccess.open(_rig_command_abs_path, FileAccess.WRITE)
		if file:
			file.close()


func _execute_rig_command(command: String) -> void:
	var text = command.strip_edges(true, true)
	if text == "":
		return

	print("\nLLM rig command: %s" % text)

	var parts = text.split(" ", false)
	var action = parts[0].to_lower()

	match action:
		"press", "key":
			if parts.size() < 2:
				print("  Missing key argument.")
			else:
				_press_key(parts[1])
		"open":
			if quest_board:
				quest_board.open_board()
		"close":
			if quest_board:
				quest_board.close_board()
		"select", "slot":
			if parts.size() < 2:
				print("  Missing slot argument.")
			else:
				var idx = _slot_index_from_letter(parts[1])
				if idx >= 0 and quest_board:
					quest_board.select_slot(idx)
				else:
					print("  Invalid slot: %s" % parts[1])
		"accept":
			if quest_board:
				quest_board.action_q_on_selected()
		"status", "info", "dump":
			_print_rig_status()
		"help":
			_print_rig_command_help()
		_:
			print("  Unknown rig command: %s" % text)


func _print_rig_command_help() -> void:
	print("")
	print("LLM Rig command file: %s" % _rig_command_abs_path)
	print("Commands:")
	print("  press <key>     – simulate pressing a key (C, Q, R, J, K, L, ;, 1-4, etc.)")
	print("  open / close    – open/close the quest board")
	print("  select <U|I|O|P> – select quest slot by letter")
	print("  accept          – trigger the current slot's Q action")
	print("  status          – dump resources, quest selection, and phase info")
	print("  help            – reprint this help")
	print("")


func _print_rig_status() -> void:
	print("\n=== LLM Rig status ===")
	print("Phase: %s" % current_phase)
	print("Quests completed: %d" % quests_completed)
	print("Vocabulary learned: %s" % vocabulary_learned)
	print("Resources: %s" % resources_harvested)

	if quest_board and quest_board.has_method("get_selected_quest"):
		print("Selected quest: %s" % quest_board.get_selected_quest())

	print("Command file: %s" % _rig_command_abs_path)
	print("========================\n")


func _slot_index_from_letter(letter: String) -> int:
	match letter.to_upper():
		"U":
			return 0
		"I":
			return 1
		"O":
			return 2
		"P":
			return 3
		"0":
			return 0
		"1":
			return 1
		"2":
			return 2
		"3":
			return 3
	return -1


func _press_key(key_name: String) -> void:
	var keycode = OS.find_keycode_from_string(key_name.to_upper())
	if keycode == KEY_UNKNOWN:
		print("  Unknown key: %s" % key_name)
		return

	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	call_deferred("_release_key", keycode)


func _release_key(keycode: int) -> void:
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = false
	Input.parse_input_event(event)
