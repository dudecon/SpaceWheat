class_name FarmBuilder

## Factory for creating a fully-initialized Farm synchronously
## This is the first step in the "Ready Means Ready" refactoring
##
## Purpose: Remove async/deferred initialization from FarmView
## Instead of creating Farm in call_deferred(), we create it here synchronously
## ensuring all dependencies are ready before any UI component tries to use them

const Farm = preload("res://Core/Farm.gd")


static func create_default_farm() -> Farm:
	"""Create a fully-initialized Farm with all systems ready

	This is purely synchronous - no await, no call_deferred()
	The Farm's grid, biomes, and economy are all ready when this returns
	"""
	var farm = Farm.new()

	# Farm._init() already runs synchronously when .new() is called
	# Farm._ready() will run when we add it to the scene tree
	# But all the actual data setup happens in Farm._init()

	print("✅ Farm created (ready for UI wiring)")
	return farm


static func create_farm_with_custom_grid(grid_width: int = 6, grid_height: int = 2) -> Farm:
	"""Create a Farm with custom grid dimensions"""
	var farm = Farm.new()
	# TODO: Add parameter passing if needed in future
	return farm
