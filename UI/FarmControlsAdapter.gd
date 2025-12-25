## FarmControlsAdapter - Example implementation of ControlsInterface
##
## This adapter wraps an existing Farm instance and makes it compatible
## with the UI's ControlsInterface contract.
##
## USAGE FOR SIMULATION TEAM:
##   var farm = Farm.new()
##   var controls = FarmControlsAdapter.new(farm)
##   ui_controller.inject_controls(controls)
##
## ALTERNATIVELY: Make Farm inherit from ControlsInterface directly
##   class Farm extends ControlsInterface
##   # implement required methods

class_name FarmControlsAdapter
extends Node

# Signals (mirroring ControlsInterface)
signal tool_selected(tool_num: int)
signal plot_selected(position: Vector2i)
signal action_executed(action: String, position: Vector2i, success: bool)
signal wheat_changed(new_amount: int)
signal inventory_changed(resource: String, amount: int)
signal plot_state_changed(position: Vector2i)
signal plot_planted(position: Vector2i)
signal plot_harvested(position: Vector2i, yield_amount: int)
signal qubit_measured(position: Vector2i, outcome: String)
signal plots_entangled(pos1: Vector2i, pos2: Vector2i)

# Reference to the wrapped farm
var farm: Node = null

# State tracking
var current_tool: int = 1
var current_selection: Vector2i = Vector2i.ZERO


func _init(farm_instance: Node) -> void:
	"""Initialize adapter with a farm instance"""
	farm = farm_instance
	name = "FarmControlsAdapter"

	# Bridge signals immediately - farm is already set, no need to defer
	bridge_farm_signals()


## IMPLEMENT CONTROL METHODS

func select_tool(tool_num: int) -> void:
	"""Select a tool - delegates to farm"""
	current_tool = tool_num

	# Notify farm if it cares
	if farm and farm.has_method("select_tool"):
		farm.select_tool(tool_num)

	# Always emit interface signal
	tool_selected.emit(tool_num)


func select_plot(position: Vector2i) -> void:
	"""Select a plot - delegates to farm"""
	current_selection = position

	# Notify farm if it cares
	if farm and farm.has_method("select_plot"):
		farm.select_plot(position)

	# Always emit interface signal
	plot_selected.emit(position)


func trigger_action(action_key: String, position: Vector2i = Vector2i.ZERO) -> bool:
	"""Trigger an action - routes to farm methods based on action_key"""

	# Use current selection if not specified
	if position == Vector2i.ZERO:
		position = current_selection

	var success = false

	if not farm:
		action_executed.emit(action_key, position, false)
		return false

	# Route action to appropriate farm method
	match action_key:
		# Plant actions
		"plant_wheat":
			success = farm.build(position, "wheat")
		"plant_tomato":
			success = farm.build(position, "tomato")
		"plant_mushroom":
			success = farm.build(position, "mushroom")

		# Batch plant actions
		"plant_batch":
			if farm.has_method("batch_plant"):
				var result = farm.batch_plant([position], "wheat")
				success = result.get("count", 0) > 0
			else:
				success = farm.build(position, "wheat")

		# Quantum operations
		"measure_plot":
			var outcome = farm.measure_plot(position)
			success = outcome != ""

		"batch_measure":
			if farm.has_method("batch_measure"):
				var result = farm.batch_measure([position])
				success = result.get("count", 0) > 0
			else:
				var outcome = farm.measure_plot(position)
				success = outcome != ""

		"harvest_plot":
			var result = farm.harvest_plot(position)
			success = result.get("success", false)

		"batch_harvest":
			if farm.has_method("batch_harvest"):
				var result = farm.batch_harvest([position])
				success = result.get("count", 0) > 0
			else:
				var result = farm.harvest_plot(position)
				success = result.get("success", false)

		"entangle":
			# For single entanglement - would need two positions
			success = false

		"entangle_batch":
			if farm.has_method("entangle_plots"):
				# Try to entangle the selected position with an adjacent plot
				success = farm.entangle_plots(position, position + Vector2i(1, 0))
			else:
				success = false

		"break_entanglement":
			# TODO: Implement break entanglement
			success = false

		# Building actions
		"place_mill":
			success = farm.build(position, "mill")
		"place_market":
			success = farm.build(position, "market")

		# Economy actions
		"sell_all":
			if farm.has("economy") and farm.economy:
				var credits_earned = farm.economy.sell_all_wheat()
				success = credits_earned > 0

		_:
			success = false

	# Always emit interface signal
	action_executed.emit(action_key, position, success)
	return success


func move_cursor(direction: Vector2i) -> void:
	"""Move selection cursor - delegates to farm"""
	var new_pos = current_selection + direction

	# Clamp to valid grid bounds if farm has grid
	if farm and farm.has_method("get_grid_width"):
		var width = farm.get_grid_width() if farm.has_method("get_grid_width") else 6
		var height = farm.get_grid_height() if farm.has_method("get_grid_height") else 1
		new_pos.x = clampi(new_pos.x, 0, width - 1)
		new_pos.y = clampi(new_pos.y, 0, height - 1)

	select_plot(new_pos)


func quick_select_location(index: int) -> void:
	"""Quick select location (Y/U/I/O/P = locations 1-5)"""

	# Map to a position based on farm grid
	var width = 6
	var height = 1
	if farm and farm.has_method("get_grid_width"):
		width = farm.get_grid_width() if farm.has_method("get_grid_width") else 6
		height = farm.get_grid_height() if farm.has_method("get_grid_height") else 1

	# Simple row-major layout: location 1 = (0,0), 2 = (1,0), etc
	var pos = Vector2i((index - 1) % width, (index - 1) / width)
	select_plot(pos)


## IMPLEMENT QUERY METHODS

func get_current_tool() -> int:
	"""Get currently selected tool"""
	return current_tool


func get_current_selection() -> Vector2i:
	"""Get currently selected plot position"""
	return current_selection


func get_credits() -> int:
	"""Get credits from farm economy"""
	if farm and farm.has("economy") and farm.economy.has_method("get_credits"):
		return farm.economy.get_credits()
	if farm and farm.has("economy"):
		if "credits" in farm.economy:
			return farm.economy.credits
	return 0


func get_inventory(resource: String) -> int:
	"""Get inventory amount from farm"""
	if farm and farm.has("economy") and farm.economy.has_method("get_inventory"):
		return farm.economy.get_inventory(resource)
	if farm and farm.has("economy") and farm.economy.has_method("get_resource_count"):
		return farm.economy.get_resource_count(resource)
	return 0


## HELPER METHODS

func get_grid_width() -> int:
	"""Get farm grid width"""
	if farm and "grid_width" in farm:
		return farm.grid_width
	return 6


func get_grid_height() -> int:
	"""Get farm grid height"""
	if farm and "grid_height" in farm:
		return farm.grid_height
	return 1


## BRIDGE SIGNALS
## Connect farm signals to ControlsInterface signals
## so the UI can listen for updates from any implementation

func bridge_farm_signals() -> void:
	"""Bridge farm signals to ControlsInterface signals"""
	if not farm:
		return

	# Wheat currency and inventory signals from economy
	if "economy" in farm and farm.economy:
		# Bridge wheat as primary currency
		if farm.economy.has_signal("wheat_changed"):
			farm.economy.wheat_changed.connect(
				func(amount): wheat_changed.emit(amount)
			)
		if farm.economy.has_signal("labor_changed"):
			farm.economy.labor_changed.connect(
				func(amount): inventory_changed.emit("labor", amount)
			)
		if farm.economy.has_signal("flour_changed"):
			farm.economy.flour_changed.connect(
				func(amount): inventory_changed.emit("flour", amount)
			)
		if farm.economy.has_signal("mushroom_changed"):
			farm.economy.mushroom_changed.connect(
				func(amount): inventory_changed.emit("mushroom", amount)
			)

	# Plot signals
	if farm.has_signal("plot_planted"):
		farm.plot_planted.connect(
			func(pos, plant_type): plot_planted.emit(pos)
		)
	if farm.has_signal("plot_harvested"):
		farm.plot_harvested.connect(
			func(pos, yield_data): plot_harvested.emit(pos, yield_data.get("yield", 0))
		)

	# Grid signals
	if "grid" in farm and farm.grid and "plots" in farm.grid:
		for pos in farm.grid.plots.keys():
			var plot = farm.grid.plots[pos]
			if plot and plot.has_signal("state_changed"):
				plot.state_changed.connect(
					func(): plot_state_changed.emit(pos)
				)
