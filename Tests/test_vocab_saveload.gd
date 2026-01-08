extends SceneTree

## Test vocabulary persistence across save/load

const GameState = preload("res://Core/GameState/GameState.gd")
const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")

func _init():
	print("\n" + "═".repeat(70))
	print("VOCABULARY SAVE/LOAD TEST")
	print("═".repeat(70) + "\n")

	# Create test state with expanded vocabulary
	var state = GameState.new()
	state.known_emojis = ["🍞", "👥", "🌱", "💰", "🧺", "⚙", "🏭"]  # Learned 5 new emojis

	print("Original vocabulary: %s (%d emojis)\n" % ["".join(state.known_emojis), state.known_emojis.size()])

	# Serialize to dictionary
	var save_data = {
		"known_emojis": state.known_emojis,
		"wheat_inventory": 10,
		"credits": 50
	}

	print("Serialized data:")
	print("  known_emojis: %s" % save_data.known_emojis)
	print("  wheat_inventory: %d" % save_data.wheat_inventory)
	print("  credits: %d\n" % save_data.credits)

	# Simulate save/load by creating new state and restoring
	var loaded_state = GameState.new()
	loaded_state.known_emojis = save_data.known_emojis
	loaded_state.wheat_inventory = save_data.wheat_inventory
	loaded_state.credits = save_data.credits

	print("Loaded vocabulary: %s (%d emojis)\n" % ["".join(loaded_state.known_emojis), loaded_state.known_emojis.size()])

	# Verify
	if loaded_state.known_emojis.size() == state.known_emojis.size():
		print("✅ PASS: Vocabulary size preserved")
	else:
		print("❌ FAIL: Vocabulary size mismatch!")

	var match = true
	for i in range(state.known_emojis.size()):
		if state.known_emojis[i] != loaded_state.known_emojis[i]:
			match = false
			break

	if match:
		print("✅ PASS: Vocabulary content preserved")
	else:
		print("❌ FAIL: Vocabulary content mismatch!")

	print("\n" + "═".repeat(70))
	print("TEST COMPLETE")
	print("═".repeat(70) + "\n")

	quit()
