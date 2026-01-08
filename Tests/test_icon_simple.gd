extends SceneTree

func _init():
	print("Testing Icon class...")
	# Don't reference Icon by name, just load it
	var IconClass = load("res://Core/QuantumSubstrate/Icon.gd")
	print("Loaded Icon script: %s" % IconClass)
	
	if IconClass:
		var icon_inst = IconClass.new()
		print("Created instance: %s" % icon_inst)
		icon_inst.emoji = "🌾"
		print("Set emoji to: %s" % icon_inst.emoji)
	
	quit(0)
