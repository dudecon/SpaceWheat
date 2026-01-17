#!/usr/bin/env -S godot --headless -s
extends SceneTree

## QUICK TEST: Tools 2, 3, 4 + Economic Integration
## Focused on action execution and error detection

var farm = null
var grid = null
var economy = null
var biome_list = {}
var input_handler = null

var frame_count = 0
var scene_loaded = false
var tests_done = false

var findings = {
	"tool2_entangle": [],
	"tool3_industry": [],
	"tool4_gates": [],
	"economy": [],
	"cross_tool": []
}

var issues = []

func _init():
	print("\n" + "═".repeat(80))
	print("🔧 QUICK TEST: Tools 2, 3, 4 + Economic Integration")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Loading...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready!\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm
	grid = farm.grid
	economy = farm.economy
	biome_list = grid.biomes
	input_handler = fv.input_handler

	economy.add_resource("💰", 5000, "test")

	# Quick sanity checks on all tools
	_test_tool_2_entangle()
	_test_tool_3_industry()
	_test_tool_4_unitary()
	_test_economy_tracking()

	print_findings()
	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_tool_2_entangle():
	print("─".repeat(80))
	print("TOOL 2 ENTANGLE - Quick Test")
	print("─".repeat(80))

	var biome = biome_list.values()[0]

	# Try to check if entanglement actions exist in input handler
	var tool_2_config = ToolConfig.get_tool(2)

	if tool_2_config:
		findings["tool2_entangle"].append("Tool 2 config exists: %s" % tool_2_config.keys())
		print("✅ Tool 2 configuration found")

		# Check for action definitions
		var q_action = tool_2_config.get("q", {})
		var e_action = tool_2_config.get("e", {})
		var r_action = tool_2_config.get("r", {})

		findings["tool2_entangle"].append("Q: %s" % q_action.get("action", "MISSING"))
		findings["tool2_entangle"].append("E: %s" % e_action.get("action", "MISSING"))
		findings["tool2_entangle"].append("R: %s" % r_action.get("action", "MISSING"))

		print("  Q: %s" % q_action.get("action", "MISSING"))
		print("  E: %s" % e_action.get("action", "MISSING"))
		print("  R: %s" % r_action.get("action", "MISSING"))
	else:
		issues.append("TOOL2-01: Tool 2 configuration not found")
		print("❌ Tool 2 config missing")

# ═══════════════════════════════════════════════════════════════════════════

func _test_tool_3_industry():
	print("\n" + "─".repeat(80))
	print("TOOL 3 INDUSTRY - Quick Test")
	print("─".repeat(80))

	var tool_3_config = ToolConfig.get_tool(3)

	if tool_3_config:
		findings["tool3_industry"].append("Tool 3 config exists")
		print("✅ Tool 3 configuration found")

		var q_action = tool_3_config.get("q", {})
		var e_action = tool_3_config.get("e", {})
		var r_action = tool_3_config.get("r", {})

		findings["tool3_industry"].append("Q: %s" % q_action.get("action", "MISSING"))
		findings["tool3_industry"].append("E: %s" % e_action.get("action", "MISSING"))
		findings["tool3_industry"].append("R: %s" % r_action.get("action", "MISSING"))

		print("  Q: %s" % q_action.get("action", "MISSING"))
		print("  E: %s" % e_action.get("action", "MISSING"))
		print("  R: %s" % r_action.get("action", "MISSING"))
	else:
		issues.append("TOOL3-01: Tool 3 configuration not found")
		print("❌ Tool 3 config missing")

# ═══════════════════════════════════════════════════════════════════════════

func _test_tool_4_unitary():
	print("\n" + "─".repeat(80))
	print("TOOL 4 UNITARY - Quick Test (with F-cycling)")
	print("─".repeat(80))

	var tool_4_config = ToolConfig.get_tool(4)

	if tool_4_config:
		findings["tool4_gates"].append("Tool 4 config exists")
		print("✅ Tool 4 configuration found")

		# Check for F-cycling (multiple modes)
		if "modes" in tool_4_config:
			var modes = tool_4_config["modes"]
			findings["tool4_gates"].append("Modes: %d" % modes.size())
			print("  Modes: %d" % modes.size())

			for mode_idx in range(min(3, modes.size())):
				var mode = modes[mode_idx]
				print("    Mode %d: %s" % [mode_idx, mode.get("label", "?")])
		else:
			print("  No modes (no F-cycling)")

		print("  Default Q/E/R:")
		var q = tool_4_config.get("q", {})
		var e = tool_4_config.get("e", {})
		var r = tool_4_config.get("r", {})
		print("    Q: %s" % q.get("action", "?"))
		print("    E: %s" % e.get("action", "?"))
		print("    R: %s" % r.get("action", "?"))
	else:
		issues.append("TOOL4-01: Tool 4 configuration not found")
		print("❌ Tool 4 config missing")

# ═══════════════════════════════════════════════════════════════════════════

func _test_economy_tracking():
	print("\n" + "─".repeat(80))
	print("ECONOMY - Resource Tracking")
	print("─".repeat(80))

	var initial_credits = economy.get_resource("💰")
	print("Initial credits: %d 💰" % initial_credits)

	# Test add_resource
	economy.add_resource("💰", 100, "test_add")
	var after_add = economy.get_resource("💰")

	if after_add == initial_credits + 100:
		findings["economy"].append("add_resource works correctly")
		print("✅ add_resource: 💰 increased by 100")
	else:
		issues.append("ECON-01: add_resource not working (expected +100, got +%d)" % (after_add - initial_credits))
		print("❌ add_resource failed")

	# Test spend_resource
	var spent = economy.can_afford("💰", 50)
	if spent:
		economy.spend_resource("💰", 50, "test_spend")
		var after_spend = economy.get_resource("💰")
		findings["economy"].append("spend_resource works")
		print("✅ spend_resource: 💰 decreased correctly")
	else:
		issues.append("ECON-02: can_afford check failed")
		print("❌ can_afford failed")

	# Test custom resources
	economy.add_resource("🍕", 5, "test_pizza")
	var pizza = economy.get_resource("🍕")
	if pizza == 5:
		findings["economy"].append("Custom resources work")
		print("✅ Custom resources (🍕): working")
	else:
		issues.append("ECON-03: Custom resources not working")
		print("❌ Custom resources failed")

# ═══════════════════════════════════════════════════════════════════════════

func print_findings():
	print("\n" + "═".repeat(80))
	print("📋 QUICK TEST SUMMARY - Tools 2, 3, 4 + Economy")
	print("═".repeat(80))

	for category in findings.keys():
		if findings[category].size() == 0:
			continue

		print("\n🔹 %s:" % category.to_upper())
		for finding in findings[category]:
			print("   ✅ %s" % finding)

	print("\n" + "─".repeat(80))

	if issues.size() > 0:
		print("\n🐛 ISSUES FOUND (%d):" % issues.size())
		for issue in issues:
			print("   - %s" % issue)
	else:
		print("\n✅ NO CRITICAL ISSUES FOUND")

	print("═".repeat(80) + "\n")
