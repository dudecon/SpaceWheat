extends SceneTree

## Quick terminal test for BaseSubmenu DRY utilities
## Run: godot --headless --script tests/test_submenu_dry.gd

const BaseSubmenu = preload("res://UI/Core/Submenus/BaseSubmenu.gd")
const GateSelectionSubmenu = preload("res://UI/Core/Submenus/GateSelectionSubmenu.gd")

var passed = 0
var failed = 0


const DIVIDER = "============================================================"

func _init():
	print("\n" + DIVIDER)
	print("SUBMENU DRY TESTS")
	print(DIVIDER)

	test_pagination()
	test_pagination_edge_cases()
	test_build_actions()
	test_cost_formatting()
	test_affordability()
	test_gate_selection_submenu()
	test_gate_selection_empty()
	test_sorting()

	print("\n" + DIVIDER)
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	print(DIVIDER + "\n")

	quit(0 if failed == 0 else 1)


func assert_eq(actual, expected, msg: String):
	if actual == expected:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)
		print("    Expected: %s" % str(expected))
		print("    Actual:   %s" % str(actual))


func assert_true(condition: bool, msg: String):
	if condition:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)


func test_pagination():
	print("\n[Pagination]")

	var options = ["a", "b", "c", "d", "e", "f", "g"]

	# Page 0
	var p0 = BaseSubmenu.paginate(options, 0)
	assert_eq(p0.page, 0, "Page 0: page index")
	assert_eq(p0.max_pages, 3, "Page 0: max_pages (7 items / 3 per page = 3)")
	assert_eq(p0.total_options, 7, "Page 0: total_options")
	assert_eq(p0.page_options.size(), 3, "Page 0: 3 options")
	assert_eq(p0.page_options, ["a", "b", "c"], "Page 0: correct slice")

	# Page 1
	var p1 = BaseSubmenu.paginate(options, 1)
	assert_eq(p1.page, 1, "Page 1: page index")
	assert_eq(p1.page_options, ["d", "e", "f"], "Page 1: correct slice")

	# Page 2 (partial)
	var p2 = BaseSubmenu.paginate(options, 2)
	assert_eq(p2.page, 2, "Page 2: page index")
	assert_eq(p2.page_options, ["g"], "Page 2: partial page (1 item)")

	# Page wrap
	var p3 = BaseSubmenu.paginate(options, 3)
	assert_eq(p3.page, 0, "Page 3 wraps to 0")


func test_pagination_edge_cases():
	print("\n[Pagination Edge Cases]")

	# Empty
	var empty = BaseSubmenu.paginate([], 0)
	assert_eq(empty.page, 0, "Empty: page 0")
	assert_eq(empty.max_pages, 1, "Empty: max_pages 1")
	assert_eq(empty.page_options.size(), 0, "Empty: no options")

	# Single item
	var single = BaseSubmenu.paginate(["x"], 0)
	assert_eq(single.page_options, ["x"], "Single: one item")
	assert_eq(single.max_pages, 1, "Single: 1 page")

	# Exactly 3 items (one full page)
	var exact = BaseSubmenu.paginate(["a", "b", "c"], 0)
	assert_eq(exact.max_pages, 1, "Exact 3: 1 page")
	assert_eq(exact.page_options.size(), 3, "Exact 3: 3 options")


func test_build_actions():
	print("\n[Build Actions]")

	var options = [
		{"action": "foo", "label": "Foo"},
		{"action": "bar", "label": "Bar"},
		{"action": "baz", "label": "Baz"}
	]

	var actions = BaseSubmenu.build_actions(options)

	assert_true(actions.has("Q"), "Has Q action")
	assert_true(actions.has("E"), "Has E action")
	assert_true(actions.has("R"), "Has R action")
	assert_eq(actions["Q"]["action"], "foo", "Q maps to first option")
	assert_eq(actions["E"]["action"], "bar", "E maps to second option")
	assert_eq(actions["R"]["action"], "baz", "R maps to third option")

	# Partial (2 options)
	var partial = BaseSubmenu.build_actions([{"action": "a", "label": "A"}, {"action": "b", "label": "B"}])
	assert_true(partial.has("Q"), "Partial: has Q")
	assert_true(partial.has("E"), "Partial: has E")
	assert_true(not partial.has("R"), "Partial: no R")


func test_cost_formatting():
	print("\n[Cost Formatting]")

	assert_eq(BaseSubmenu.format_cost({}), "", "Empty cost")
	assert_eq(BaseSubmenu.format_cost({"🍼": 1}), "🍼", "Single item, qty 1")
	assert_eq(BaseSubmenu.format_cost({"🍼": 3}), "🍼×3", "Single item, qty 3")

	var multi = BaseSubmenu.format_cost({"🍼": 2, "🌾": 5})
	assert_true(multi.contains("🍼×2"), "Multi: has milk")
	assert_true(multi.contains("🌾×5"), "Multi: has wheat")


func test_affordability():
	print("\n[Affordability]")

	# Mock economy
	var mock_economy = MockEconomy.new()
	mock_economy.balances = {"energy": 10, "milk": 2}

	assert_true(BaseSubmenu.check_affordability({}, mock_economy), "Empty cost: affordable")
	assert_true(BaseSubmenu.check_affordability({"energy": 5}, mock_economy), "Under budget: affordable")
	assert_true(BaseSubmenu.check_affordability({"energy": 10}, mock_economy), "Exact budget: affordable")
	assert_true(not BaseSubmenu.check_affordability({"energy": 15}, mock_economy), "Over budget: not affordable")
	assert_true(not BaseSubmenu.check_affordability({"gold": 1}, mock_economy), "Missing resource: not affordable")

	# Apply to options
	var options = [
		{"label": "Cheap", "cost": {"energy": 1}},
		{"label": "Expensive", "cost": {"energy": 100}}
	]
	BaseSubmenu.apply_cost_to_options(options, mock_economy)
	assert_true(options[0]["can_afford"], "Cheap: can afford")
	assert_true(not options[1]["can_afford"], "Expensive: cannot afford")
	assert_true(not options[1]["enabled"], "Expensive: disabled")


func test_gate_selection_submenu():
	print("\n[GateSelectionSubmenu]")

	# 2 qubits selected
	var selection_2 = [Vector2i(0, 0), Vector2i(1, 0)]
	var submenu_2 = GateSelectionSubmenu.generate_submenu(null, null, selection_2, 0)

	assert_eq(submenu_2["name"], "gate_selection", "Name correct")
	assert_eq(submenu_2["selection_count"], 2, "Selection count: 2")
	assert_true(submenu_2["actions"].has("Q"), "Has Q action")
	assert_eq(submenu_2["actions"]["Q"]["action"], "build_gate", "Q action is build_gate")
	assert_true(submenu_2["actions"]["Q"].has("gate_type"), "Q has gate_type")

	# 3 qubits selected - should have GHZ/Cluster options
	var selection_3 = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var submenu_3 = GateSelectionSubmenu.generate_submenu(null, null, selection_3, 0)
	assert_eq(submenu_3["selection_count"], 3, "Selection count: 3")
	assert_true(submenu_3["total_options"] > 4, "3 qubits: more than 4 options (includes GHZ, Cluster)")


func test_gate_selection_empty():
	print("\n[GateSelectionSubmenu Empty State]")

	# 0 qubits
	var empty = GateSelectionSubmenu.generate_submenu(null, null, [], 0)
	assert_true(empty.get("_disabled", false), "0 qubits: disabled")

	# 1 qubit
	var single = GateSelectionSubmenu.generate_submenu(null, null, [Vector2i(0, 0)], 0)
	assert_true(single.get("_disabled", false), "1 qubit: disabled")
	assert_eq(single["actions"]["Q"]["label"], "Select 2+ qubits", "1 qubit: shows message")


func test_sorting():
	print("\n[Sorting Utilities]")

	var options = [
		{"name": "c", "priority": 1},
		{"name": "a", "priority": 3},
		{"name": "b", "priority": 2}
	]

	# Sort descending
	var sorted_desc = BaseSubmenu.sort_by_field(options.duplicate(true), "priority", true)
	assert_eq(sorted_desc[0]["name"], "a", "Desc: highest first")
	assert_eq(sorted_desc[2]["name"], "c", "Desc: lowest last")

	# Sort ascending
	var sorted_asc = BaseSubmenu.sort_by_field(options.duplicate(true), "priority", false)
	assert_eq(sorted_asc[0]["name"], "c", "Asc: lowest first")

	# Sort enabled first
	var mixed = [
		{"name": "disabled1", "enabled": false},
		{"name": "enabled1", "enabled": true},
		{"name": "disabled2", "enabled": false},
		{"name": "enabled2", "enabled": true}
	]
	var sorted_enabled = BaseSubmenu.sort_enabled_first(mixed)
	assert_eq(sorted_enabled[0]["name"], "enabled1", "Enabled first: slot 0")
	assert_eq(sorted_enabled[1]["name"], "enabled2", "Enabled first: slot 1")
	assert_eq(sorted_enabled[2]["name"], "disabled1", "Enabled first: disabled after")


class MockEconomy:
	extends RefCounted
	var balances: Dictionary = {}

	func get_balance(resource: String) -> int:
		return balances.get(resource, 0)
