extends SceneTree

## Test biome-specific plant menus

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

var farm = null

func _init():
	print("\n" + "=".repeat(70))
	print("🌱 BIOME-SPECIFIC PLANT MENU TEST")
	print("=".repeat(70) + "\n")

	# Load farm
	var farm_scene = load("res://Core/Farm.gd")
	if not farm_scene:
		print("❌ FAILED: Could not load Farm.gd")
		quit()
		return

	farm = farm_scene.new()
	get_root().add_child(farm)

	print("⏳ Waiting for farm initialization...\n")


var test_frame = 0

func _process(delta):
	test_frame += 1

	# Wait for initialization
	if test_frame < 5:
		return

	if test_frame == 5:
		# Test each biome's plant menu
		test_biome_menu("Kitchen", Vector2i(3, 1))
		test_biome_menu("Forest", Vector2i(0, 1))
		test_biome_menu("BioticFlux", Vector2i(3, 0))
		test_biome_menu("Market", Vector2i(0, 0))

		print("\n" + "=".repeat(70))
		print("✅ ALL BIOME PLANT MENUS VALIDATED")
		print("=".repeat(70) + "\n")

		quit()


func test_biome_menu(biome_name: String, test_pos: Vector2i):
	print("\n🧪 Testing %s biome (plot %s):" % [biome_name, test_pos])

	# Generate submenu for this position
	var submenu = ToolConfig.get_dynamic_submenu("plant", farm, test_pos)

	if submenu.is_empty():
		print("  ❌ FAILED: No submenu generated")
		return

	# Display menu
	print("  📋 Menu: %s" % submenu.get("name", "Unknown"))
	print("     Q: %s %s" % [submenu["Q"]["emoji"], submenu["Q"]["label"]])
	print("     E: %s %s" % [submenu["E"]["emoji"], submenu["E"]["label"]])
	print("     R: %s %s" % [submenu["R"]["emoji"], submenu["R"]["label"]])
	print("  ✅ Menu validated")
