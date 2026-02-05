extends Node

## Diagnostic: Check C++ module loading

func _ready():
	print("\n" + "=".repeat(70))
	print("DIAGNOSTIC TEST - C++ Module Status")
	print("=".repeat(70))

	# Check each C++ class
	var classes_to_check = [
		"QuantumMatrixNative",
		"QuantumEvolutionEngine",
		"MultiBiomeLookaheadEngine",
		"ForceGraphEngine",
		"ParametricSelectorNative"
	]

	print("\n[CHECK] C++ Class Availability:")
	for i in classes_to_check.size():
		var class_name = classes_to_check[i]
		var exists = ClassDB.class_exists(class_name)
		var status = "✅" if exists else "❌"
		print("  %s %s" % [status, class_name])

	# Try to instantiate the most critical one
	print("\n[TEST] Attempting to instantiate MultiBiomeLookaheadEngine...")
	if ClassDB.class_exists("MultiBiomeLookaheadEngine"):
		var engine = ClassDB.instantiate("MultiBiomeLookaheadEngine")
		if engine:
			print("  ✅ Successfully instantiated")
			print("  Methods available:")
			var methods = engine.get_method_list()
			for method in methods:
				if "biome" in method.name.to_lower():
					print("    - %s" % method.name)
		else:
			print("  ❌ Failed to instantiate")
	else:
		print("  ❌ Class not found")

	# Check BubbleAtlasBatcher
	print("\n[TEST] Checking BubbleAtlasBatcher...")
	var BubbleAtlasBatcherClass = load("res://Core/Visualization/BubbleAtlasBatcher.gd")
	if BubbleAtlasBatcherClass:
		print("  ✅ BubbleAtlasBatcher.gd loads")
		var atlas = BubbleAtlasBatcherClass.new()
		if atlas:
			print("  ✅ Can instantiate BubbleAtlasBatcher")
			print("  [INFO] Attempting to build bubble atlas...")
			var start = Time.get_ticks_msec()
			var result = atlas.build_atlas()
			var elapsed = Time.get_ticks_msec() - start
			if result:
				print("  ✅ build_atlas() completed in %dms" % elapsed)
			else:
				print("  ❌ build_atlas() failed")
		else:
			print("  ❌ Cannot instantiate BubbleAtlasBatcher")
	else:
		print("  ❌ BubbleAtlasBatcher.gd not found")

	# Check EmojiAtlasBatcher
	print("\n[TEST] Checking EmojiAtlasBatcher...")
	var EmojiAtlasBatcherClass = load("res://Core/Visualization/EmojiAtlasBatcher.gd")
	if EmojiAtlasBatcherClass:
		print("  ✅ EmojiAtlasBatcher.gd loads")
		var emoji_atlas = EmojiAtlasBatcherClass.new()
		if emoji_atlas:
			print("  ✅ Can instantiate EmojiAtlasBatcher")
		else:
			print("  ❌ Cannot instantiate EmojiAtlasBatcher")
	else:
		print("  ❌ EmojiAtlasBatcher.gd not found")

	print("\n" + "=".repeat(70))
	print("Press ESC to exit")
	print("=".repeat(70) + "\n")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
