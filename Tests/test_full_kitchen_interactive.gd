#!/usr/bin/env -S godot -s
## Full Kitchen Interactive - Play through the complete cycle with keyboard!
##
## Controls:
##   Q - Plant wheat crops
##   W - Advance time (grow crops)
##   E - Harvest crops
##   R - Make bread in kitchen
##   T - Sell flour at market
##   Y - Sell bread for wheat
##   SPACE - Show current state
##   ESC - Quit

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const QuantumKitchen = preload("res://Core/Environment/QuantumKitchen_Biome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var farm: Farm
var kitchen: QuantumKitchen
var _harvest_qubits = []
var _bread_produced = 0
var _time_elapsed = 0.0

var state = {
	"crops_planted": false,
	"crops_grown": false,
	"crops_harvested": false,
	"kitchen_ready": false,
	"bread_produced": false,
	"flour_sold": false,
	"bread_sold": false,
}

var wheat_pos = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

func _init():
	_initialize_farm()
	_show_menu()

func _initialize_farm():
	print("\n" + "═" * 100)
	print("🍞 FULL KITCHEN INTERACTIVE - Play with keyboard!")
	print("═" * 100 + "\n")

	farm = Farm.new()
	farm._ready()

	# Initialize biomes
	if farm.biotic_flux_biome:
		farm.biotic_flux_biome._ready()
	if farm.market_biome:
		farm.market_biome._ready()
	if farm.forest_biome:
		farm.forest_biome._ready()
	if farm.kitchen_biome:
		farm.kitchen_biome._ready()

	# Start with resources
	var economy = farm.economy
	economy.add_resource("🌾", 5000)  # 500 wheat
	economy.add_resource("👥", 1000)  # 100 labor
	economy.add_resource("💨", 500)   # 50 flour

	print("✅ Farm initialized!")
	_show_state()

func _show_menu():
	print("\n" + "─" * 100)
	print("CONTROLS:")
	print("  Q - Plant wheat crops (for kitchen)")
	print("  W - Advance time (grow crops)")
	print("  E - Harvest crops")
	print("  R - Make bread in kitchen (Bell state)")
	print("  T - Sell flour at market")
	print("  Y - Sell bread for wheat (COMPLETE CYCLE!)")
	print("  SPACE - Show current state")
	print("  ESC - Quit")
	print("─" * 100 + "\n")

func _show_state():
	var economy = farm.economy
	print("\n📊 CURRENT STATE:")
	print("  🌾 Wheat: %d" % economy.get_resource("🌾"))
	print("  💨 Flour: %d" % economy.get_resource("💨"))
	print("  💰 Credits: %d" % economy.get_resource("💰"))
	print("  🍞 Bread: %d" % economy.get_resource("🍞"))
	print("  ⏱️  Time: %.1f seconds" % _time_elapsed)
	print("  📍 Status: Planted=%s, Grown=%s, Harvested=%s, Bread=%s, Sold=%s" % [
		state["crops_planted"], state["crops_grown"], state["crops_harvested"],
		state["bread_produced"], state["bread_sold"]
	])
	print()

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Q:
				_plant_crops()
			KEY_W:
				_advance_time()
			KEY_E:
				_harvest_crops()
			KEY_R:
				_make_bread()
			KEY_T:
				_sell_flour()
			KEY_Y:
				_sell_bread()
			KEY_SPACE:
				_show_state()
			KEY_ESCAPE:
				quit()

func _plant_crops():
	if state["crops_planted"]:
		print("❌ Crops already planted!")
		return

	print("\n🌱 PLANTING WHEAT CROPS...")
	print("━" * 100)

	for pos in wheat_pos:
		var success = farm.build(pos, "wheat")
		if success:
			print("  ✓ Planted wheat at %s" % pos)
		else:
			print("  ✗ Failed to plant wheat at %s" % pos)
			return

	state["crops_planted"] = true
	print("✅ All 3 crops planted in GHZ pattern!")
	print()

func _advance_time():
	if not state["crops_planted"]:
		print("❌ Plant crops first (press Q)!")
		return

	if state["crops_grown"]:
		print("⚠️  Crops already grown!")
		return

	print("\n🌿 ADVANCING TIME (growing crops)...")
	print("━" * 100)

	# Simulate growth
	var steps = 20
	var step_size = 0.1
	for i in range(steps):
		if farm.biotic_flux_biome:
			farm.biotic_flux_biome._process(step_size)
		if farm.market_biome:
			farm.market_biome._process(step_size)
		if farm.kitchen_biome:
			farm.kitchen_biome._process(step_size)
		_time_elapsed += step_size

		# Show progress
		if (i + 1) % 5 == 0:
			print("  ⏳ %d/%d steps..." % [i + 1, steps])

	state["crops_grown"] = true
	print("✅ Crops grown! (%.1f seconds)" % _time_elapsed)
	print()

func _harvest_crops():
	if not state["crops_planted"]:
		print("❌ Plant crops first (press Q)!")
		return

	if not state["crops_grown"]:
		print("❌ Grow crops first (press W)!")
		return

	if state["crops_harvested"]:
		print("❌ Already harvested!")
		return

	print("\n✂️  HARVESTING CROPS...")
	print("━" * 100)

	# Capture register IDs before harvest
	_harvest_qubits = []
	for pos in wheat_pos:
		var plot = farm.get_plot(pos)
		if plot and plot.is_planted and plot.parent_biome and plot.register_id >= 0:
			_harvest_qubits.append({
				"pos": pos,
				"biome": plot.parent_biome,
				"register_id": plot.register_id
			})

	# Harvest each plot
	for pos in wheat_pos:
		var measurement = farm.measure_plot(pos)
		var harvest = farm.harvest_plot(pos)
		if harvest.is_empty():
			print("  ✗ Harvest failed at %s" % pos)
			return
		print("  ✓ Harvested from %s → %s" % [pos, measurement])

	state["crops_harvested"] = true
	print("✅ All crops harvested! (%d registers saved)" % _harvest_qubits.size())
	print()

func _make_bread():
	if not state["crops_harvested"]:
		print("❌ Harvest crops first (press E)!")
		return

	if state["bread_produced"]:
		print("❌ Already made bread!")
		return

	print("\n👨‍🍳 MAKING BREAD (Quantum measurement)...")
	print("━" * 100)

	# Create kitchen
	kitchen = QuantumKitchen.new()
	if not kitchen:
		print("  ✗ Failed to create kitchen")
		return

	kitchen._ready()
	print("  ✓ Kitchen created")

	# Configure Bell state
	var is_valid = kitchen.configure_bell_state(wheat_pos)
	if not is_valid:
		print("  ✗ Bell state configuration failed")
		return

	print("  ✓ Bell state detected: GHZ (Horizontal)")

	# Create input qubits
	var input_qubits = []
	for i in range(_harvest_qubits.size()):
		var data = _harvest_qubits[i]
		var qubit = DualEmojiQubit.new()
		qubit.north_emoji = "🌾" if i == 0 else ("💧" if i == 1 else "💨")
		qubit.south_emoji = "👥"
		qubit.register_id = data["register_id"]
		qubit.parent_biome = data["biome"]
		input_qubits.append(qubit)

	if input_qubits.size() >= 3:
		kitchen.set_input_qubits(input_qubits[0], input_qubits[1], input_qubits[2])
		print("  ✓ Kitchen inputs configured")

	# Produce bread
	var bread_qubit = kitchen.produce_bread()
	if not bread_qubit:
		print("  ✗ Bread production failed")
		return

	print("  ✓ Bread produced!")
	print("    - Radius: %.4f" % bread_qubit.radius)
	print("    - Purity: %.4f" % bread_qubit.purity)

	_bread_produced = 1
	state["bread_produced"] = true
	farm.economy.add_resource("🍞", 1)  # Add bread to economy
	print("✅ Bread created and added to inventory!")
	print()

func _sell_flour():
	if not state["crops_harvested"]:
		print("❌ Harvest crops first (press E)!")
		return

	var economy = farm.economy
	var flour = economy.get_resource("💨")

	if flour <= 0:
		print("❌ No flour to sell!")
		return

	print("\n💰 SELLING FLOUR AT MARKET...")
	print("━" * 100)

	var flour_to_trade = min(10, flour)
	var credits_per_flour = 80

	economy.add_resource("💨", -flour_to_trade)
	economy.add_resource("💰", flour_to_trade * credits_per_flour)

	print("  ✓ Sold %d flour" % flour_to_trade)
	print("  ✓ Received %d credits" % (flour_to_trade * credits_per_flour))

	state["flour_sold"] = true
	print("✅ Flour sold!")
	print()

func _sell_bread():
	if _bread_produced <= 0:
		print("❌ Make bread first (press R)!")
		return

	var economy = farm.economy
	var bread = economy.get_resource("🍞")

	if bread <= 0:
		print("❌ No bread to sell!")
		return

	print("\n🍞 SELLING BREAD FOR WHEAT (COMPLETING THE CYCLE!)...")
	print("━" * 100)

	var wheat_before = economy.get_resource("🌾")
	var bread_to_trade = bread
	var wheat_per_bread = 100

	economy.add_resource("🍞", -bread_to_trade)
	economy.add_resource("🌾", bread_to_trade * wheat_per_bread)

	var wheat_after = economy.get_resource("🌾")

	print("  ✓ Sold %d bread" % bread_to_trade)
	print("  ✓ Received %d wheat" % (bread_to_trade * wheat_per_bread))
	print("  🌾 Wheat: %d → %d" % [wheat_before, wheat_after])

	print("\n  ✅ FULL CYCLE COMPLETE!")
	print("     🌾 Wheat → Farm → Harvest → Kitchen → Bread → Market → Wheat 🔄")

	state["bread_sold"] = true
	print("✅ Bread sold! Ready to plant again!")
	print()

func rad_to_deg(radians: float) -> float:
	return radians * 180.0 / PI
