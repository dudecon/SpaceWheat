extends SceneTree

func _init():
	print("Quest Board Simple Test")

	var farm_scene = load("res://scenes/FarmView.tscn")
	if not farm_scene:
		print("Failed to load main scene")
		quit()
		return

	var farm = farm_scene.instantiate()
	root.add_child(farm)

	print("Farm loaded successfully")
	quit()
