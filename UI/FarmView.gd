## FarmView - Simplified entry point
## Creates the farm and loads it into PlayerShell
##
## This used to be 50+ lines of orchestration.
## Now it's just: create farm, load into shell.

extends Control

const Farm = preload("res://Core/Farm.gd")
const PlayerShell = preload("res://UI/PlayerShell.gd")
const InputController = preload("res://UI/Controllers/InputController.gd")

var shell: PlayerShell = null
var farm: Node = null
var input_controller: InputController = null


func _ready() -> void:
	"""Initialize: create farm and shell, wire them together"""
	print("🌾 FarmView starting...")

	# Create farm (synchronous, no deferred)
	print("📝 Creating farm...")
	farm = Farm.new()
	add_child(farm)
	print("   ✅ Farm created and added to tree")

	# Create player shell
	print("🎪 Creating player shell...")
	shell = PlayerShell.new()
	add_child(shell)
	print("   ✅ Player shell created")

	# Load farm into shell (this creates FarmUI internally)
	shell.load_farm(farm)

	# Create input controller and wire signals
	print("🎮 Creating input controller...")
	input_controller = InputController.new()
	add_child(input_controller)

	# Wire keyboard help signal to shell
	if input_controller.has_signal("keyboard_help_requested"):
		input_controller.keyboard_help_requested.connect(shell._toggle_keyboard_help)
		print("   ✅ K key (keyboard help) connected")

	print("✅ FarmView ready - game started!")


func get_farm() -> Node:
	"""Get the current farm (for external access)"""
	return farm


func get_shell() -> Node:
	"""Get the shell (for external access)"""
	return shell
