extends Node

## Minimal boot test to find hang point

const TestBootManager = preload("res://Tests/TestBootManager.gd")

var frame = 0

func _ready():
	print("\n" + "=".repeat(70))
	print("SIMPLE BOOT TEST")
	print("=".repeat(70))

	var boot_manager = TestBootManager.new()
	boot_manager.boot_progress.connect(func(stage, msg): print("[%s] %s" % [stage, msg]))

	print("\n[TEST] Attempting boot_biomes with 1 biome (skip visualization)...")
	var result = await boot_manager.boot_biomes(self, ["CyberDebtMegacity"], true)

	if result.get("success"):
		print("\n✅ BOOT SUCCESSFUL")
		print("Biomes: %d" % result.get("biomes", {}).size())
		print("Batcher: %s" % ("ready" if result.get("batcher") else "missing"))
	else:
		print("\n❌ BOOT FAILED: %s" % result.get("error", "unknown"))

	print("\nDone! Press ESC to exit")

func _process(delta):
	frame += 1
	if frame == 1:
		print("[Frame 1] Boot in progress...")
	elif frame % 60 == 0:
		print("[Frame %d] Still booting..." % frame)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
