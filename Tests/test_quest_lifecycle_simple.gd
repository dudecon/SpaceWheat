#!/usr/bin/env -S godot --headless -s
extends SceneTree

## 🎯 SIMPLE QUEST LIFECYCLE TEST
## Test quest system without full farm initialization

const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const QuestGenerator = preload("res://Core/Quests/QuestGenerator.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

var quest_manager: QuestManager = null
var economy: FarmEconomy = null
var state_manager: GameStateManager = null

var quests_completed = 0

func _init():
	print("\n" + "=".repeat(80))
	print("🎯 SIMPLE QUEST LIFECYCLE TEST + SAVE")
	print("=".repeat(80))

	# Create economy (minimal setup)
	print("\n💰 Creating economy...")
	economy = FarmEconomy.new()
	root.add_child(economy)

	print("✓ Economy initialized")
	print("  🌾 Starting wheat: %d credits" % economy.get_resource("🌾"))
	print("  💰 Starting money: %d credits" % economy.get_resource("💰"))

	# Create quest manager
	print("\n📜 Creating quest manager...")
	quest_manager = QuestManager.new()
	root.add_child(quest_manager)
	quest_manager.connect_to_economy(economy)

	# Connect signals
	quest_manager.quest_completed.connect(_on_quest_completed)

	print("✓ QuestManager ready")

	# Create game state manager for saving
	print("\n💾 Creating state manager...")
	state_manager = GameStateManager.new()
	root.add_child(state_manager)

	print("✓ StateManager ready")

	# Run quest demos
	test_quest_lifecycle()

	# Save game
	test_save_game()

	# Print final stats
	print_final_stats()

	quit(0)


func test_quest_lifecycle():
	"""Test complete quest lifecycle"""

	print("\n" + "─".repeat(80))
	print("🎯 QUEST LIFECYCLE TEST")
	print("─".repeat(80))

	# Create test factions (with proper 12-bit patterns)
	var factions = [
		{
			"name": "Millwright's Union",
			"emoji": "🌾⚙️🏭",
			"bits": [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
			"category": "Working Guilds",
			"description": "Grain processors"
		},
		{
			"name": "Granary Guilds",
			"emoji": "🌾💰⚖️",
			"bits": [1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1],
			"category": "Imperial Powers",
			"description": "Food-control networks"
		},
		{
			"name": "Rootway Travelers",
			"emoji": "🍄🌿🌲",
			"bits": [0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1],
			"category": "Natural Communion",
			"description": "Fungal network navigators"
		}
	]

	for faction in factions:
		run_quest(faction)


func run_quest(faction: Dictionary):
	"""Run one complete quest"""

	print("\n📂 Testing: %s" % faction.name)

	# Offer quest
	var quest = quest_manager.offer_quest(faction, "TestBiome", ["🌾", "💰", "🍄"])

	if quest.is_empty():
		print("  ⚠️ Quest generation failed (may be random)")
		return

	print("  ✓ Quest offered: #%d" % quest.id)
	print("    %s" % quest.get("body", quest.get("title", "Untitled")))
	print("    Requires: %s × %d" % [quest.get("resource", "?"), quest.get("quantity", 0)])

	# Accept quest
	var accepted = quest_manager.accept_quest(quest)
	if not accepted:
		print("  ❌ Failed to accept quest")
		return

	print("  ✓ Quest accepted!")

	# Check resources
	var required_emoji = quest.get("resource", "")
	var required_qty = quest.get("quantity", 0)
	var required_credits = required_qty * EconomyConstants.QUANTUM_TO_CREDITS
	var current_amount = economy.get_resource(required_emoji)

	print("  Current %s: %d (need %d)" % [required_emoji, current_amount, required_credits])

	# Give resources if needed
	if current_amount < required_credits:
		var deficit = required_credits - current_amount
		print("  💰 Adding %d %s to inventory..." % [deficit, required_emoji])
		economy.add_resource(required_emoji, deficit, "quest_boost")

	# Complete quest
	var completed = quest_manager.complete_quest(quest.id)
	if completed:
		print("  ✅ Quest completed!")
		var rewards = quest_manager.completed_quests[-1].get("rewards", {})
		for emoji in rewards:
			print("    Reward: %s × %d" % [emoji, rewards[emoji]])
	else:
		print("  ❌ Quest completion failed")


func test_save_game():
	"""Test save functionality (minimal)"""

	print("\n" + "─".repeat(80))
	print("💾 SAVE GAME TEST")
	print("─".repeat(80))

	print("\n📊 Current state:")
	print("  🌾 Wheat: %d" % economy.get_resource("🌾"))
	print("  💰 Money: %d" % economy.get_resource("💰"))
	print("  🍄 Mushrooms: %d" % economy.get_resource("🍄"))
	print("  📜 Quests completed: %d" % quests_completed)

	# Note: Full save requires active_farm to be set
	print("\n⚠️ Note: Full game save requires Farm instance")
	print("   This test validates quest system only")

	# Verify save directory exists
	var save_dir = "user://saves/"
	var dir = DirAccess.open("user://")
	if dir and dir.dir_exists("saves"):
		print("✓ Save directory exists: %s" % save_dir)
	else:
		print("⚠️ Save directory not found")


func print_final_stats():
	"""Print final statistics"""

	print("\n" + "=".repeat(80))
	print("📊 FINAL STATISTICS")
	print("=".repeat(80))

	print("\n🎯 Quest Stats:")
	print("  Active: %d" % quest_manager.get_active_quest_count())
	print("  Completed: %d" % quest_manager.get_completed_quest_count())
	print("  Failed: %d" % quest_manager.get_failed_quest_count())

	print("\n💰 Final Economy:")
	print("  🌾 Wheat: %d credits" % economy.get_resource("🌾"))
	print("  💰 Money: %d credits" % economy.get_resource("💰"))
	print("  🍄 Mushrooms: %d credits" % economy.get_resource("🍄"))

	print("\n✅ QUEST SYSTEM TEST COMPLETE!")
	print("=".repeat(80) + "\n")


func _on_quest_completed(quest_id: int, rewards: Dictionary):
	quests_completed += 1
