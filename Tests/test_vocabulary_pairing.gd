extends Node

## Test the VocabularyPairing system

const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("  VOCABULARY PAIRING TEST")
	print("=".repeat(60))

	await get_tree().process_frame

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		print("[ERROR] IconRegistry not found")
		_finish()
		return

	print("IconRegistry: %d icons\n" % icon_registry.icons.size())

	# Test several emojis
	_test_emoji("🐝", 20)
	_test_emoji("🔥", 20)
	_test_emoji("🍄", 20)
	_test_emoji("🌾", 20)

	_finish()


func _test_emoji(north: String, num_rolls: int) -> void:
	print("-".repeat(50))
	print("  Testing %s as North" % north)
	print("-".repeat(50))

	var icon_registry = get_node_or_null("/root/IconRegistry")

	# Show connection weights
	var sorted = VocabularyPairing.get_sorted_connections(north, icon_registry)
	print("\n  Connection weights:")
	for c in sorted:
		print("    %s/%s: %.3f (%.1f%%) [H=%.2f L_in=%.2f L_out=%.2f]" % [
			north, c.emoji, c.weight, c.probability * 100,
			c.h, c.l_in, c.l_out
		])

	# Do rolls
	print("\n  %d rolls:" % num_rolls)
	var counts = {}
	for _i in range(num_rolls):
		var result = VocabularyPairing.roll_partner(north)
		var south = result.get("south", "?")
		counts[south] = counts.get(south, 0) + 1

	# Sort and display
	var sorted_counts = []
	for s in counts:
		sorted_counts.append({"south": s, "count": counts[s]})
	sorted_counts.sort_custom(func(a, b): return a.count > b.count)

	for item in sorted_counts:
		var expected = 0.0
		for c in sorted:
			if c.emoji == item.south:
				expected = c.probability * num_rolls
				break
		print("    %s/%s: %d (expected ~%.1f)" % [north, item.south, item.count, expected])

	print("")


func _finish() -> void:
	print("=".repeat(60))
	print("Test complete.")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
