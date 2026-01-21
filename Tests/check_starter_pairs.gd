extends Node

const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")

func _ready() -> void:
	await get_tree().process_frame

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		print("No IconRegistry")
		get_tree().quit()
		return

	print("\n=== Starter Emoji Connections ===\n")

	for emoji in ["🌾", "👥", "🍂", "🌱"]:
		print("--- %s ---" % emoji)
		var sorted = VocabularyPairing.get_sorted_connections(emoji, icon_registry)
		if sorted.is_empty():
			print("  (no connections)")
		else:
			for c in sorted.slice(0, 5):
				print("  %s/%s: %.1f%% [H=%.2f L_in=%.2f L_out=%.2f]" % [
					emoji, c.emoji, c.probability * 100,
					c.h, c.l_in, c.l_out
				])
		print("")

	get_tree().quit()
