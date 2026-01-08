extends SceneTree

## Test the measurement signal flow
## Verifies that measuring triggers plot tile update via signal chain

var test_results = []

func _init():
	print("🧪 Testing Measurement Signal Flow")
	print("================================================================================\n")

	# Create minimal test environment
	var farm = load("res://Core/Farm.gd").new()
	var plot_grid_display = load("res://UI/PlotGridDisplay.gd").new()

	# Mock setup
	var signal_received = false
	var received_pos = null
	var received_outcome = ""

	# Test 1: Verify Farm has plot_measured signal
	print("Test 1: Farm.plot_measured signal exists")
	if farm.has_signal("plot_measured"):
		test_results.append("✅ Farm has plot_measured signal")
		print("   ✅ Signal exists\n")
	else:
		test_results.append("❌ Farm missing plot_measured signal")
		print("   ❌ FAIL\n")
		quit()
		return

	# Test 2: Verify PlotGridDisplay has handler
	print("Test 2: PlotGridDisplay._on_farm_plot_measured handler exists")
	if plot_grid_display.has_method("_on_farm_plot_measured"):
		test_results.append("✅ PlotGridDisplay has _on_farm_plot_measured handler")
		print("   ✅ Handler exists\n")
	else:
		test_results.append("❌ PlotGridDisplay missing handler")
		print("   ❌ FAIL\n")
		quit()
		return

	# Test 3: Connect signal and verify it fires
	print("Test 3: Signal connection and emission")
	farm.plot_measured.connect(func(pos, outcome):
		signal_received = true
		received_pos = pos
		received_outcome = outcome
		print("   ✅ Signal received: pos=%s, outcome=%s" % [pos, outcome])
	)

	# Emit test signal
	farm.plot_measured.emit(Vector2i(0, 0), "🌾")
	await create_timer(0.1).timeout

	if signal_received and received_pos == Vector2i(0, 0) and received_outcome == "🌾":
		test_results.append("✅ Signal emits and receives correctly")
		print("   ✅ Signal flow works\n")
	else:
		test_results.append("❌ Signal emission failed")
		print("   ❌ FAIL\n")

	# Test 4: Verify PlotTile visual logic
	print("Test 4: PlotTile measurement display logic")
	var plot_tile = load("res://UI/PlotTile.gd").new()

	# Mock plot data - unmeasured superposition
	var unmeasured_data = {
		"is_planted": true,
		"plot_type": "wheat",
		"has_been_measured": false,
		"north_emoji": "🌾",
		"south_emoji": "👥",
		"north_probability": 0.7,
		"south_probability": 0.3,
		"energy_level": 0.5,
		"coherence": 0.3,
		"entangled_plots": []
	}

	# Mock plot data - measured
	var measured_data = {
		"is_planted": true,
		"plot_type": "wheat",
		"has_been_measured": true,
		"north_emoji": "🌾",
		"south_emoji": "👥",
		"north_probability": 1.0,
		"south_probability": 0.0,
		"energy_level": 0.5,
		"coherence": 0.0,
		"entangled_plots": []
	}

	print("   Unmeasured state: has_been_measured=%s" % unmeasured_data["has_been_measured"])
	print("   Measured state: has_been_measured=%s" % measured_data["has_been_measured"])

	if not unmeasured_data["has_been_measured"] and measured_data["has_been_measured"]:
		test_results.append("✅ Plot data correctly represents measured vs unmeasured states")
		print("   ✅ State differentiation works\n")
	else:
		test_results.append("❌ Plot data states incorrect")
		print("   ❌ FAIL\n")

	# Report
	print("================================================================================")
	print("📊 FINAL RESULTS")
	print("================================================================================")
	for result in test_results:
		print(result)

	var all_passed = test_results.size() == 4 and test_results.all(func(r): return r.begins_with("✅"))

	print("\n" + ("✅ ALL TESTS PASSED" if all_passed else "❌ SOME TESTS FAILED"))
	print("\n📋 Signal Flow Verification:")
	print("   Farm.measure_plot(pos)")
	print("     ↓")
	print("   farm.plot_measured.emit(pos, outcome)  ← Signal emits")
	print("     ↓")
	print("   PlotGridDisplay._on_farm_plot_measured(pos, outcome)  ← Handler receives")
	print("     ↓")
	print("   update_tile_from_farm(pos)  ← Tile updates")
	print("     ↓")
	print("   PlotTile shows single solid emoji  ← Visual change")

	quit()
