#!/usr/bin/env -S godot -s
extends SceneTree

## Simple icon test - no custom styling

func _init():
	print("\n=== SIMPLE ICON TEST ===")
	call_deferred("_run_test")

func _run_test():
	await process_frame
	
	# Create a simple button with icon - NO custom styling
	var btn = Button.new()
	btn.text = "[1] Probe"
	btn.icon = load("res://Assets/UI/Science/Probe.svg")
	btn.expand_icon = true
	btn.custom_minimum_size = Vector2(200, 55)
	root.add_child(btn)
	
	await process_frame
	
	print("Button created:")
	print("  icon: %s" % (btn.icon != null))
	print("  icon size: %s" % (btn.icon.get_size() if btn.icon else "N/A"))
	print("  button size: %s" % btn.size)
	print("  expand_icon: %s" % btn.expand_icon)
	
	# Check what theme properties affect icon display
	print("\nButton theme constants:")
	print("  h_separation: %s" % btn.get_theme_constant("h_separation"))
	print("  icon_max_width: %s" % btn.get_theme_constant("icon_max_width"))
	
	# Check if icon is visible by examining the internal nodes
	print("\nButton children: %d" % btn.get_child_count())
	
	print("\n=== TEST COMPLETE ===")
	print("Run WITHOUT --headless to see if icon displays visually!")
	
	quit(0)
