extends Control

## FarmView - Main UI scene for the quantum wheat farming game
## Acts as a simple coordinator that delegates to FarmUIController
##
## Phase 4a: Decentralized Architecture
## - Removed ~2,400 lines of implementation
## - Now ~50 lines of simple coordination
## - All heavy lifting delegated to FarmUIController

# Import the orchestration layer
const FarmUIController = preload("res://UI/FarmUIController.gd")
const Farm = preload("res://Core/Farm.gd")
const FactionManager = preload("res://Core/GameMechanics/FactionManager.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")


# The UI controller that handles all orchestration
var ui_controller: FarmUIController
var test_farm: Node = null  # For test mode access


## INITIALIZATION

func _ready() -> void:
	"""Initialize FarmView by creating and configuring the UI controller"""
	print("🎮 FarmView initializing...")

	# Set anchors first to avoid Godot warnings about anchor/size conflicts
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Then size FarmView to match viewport
	var viewport_size = get_viewport().get_visible_rect().size
	size = viewport_size
	position = Vector2.ZERO
	custom_minimum_size = Vector2.ZERO

	print("📐 FarmView sized to viewport: %s" % size)

	# Create the orchestration layer
	ui_controller = FarmUIController.new()
	add_child(ui_controller)
	# UI controller should fill FarmView (set after adding to tree)
	ui_controller.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Inject dependencies (farm and systems created by GameController)
	if has_meta("farm"):
		var farm = get_meta("farm")
		test_farm = farm
		var faction_manager = get_meta("faction_manager") if has_meta("faction_manager") else null
		var vocabulary_system = get_meta("vocabulary_system") if has_meta("vocabulary_system") else null
		var conspiracy_network = get_meta("conspiracy_network") if has_meta("conspiracy_network") else null

		ui_controller.inject_farm(farm, faction_manager, vocabulary_system, conspiracy_network)
	else:
		# No farm provided - create a default simple farm for testing
		print("📝 No farm provided - creating default UIOP farm (6x1)...")

		# Use call_deferred to ensure FarmView is ready before initializing farm
		call_deferred("_initialize_default_farm")

	# UI controller will initialize everything in its _ready()
	print("✅ FarmView ready - delegating to FarmUIController")


func _initialize_default_farm() -> void:
	"""Initialize the default farm after FarmView is fully ready"""
	var farm = Farm.new()
	test_farm = farm

	# Add farm to scene tree (needed for _ready() to be called)
	add_child(farm)
	print("✅ Farm added to scene tree")

	# Wait for farm._ready() to complete by waiting for a process frame
	# _ready() is called during add_child(), completes in this frame
	await get_tree().process_frame
	print("   ✅ Farm _ready() completed - grid is now initialized")

	# Biomes are automatically initialized when farm._ready() is called
	# Quantum states evolve over time, sun/moon cycles, icons influence growth
	print("   🌍 Biomes initialized with full quantum evolution")

	# Wrap farm with adapter to implement ControlsInterface
	var AdapterClass = load("res://UI/FarmControlsAdapter.gd")
	var controls = AdapterClass.new(farm)

	# Bridge signals immediately after creation
	controls.bridge_farm_signals()

	# Inject into UI controller - BOTH the adapter AND the farm
	# CRITICAL: Now farm.grid is guaranteed to be initialized
	ui_controller.inject_controls(controls)
	ui_controller.inject_farm(farm)  # This triggers signal connections in controls_manager

	print("✅ Default farm created with FarmControlsAdapter")

	# Check if auto-play test mode is enabled
	if OS.get_environment("GODOT_TEST_AUTOPLAY") == "1":
		print("\n🎬 AUTO-PLAY TEST MODE DETECTED - Starting automatic demo...")
		call_deferred("_run_autoplay_test")


## VIEWPORT HANDLING

func _on_viewport_resized() -> void:
	"""Handle viewport resize"""
	if ui_controller:
		ui_controller._on_viewport_size_changed()


## PUBLIC API (Delegated to UI Controller)

func show_message(text: String) -> void:
	"""Show informational message"""
	if ui_controller:
		ui_controller.show_message(text)


func show_error(text: String) -> void:
	"""Show error message"""
	if ui_controller:
		ui_controller.show_error(text)


func get_selected_plot() -> Vector2i:
	"""Get current keyboard-selected plot"""
	if ui_controller:
		return ui_controller.get_current_selected_plot()
	return Vector2i(-1, -1)


func inject_farm(farm_ref) -> void:
	"""Inject farm data after UI initialized (called by GameStateManager)"""
	if ui_controller:
		ui_controller.inject_farm_late(farm_ref)


## AUTO-PLAY TEST MODE

func _run_autoplay_test() -> void:
	"""Run automated test sequence to demonstrate Q/E/R gameplay loop"""
	var header_line = ""
	for _i in range(70):
		header_line += "="
	print("\n" + header_line)
	print("🎬 STARTING AUTOMATED GAMEPLAY DEMO")
	print(header_line + "\n")

	# Wait for UI to fully render
	await get_tree().create_timer(2.0).timeout

	# Get the input handler from the UI controller
	if not ui_controller or not ui_controller.controls_manager:
		print("ERROR: Could not find controls manager")
		return

	var input_handler = ui_controller.controls_manager.get_input_handler()
	if not input_handler:
		print("ERROR: Could not find input handler")
		return

	print("✅ Input handler found - beginning test sequence...\n")

	# Test sequence
	await _test_step_1(input_handler)
	await _test_step_2(input_handler)
	await _test_step_3(input_handler)
	await _test_step_4(input_handler)
	await _test_step_5(input_handler)
	await _test_step_6(input_handler)
	await _test_step_7(input_handler)
	await _test_step_8(input_handler)
	await _test_step_9(input_handler)
	await _test_step_10(input_handler)
	await _test_step_11(input_handler)

	var equals_line = ""
	for _i in range(70):
		equals_line += "="
	print("\n" + equals_line)
	print("✅ AUTOPLAY TEST COMPLETE!")
	print(equals_line)
	print("\nAll Q/E/R actions executed successfully.")
	print("Check the console above and watch the UI for state changes.\n")

	await get_tree().create_timer(2.0).timeout
	get_tree().quit()


func _print_test_header(step: int, title: String) -> void:
	var line = ""
	for _i in range(70):
		line += "-"
	print("\n" + line)
	print("STEP %d: %s" % [step, title])
	print(line)


func _wait_and_display(seconds: float) -> void:
	"""Wait with visual feedback"""
	for i in range(int(seconds * 10)):
		await get_tree().process_frame


func _test_step_1(handler: Node) -> void:
	_print_test_header(1, "Select Tool 1 (Plant Tool)")
	print("Action: Emit tool_changed for tool 1")
	handler._select_tool(1)
	await _wait_and_display(1.5)


func _test_step_2(handler: Node) -> void:
	_print_test_header(2, "Select Plot Y (Position 1,0)")
	print("Action: Set selection to Y")
	handler._set_selection(Vector2i(1, 0))
	await _wait_and_display(1.5)


func _test_step_3(handler: Node) -> void:
	_print_test_header(3, "Execute Q Action (Plant Wheat)")
	print("Action: Plant wheat at selected position")
	print("Expected: 5 credits deducted, plot shows planted")
	handler._execute_tool_action("Q")
	await _wait_and_display(2.0)


func _test_step_4(handler: Node) -> void:
	_print_test_header(4, "Select Plot U (Position 2,0)")
	print("Action: Move selection to U")
	handler._set_selection(Vector2i(2, 0))
	await _wait_and_display(1.5)


func _test_step_5(handler: Node) -> void:
	_print_test_header(5, "Execute E Action (Plant Mushroom)")
	print("Action: Plant mushroom at position 2,0")
	handler._execute_tool_action("E")
	await _wait_and_display(2.0)


func _test_step_6(handler: Node) -> void:
	_print_test_header(6, "Switch to Tool 2 (Quantum Ops)")
	print("Action: Change tool to Quantum Ops")
	print("Expected: Action menu updates to Q=Entangle, E=Measure, R=Harvest")
	handler._select_tool(2)
	await _wait_and_display(1.5)


func _test_step_7(handler: Node) -> void:
	_print_test_header(7, "Select Plot Y Again (Position 1,0 with wheat)")
	print("Action: Select the wheat plot we planted earlier")
	handler._set_selection(Vector2i(1, 0))
	await _wait_and_display(1.5)


func _test_step_8(handler: Node) -> void:
	_print_test_header(8, "Execute E Action (Measure)")
	print("Action: Measure the quantum state of the wheat")
	print("Expected: Shows measurement result (🌾 or 👥)")
	handler._execute_tool_action("E")
	await _wait_and_display(2.0)


func _test_step_9(handler: Node) -> void:
	_print_test_header(9, "Execute R Action (Harvest)")
	print("Action: Harvest the wheat plot")
	print("Expected: Wheat added to inventory, plot becomes empty")
	handler._execute_tool_action("R")
	await _wait_and_display(2.0)


func _test_step_10(handler: Node) -> void:
	_print_test_header(10, "Switch to Tool 3 (Economy)")
	print("Action: Change tool to Economy")
	print("Expected: Action menu updates to Q=Mill, E=Market, R=Sell All")
	handler._select_tool(3)
	await _wait_and_display(1.5)


func _test_step_11(handler: Node) -> void:
	_print_test_header(11, "Execute R Action (Sell All Wheat)")
	print("Action: Sell all harvested wheat")
	print("Expected: Wheat inventory → 0, credits increase")
	handler._execute_tool_action("R")
	await _wait_and_display(2.0)
