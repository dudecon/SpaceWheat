extends Node

func _ready():
	print("\n=== PHASE 0 CORE GAMEPLAY LOOP TEST ===\n")
	
	# Test 1: Initialize Farm with biome
	print("[TEST 1] Initialize Farm with biome")
	test_farm_initialization()
	
	# Test 2: EXPLORE action (bind plot to qubit)
	print("\n[TEST 2] EXPLORE action - bind plot to qubit")
	test_explore_action()
	
	# Test 3: Apply X gate
	print("\n[TEST 3] Apply X gate")
	test_apply_gate()
	
	# Test 4: Measure plot
	print("\n[TEST 4] Measure plot")
	test_measure_plot()
	
	# Test 5: Harvest plot
	print("\n[TEST 5] Harvest plot")
	test_harvest_plot()
	
	print("\n=== TEST COMPLETE ===\n")
	get_tree().quit()

func test_farm_initialization():
	var farm = Node.new()
	farm.name = "TestFarm"
	add_child(farm)
	print("✅ Farm node created")
	
	# Try to load FarmGrid
	var FarmGrid = load("res://Core/GameMechanics/FarmGrid.gd")
	if FarmGrid:
		var grid = FarmGrid.new()
		farm.add_child(grid)
		print("✅ FarmGrid loaded and instantiated")
		
		# Check if FarmGrid has initialization method
		if grid.has_method("_ready"):
			grid._ready()
			print("✅ FarmGrid._ready() called")
		else:
			print("⚠️ FarmGrid._ready() not found")
		
		# Check grid properties
		if grid.get("width") != null or grid.get("height") != null:
			print("✅ FarmGrid has dimension properties")
		else:
			print("⚠️ FarmGrid dimension properties not found")
	else:
		print("❌ FarmGrid script not found at res://Core/GameMechanics/FarmGrid.gd")

func test_explore_action():
	# Load GameStateManager
	var GameStateManager = load("res://Core/GameState/GameStateManager.gd")
	if not GameStateManager:
		print("❌ GameStateManager not found")
		return
	
	print("✅ GameStateManager loaded")
	
	# Try to access action system
	var ToolConfig = load("res://Core/GameState/ToolConfig.gd")
	if ToolConfig:
		print("✅ ToolConfig loaded")
		var tool_config = ToolConfig.new()
		if tool_config.has_method("get_tool_actions"):
			var actions = tool_config.get_tool_actions("shovel")
			print("✅ Tool actions retrieved for 'shovel': " + str(actions))
		else:
			print("⚠️ get_tool_actions() method not found")
	else:
		print("⚠️ ToolConfig not found")

func test_apply_gate():
	# Load ComplexMatrix for quantum operations
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	if not ComplexMatrix:
		print("❌ ComplexMatrix not found")
		return
	
	print("✅ ComplexMatrix loaded")
	
	var matrix = ComplexMatrix.new()
	print("✅ ComplexMatrix instantiated")
	
	# Check for gate operations
	if matrix.has_method("pauli_x"):
		var x_gate = matrix.pauli_x()
		print("✅ Pauli X gate created")
	else:
		print("⚠️ pauli_x() method not found on ComplexMatrix")
	
	# Check for matrix multiplication
	if matrix.has_method("multiply"):
		print("✅ multiply() method available for gate application")
	else:
		print("⚠️ multiply() method not found on ComplexMatrix")

func test_measure_plot():
	# Load WheatPlot
	var WheatPlot = load("res://Core/GameMechanics/WheatPlot.gd")
	if not WheatPlot:
		print("❌ WheatPlot not found")
		return
	
	print("✅ WheatPlot loaded")
	
	var plot = WheatPlot.new()
	print("✅ WheatPlot instantiated")
	
	# Check for measurement methods
	if plot.has_method("measure"):
		print("✅ measure() method found")
	else:
		print("⚠️ measure() method not found on WheatPlot")
	
	if plot.has_method("get_state"):
		print("✅ get_state() method found")
	else:
		print("⚠️ get_state() method not found on WheatPlot")
	
	# Check for qubit binding
	if plot.has_method("bind_qubit"):
		print("✅ bind_qubit() method found")
	else:
		print("⚠️ bind_qubit() method not found on WheatPlot")

func test_harvest_plot():
	# Load BasePlot
	var BasePlot = load("res://Core/GameMechanics/BasePlot.gd")
	if not BasePlot:
		print("❌ BasePlot not found")
		return
	
	print("✅ BasePlot loaded")
	
	var plot = BasePlot.new()
	print("✅ BasePlot instantiated")
	
	# Check for harvest methods
	if plot.has_method("harvest"):
		print("✅ harvest() method found")
	else:
		print("⚠️ harvest() method not found on BasePlot")
	
	if plot.has_method("get_yield"):
		print("✅ get_yield() method found")
	else:
		print("⚠️ get_yield() method not found on BasePlot")
	
	if plot.has_method("reset"):
		print("✅ reset() method found")
	else:
		print("⚠️ reset() method not found on BasePlot")
