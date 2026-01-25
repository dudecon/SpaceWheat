extends Node

## Test harness for keyboard-driven gameplay
## Manages KeyboardPlayer and provides oversight

const Farm = preload("res://Core/Farm.gd")
const KeyboardPlayer = preload("res://Tests/KeyboardPlayer.gd")
const QuantumQuestGenerator = preload("res://Core/Quests/QuantumQuestGenerator.gd")
const QuantumQuestEvaluator = preload("res://Core/Quests/QuantumQuestEvaluator.gd")
const QuestCategory = preload("res://Core/Quests/QuestCategory.gd")

var farm: Farm
var player: KeyboardPlayer
var evaluator: QuantumQuestEvaluator
var test_duration: float = 15.0  # Run for 15 seconds
var elapsed_time: float = 0.0

func _ready():
	print("\n======================================================================")
	print("KEYBOARD-DRIVEN GAMEPLAY TEST")
	print("Test Duration: %.0f seconds" % test_duration)
	print("======================================================================\n")

	# Create farm
	print("🌾 Setting up farm...")
	farm = Farm.new()
	add_child(farm)

	await get_tree().process_frame

	if not farm.biome_enabled:
		print("❌ ERROR: Biomes not enabled")
		get_tree().quit(1)
		return

	print("✅ Farm ready\n")

	# Create quest system
	print("📜 Setting up quest system...")
	evaluator = QuantumQuestEvaluator.new()
	add_child(evaluator)
	evaluator.biomes = [farm.biotic_flux_biome]
	evaluator.quest_completed.connect(_on_quest_completed)
	evaluator.objective_completed.connect(_on_objective_completed)

	# Generate tutorial quest
	var generator = QuantumQuestGenerator.new()
	var context = QuantumQuestGenerator.GenerationContext.new()
	context.player_level = 1
	context.available_emojis = ["🌾", "👥"]
	context.preferred_category = QuestCategory.TUTORIAL

	var quest = generator.generate_quest(context)
	if quest:
		evaluator.activate_quest(quest)
		print("✅ Quest: %s\n" % quest.title)

	# Create keyboard player AI
	print("🤖 Spawning keyboard player AI...")
	player = KeyboardPlayer.new()
	add_child(player)
	player.action_completed.connect(_on_player_action)

	print("\n======================================================================")
	print("▶️  GAMEPLAY STARTED - AI is now playing!")
	print("======================================================================\n")

	set_process(true)

func _process(delta):
	elapsed_time += delta
	evaluator.evaluate_all_quests(delta)

	# Print status updates every 5 seconds
	if int(elapsed_time) % 5 == 0 and elapsed_time > 0.1:
		if int(elapsed_time * 10) % 50 == 0:  # Only once per second
			_print_status_update()

	# End test after duration
	if elapsed_time >= test_duration:
		_finish_test()
		set_process(false)

func _print_status_update():
	# Print periodic status update
	print("\n⏱️  [t=%.0fs] STATUS UPDATE" % elapsed_time)
	print("   🌾 Wheat: %d credits" % farm.economy.get_resource("🌾"))
	print("   🎯 Quest progress:")

	if evaluator.active_quests.size() > 0:
		for quest_id in evaluator.active_quests:
			var quest = evaluator.active_quests[quest_id]
			var progress = quest.get_completion_percent()
			print("      %.0f%% - %s" % [progress * 100, quest.title])

			# Debug: Show quest objectives
			if quest.objectives and quest.objectives.size() > 0:
				print("         Objectives:")
				for i in range(quest.objectives.size()):
					var obj = quest.objectives[i]
					var obj_progress = quest.progress.get(i, {})
					var completed = obj_progress.get("completed", false)
					var percent = obj_progress.get("progress", 0.0)
					var status = "✅" if completed else "⏳"
					var desc = obj.description_override if obj.description_override else obj.objective_type
					print("         %s [%d] %s (%.0f%%)" % [status, i, desc, percent * 100])

func _on_player_action(action: String, result: Dictionary):
	# Log player actions
	# Actions are already logged by KeyboardPlayer
	pass

func _on_quest_completed(quest_id: String):
	print("\n🎊 🎊 🎊 🎊 🎊 🎊 🎊 🎊 🎊 🎊 ")
	print("QUEST COMPLETED: %s" % quest_id)
	print("🎊 🎊 🎊 🎊 🎊 🎊 🎊 🎊 🎊 🎊 \n")

	if player:
		player.quests_completed += 1

func _on_objective_completed(quest_id: String, obj_index: int):
	print("\n✨ Objective %d completed in quest %s" % [obj_index, quest_id])

func _finish_test():
	print("\n\n======================================================================")
	print("TEST COMPLETE - FINAL RESULTS")
	print("======================================================================\n")

	# Player stats
	if player:
		player.print_stats()

	# Quest results
	print("\n📊 QUEST RESULTS:")
	var total_quests = evaluator.active_quests.size()
	var completed = 0

	for quest_id in evaluator.active_quests:
		var quest = evaluator.active_quests[quest_id]
		if quest.is_complete():
			completed += 1
			print("  ✅ COMPLETE: %s" % quest.title)
		else:
			var progress = quest.get_completion_percent()
			print("  ⏳ IN PROGRESS (%.0f%%): %s" % [progress * 100, quest.title])

	print("\n  Total: %d/%d quests completed" % [completed, total_quests])

	# Final resources
	print("\n💰 FINAL RESOURCES:")
	print("  🌾 Wheat: %d credits" % farm.economy.get_resource("🌾"))
	print("  👥 Labor: %d credits" % farm.economy.get_resource("👥"))

	# Goals completed
	if farm.goals:
		var goals_completed = 0
		print("\n🎯 GOALS:")
		for goal in farm.goals.goals:
			if goal.get("completed", false):
				goals_completed += 1
				print("  ✅ %s" % goal.get("name", "Unknown"))

		print("\n  Total: %d goals completed" % goals_completed)

	print("\n======================================================================")
	print("✅ KEYBOARD GAMEPLAY TEST FINISHED!")
	print("   Duration: %.1f seconds" % elapsed_time)
	print("   Actions: %d" % (player.actions_taken if player else 0))
	print("======================================================================\n")

	# Wait a moment then quit
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)
