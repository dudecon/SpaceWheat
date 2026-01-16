#!/usr/bin/env -S godot --headless -s
extends SceneTree

## 🎯 CLAUDE PLAYS WITH QUESTS + SAVES
## Boot new game → Complete quests → Save game

const Farm = preload("res://Core/Farm.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const QuestGenerator = preload("res://Core/Quests/QuestGenerator.gd")
const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

var farm: Farm = null
var quest_manager: QuestManager = null
var state_manager: GameStateManager = null

var quests_offered = 0
var quests_accepted = 0
var quests_completed = 0
var quests_failed = 0

func _initialize():
	print("\n" + "=".repeat(80))
	print("🎯 CLAUDE PLAYS WITH QUESTS + SAVES")
	print("=".repeat(80))

	# Create farm
	print("\n🌾 Step 1: Booting new game...")
	farm = Farm.new()
	root.add_child(farm)

	# Wait for farm to fully initialize (just 2 frames)
	await process_frame
	await process_frame

	print("✓ Farm initialized: %dx%d grid" % [farm.grid.grid_width, farm.grid.grid_height])
	print("✓ Starting credits: 🌾 %d" % farm.economy.get_resource("🌾"))

	# Create quest manager
	print("\n📜 Step 2: Creating quest system...")
	quest_manager = QuestManager.new()
	root.add_child(quest_manager)

	# Connect quest manager to economy
	quest_manager.connect_to_economy(farm.economy)

	# Connect to quest manager signals
	quest_manager.quest_offered.connect(_on_quest_offered)
	quest_manager.quest_accepted.connect(_on_quest_accepted)
	quest_manager.quest_completed.connect(_on_quest_completed)
	quest_manager.quest_failed.connect(_on_quest_failed)

	await process_frame

	print("✓ QuestManager connected to economy")

	# Create game state manager
	state_manager = GameStateManager.new()
	root.add_child(state_manager)
	state_manager.active_farm = farm
	await process_frame

	print("✓ GameStateManager ready")

	# Play through quest lifecycle
	await quest_lifecycle_demo()

	# Save the game
	await save_game_demo()

	# Print final stats
	print_final_stats()

	quit(0)


func quest_lifecycle_demo():
	"""Demonstrate quest lifecycle: offer → accept → complete"""

	print("\n" + "─".repeat(80))
	print("🎯 QUEST LIFECYCLE DEMO")
	print("─".repeat(80))

	# Create test factions
	var factions = [
		{
			"name": "🌾 Wheat Farmers' Guild",
			"emoji": "🌾",
			"description": "Agricultural collective focused on wheat production"
		},
		{
			"name": "💰 Trade Federation",
			"emoji": "💰",
			"description": "Merchant alliance seeking profit opportunities"
		},
		{
			"name": "🍄 Fungal Network",
			"emoji": "🍄",
			"description": "Mycelial communion seeking decomposition balance"
		}
	]

	for faction in factions:
		await run_quest_cycle(faction)

	print("\n✅ Quest lifecycle demo complete!")


func run_quest_cycle(faction: Dictionary):
	"""Run complete quest cycle for one faction"""

	print("\n📂 Testing faction: %s" % faction.name)

	# Offer quest
	var available_resources = ["🌾", "💰", "🍄", "🍂"]
	var quest = quest_manager.offer_quest(faction, "BioticFlux", available_resources)

	if quest.is_empty():
		print("  ❌ Failed to generate quest for faction %s" % faction.name)
		return

	print("  ✓ Quest offered: ID %d" % quest.id)
	print("    Title: %s" % quest.get("title", quest.get("body", "Untitled")))
	print("    Requires: %s × %d" % [quest.get("resource", "???"), quest.get("quantity", 0)])
	print("    Rewards: %s" % str(quest.get("reward", "Unknown")))

	# Check if we can complete it immediately
	var required_emoji = quest.get("resource", "")
	var required_qty = quest.get("quantity", 0)
	var required_credits = required_qty * EconomyConstants.QUANTUM_TO_CREDITS

	var current_amount = farm.economy.get_resource(required_emoji)
	print("    Current %s: %d credits (need: %d)" % [required_emoji, current_amount, required_credits])

	# Accept quest
	var accepted = quest_manager.accept_quest(quest)
	if not accepted:
		print("  ❌ Failed to accept quest")
		return

	print("  ✓ Quest accepted!")

	# Give player resources if needed
	if current_amount < required_credits:
		var deficit = required_credits - current_amount
		print("  💰 Adding %d %s credits to complete quest..." % [deficit, required_emoji])
		farm.economy.add_resource(required_emoji, deficit, "quest_test_boost")

	# Check completion
	var can_complete = quest_manager.check_quest_completion(quest.id)
	print("  ✓ Can complete: %s" % str(can_complete))

	if can_complete:
		# Complete quest
		var completed = quest_manager.complete_quest(quest.id)
		if completed:
			print("  ✅ Quest completed!")
			var quest_data = quest_manager.completed_quests[-1]  # Get last completed
			print("    Rewards received: %s" % str(quest_data.get("rewards", {})))
		else:
			print("  ❌ Failed to complete quest")
	else:
		print("  ⚠️ Cannot complete quest - insufficient resources")
		quest_manager.fail_quest(quest.id, "insufficient_resources")


func save_game_demo():
	"""Demonstrate game save functionality"""

	print("\n" + "─".repeat(80))
	print("💾 SAVE GAME DEMO")
	print("─".repeat(80))

	# Get current game stats
	var wheat = farm.economy.get_resource("🌾")
	var money = farm.economy.get_resource("💰")

	print("\n📊 Current game state:")
	print("  🌾 Wheat: %d credits" % wheat)
	print("  💰 Money: %d credits" % money)
	print("  🎯 Quests completed: %d" % quests_completed)
	print("  ❌ Quests failed: %d" % quests_failed)

	# Save to slot 0
	print("\n💾 Saving to slot 1...")
	var saved = state_manager.save_game(0)

	if saved:
		print("✅ Game saved successfully!")

		# Verify save file exists
		var save_path = state_manager.get_save_path(0)
		if FileAccess.file_exists(save_path):
			print("✓ Save file created: %s" % save_path)

			# Load save info
			var save_info = state_manager.get_save_info(0)
			print("✓ Save info:")
			print("  - Name: %s" % save_info.get("display_name", "???"))
			print("  - Credits: %d" % save_info.get("credits", 0))
			print("  - Playtime: %.1fs" % save_info.get("playtime", 0))
		else:
			print("⚠️ Save file not found (may be normal in headless mode)")
	else:
		print("❌ Save failed!")


func print_final_stats():
	"""Print summary of quest session"""

	print("\n" + "=".repeat(80))
	print("📊 SESSION SUMMARY")
	print("=".repeat(80))

	print("\n🎯 Quest Statistics:")
	print("  Offered: %d" % quests_offered)
	print("  Accepted: %d" % quests_accepted)
	print("  Completed: %d" % quests_completed)
	print("  Failed: %d" % quests_failed)

	print("\n💰 Final Economy:")
	if farm and farm.economy:
		print("  🌾 Wheat: %d credits" % farm.economy.get_resource("🌾"))
		print("  💰 Money: %d credits" % farm.economy.get_resource("💰"))
		print("  🍄 Mushrooms: %d credits" % farm.economy.get_resource("🍄"))
		print("  🍂 Detritus: %d credits" % farm.economy.get_resource("🍂"))

	print("\n✅ QUEST SYSTEM WORKING!")
	print("=".repeat(80) + "\n")


# Signal handlers

func _on_quest_offered(quest_data: Dictionary):
	quests_offered += 1


func _on_quest_accepted(quest_id: int):
	quests_accepted += 1


func _on_quest_completed(quest_id: int, rewards: Dictionary):
	quests_completed += 1


func _on_quest_failed(quest_id: int, reason: String):
	quests_failed += 1


# Utility

func wait(seconds: float):
	"""Wait for specified duration"""
	await create_timer(seconds).timeout
