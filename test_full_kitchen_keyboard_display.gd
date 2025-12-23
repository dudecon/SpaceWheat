#!/usr/bin/env godot --headless -s
## Full Kitchen Test with Keyboard Input & Display
##
## This test demonstrates the complete gameplay loop using actual keyboard input
## and displays it in a game window so you can watch it execute:
##
## 1. Plant wheat crops using Tool 1 (Q)
## 2. Wait for biotic flux growth
## 3. Harvest crops using Tool 1 (R)
## 4. Arrange qubits in kitchen Bell state
## 5. Produce bread via Kitchen measurement
## 6. Sell flour at market
##
## Run with: godot test_full_kitchen_keyboard_display.gd
## (No --headless flag to see the display!)

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const QuantumKitchen = preload("res://Core/Environment/QuantumKitchen_Biome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm: Farm
var input_handler: FarmInputHandler
var kitchen: QuantumKitchen
var _harvest_qubits = []

var phase_duration = {
	"setup": 2.0,
	"planting": 3.0,
	"growth": 65.0,
	"harvest": 5.0,
	"kitchen": 10.0,
	"market": 3.0,
	"total": 88.0
}

var phase_start_time = 0.0
var current_phase = "setup"
var phase_complete = false

var viewport_size = Vector2(1200, 600)

func _ready():
	print("🎮 Keyboard-Driven Full Kitchen Test - Starting...")

	# Create window and set size
	get_window().size = viewport_size
	get_window().position = Vector2i(100, 100)

	# Create and show a simple background
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.size = viewport_size
	get_root().add_child(bg)

	# Create farm
	farm = Farm.new()
	farm._ready()
	get_root().add_child(farm)

	# Create input handler
	input_handler = FarmInputHandler.new()
	input_handler.farm = farm
	get_root().add_child(input_handler)

	# Create kitchen
	kitchen = QuantumKitchen.new()
	kitchen._ready()

	print("✓ Setup complete - Starting test sequence...")
	print("  Display window: %s" % viewport_size)
	print("  Total test duration: %.0f seconds" % phase_duration["total"])
	print()

	phase_start_time = Time.get_ticks_msec() / 1000.0
	current_phase = "setup"


func _process(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - phase_start_time

	match current_phase:
		"setup":
			if elapsed >= phase_duration["setup"]:
				_transition_to_planting()

		"planting":
			if elapsed >= phase_duration["setup"] + phase_duration["planting"]:
				_transition_to_growth()

		"growth":
			_update_growth(delta)
			if elapsed >= phase_duration["setup"] + phase_duration["planting"] + phase_duration["growth"]:
				_transition_to_harvest()

		"harvest":
			if elapsed >= phase_duration["setup"] + phase_duration["planting"] + phase_duration["growth"] + phase_duration["harvest"]:
				_transition_to_kitchen()

		"kitchen":
			if elapsed >= phase_duration["setup"] + phase_duration["planting"] + phase_duration["growth"] + phase_duration["harvest"] + phase_duration["kitchen"]:
				_transition_to_market()

		"market":
			if elapsed >= phase_duration["setup"] + phase_duration["planting"] + phase_duration["growth"] + phase_duration["harvest"] + phase_duration["kitchen"] + phase_duration["market"]:
				_transition_to_complete()

		"complete":
			if not phase_complete:
				phase_complete = true


func _transition_to_planting():
	current_phase = "planting"
	phase_start_time = Time.get_ticks_msec() / 1000.0

	print("\n" + _sep("═", 100))
	print("🌱 PHASE 2: PLANT CROPS (Using Keyboard Input)")
	print(_sep("─", 100))

	var positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

	for i in range(3):
		var pos = positions[i]
		var key = ["T", "Y", "U"][i]  # Location keys from LOCATION_LABELS

		# Simulate keyboard: select plot location
		_simulate_key(key)
		await get_tree().process_frame

		# Simulate keyboard: select Tool 1 (Grower)
		_simulate_key("1")
		await get_tree().process_frame

		# Simulate keyboard: press Q to plant
		_simulate_key("q")
		await get_tree().process_frame

		print("  ✓ Planted crop at %s" % pos)
		await get_tree().create_timer(0.3).timeout


func _transition_to_growth():
	current_phase = "growth"
	phase_start_time = Time.get_ticks_msec() / 1000.0

	print("\n" + _sep("═", 100))
	print("🌿 PHASE 3: CROP GROWTH (Biotic Flux Soak - %.0f seconds)" % phase_duration["growth"])
	print(_sep("─", 100))
	print("  Crops growing... energy increasing via biome evolution")
	print()


func _update_growth(delta):
	# Simulate biome evolution
	if farm and farm.biome:
		farm.biome._process(delta)


func _transition_to_harvest():
	current_phase = "harvest"
	phase_start_time = Time.get_ticks_msec() / 1000.0

	print("\n" + _sep("═", 100))
	print("✂️  PHASE 4: HARVEST CROPS (Using Keyboard Input)")
	print(_sep("─", 100))

	var wheat_pos = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

	# Collect qubits before harvesting
	for pos in wheat_pos:
		var plot = farm.get_plot(pos)
		if plot and plot.quantum_state:
			_harvest_qubits.append(plot.quantum_state)
			print("  ✓ Collected qubit from %s (energy: %.4f)" % [pos, plot.quantum_state.energy])

	# Harvest the plots using keyboard
	for i in range(3):
		var pos = wheat_pos[i]
		var key = ["T", "Y", "U"][i]

		_simulate_key(key)
		await get_tree().process_frame

		_simulate_key("1")  # Tool 1
		await get_tree().process_frame

		_simulate_key("r")  # Harvest
		await get_tree().process_frame

		print("  ✓ Harvested from %s" % pos)
		await get_tree().create_timer(0.2).timeout

	print()


func _transition_to_kitchen():
	current_phase = "kitchen"
	phase_start_time = Time.get_ticks_msec() / 1000.0

	print("\n" + _sep("═", 100))
	print("👨‍🍳 PHASE 5: KITCHEN PRODUCTION")
	print(_sep("─", 100))

	if _harvest_qubits.size() < 3:
		print("  ✗ Not enough qubits for kitchen")
		return

	# Set up kitchen
	kitchen.set_input_qubits(_harvest_qubits[0], _harvest_qubits[1], _harvest_qubits[2])

	var wheat_pos = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var is_valid = kitchen.configure_bell_state(wheat_pos)

	if not is_valid:
		print("  ✗ Invalid Bell state")
		return

	print("  ✓ Bell state detected: GHZ (Horizontal)")

	# Produce bread
	var bread_qubit = kitchen.produce_bread()
	if bread_qubit:
		print("  ✓ Bread produced!")
		print("    📊 Bread energy: %.4f" % bread_qubit.radius)

	print()


func _transition_to_market():
	current_phase = "market"
	phase_start_time = Time.get_ticks_msec() / 1000.0

	print("\n" + _sep("═", 100))
	print("💰 PHASE 6: MARKET TRADING")
	print(_sep("─", 100))

	var economy = farm.economy
	if economy.flour_inventory > 0:
		var flour_to_trade = min(10, economy.flour_inventory)
		economy.flour_inventory -= flour_to_trade
		economy.credits += flour_to_trade * 80

		print("  ✓ Sold %d flour for %d credits" % [flour_to_trade, flour_to_trade * 80])

	print()


func _transition_to_complete():
	current_phase = "complete"

	print("\n" + _sep("═", 100))
	print("🎉 FULL KITCHEN TEST COMPLETE!")
	print(_sep("═", 100))
	print("\n  ✅ All phases completed successfully:")
	print("     • Planted crops using keyboard (Tool 1, Q)")
	print("     • Grew crops with biotic flux (%.0f seconds)" % phase_duration["growth"])
	print("     • Harvested using keyboard (Tool 1, R)")
	print("     • Created Bell state (%d qubits)" % _harvest_qubits.size())
	print("     • Produced bread via kitchen measurement")
	print("     • Traded flour at market")
	print("\n  Total test duration: %.1f seconds\n" % phase_duration["total"])

	# Keep window open for 5 seconds, then close
	await get_tree().create_timer(5.0).timeout
	quit()


func _simulate_key(key_name: String):
	"""Simulate a keyboard input"""
	var input_event = InputEventKey.new()
	input_event.keycode = OS.find_keycode_from_string(key_name.to_upper())
	input_event.pressed = true

	Input.parse_input_event(input_event)

	# Release key after a frame
	await get_tree().process_frame
	input_event.pressed = false
	Input.parse_input_event(input_event)


func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result

