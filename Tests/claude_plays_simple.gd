extends SceneTree

## ⚠️ OUT OF SYNC WITH V2 ARCHITECTURE ⚠️
## This test uses the OLD Plot-based API (farm.build, farm.measure_plot, farm.harvest_plot)
## The v2 architecture uses Terminals via ProbeActions (action_explore, action_measure, action_pop)
## DO NOT RUN - needs rewrite to use ProbeActions + Terminal system
##
## Claude plays - simple non-recursive version

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var game_time: float = 0.0
var turn: int = 0

func _init():
	print("\n🎮 CLAUDE PLAYS SPACEWHEAT - SIMPLE VERSION!\n")

	# Create farm
	farm = Farm.new()
	root.add_child(farm)

	# Wait a bit for initialization
	var timer = Timer.new()
	root.add_child(timer)
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(_start_playing)
	timer.start()

func _start_playing():
	print("🌾 Farm initialized!")
	print("   Starting wheat: %d credits\n" % farm.economy.get_resource("🌾"))

	# Play 5 turns manually
	for i in range(5):
		_play_turn()

	print("\n✅ Game complete!")
	quit()

func _play_turn():
	turn += 1
	print("──────────────────────────────────────")
	print("🎮 TURN %d" % turn)

	var wheat = farm.economy.get_resource("🌾")
	print("💰 Wheat: %d credits" % wheat)

	# Find an empty plot
	var plot_pos = Vector2i(0, 0)

	# Simple strategy: just plant and harvest immediately
	if wheat >= 10:
		print("🌱 Planting wheat...")
		var success = farm.build(plot_pos, "wheat")
		if success:
			print("   ✅ Planted!")

			# Wait a bit for quantum evolution
			print("⏰ Waiting 3 days...")
			if farm.biotic_flux_biome:
				farm.biotic_flux_biome._process(60.0)  # 3 days
			game_time += 60.0

			# Measure
			print("📏 Measuring...")
			var outcome = farm.measure_plot(plot_pos)
			print("   Outcome: %s" % outcome)

			# Harvest
			print("🚜 Harvesting...")
			var result = farm.harvest_plot(plot_pos)
			if result.get("success"):
				print("   ✅ Yield: %d credits" % result.get("yield", 0))

	print("💰 Final wheat: %d credits\n" % farm.economy.get_resource("🌾"))
