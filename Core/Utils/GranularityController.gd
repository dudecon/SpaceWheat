extends RefCounted
class_name GranularityController

## Shared granularity control logic for quantum evolution substep size
## Used by: QuantumInstrumentInput, VisualBubbleTest, and any other tools

## Adjust granularity by halving/doubling the substep size
## - Smaller dt = finer granularity = more accurate but slower
## - Larger dt = coarser granularity = faster but less accurate

const MIN_DT: float = 0.0001  # 0.1ms - ultra fine
const MAX_DT: float = 1.0     # 1000ms - ultra coarse

static func decrease_granularity(biomes: Array) -> Dictionary:
	"""Make substeps finer (more accurate, slower) - triggered by `-` key.

	Returns: {current_dt: float, new_dt: float, biome_count: int}
	"""
	if biomes.is_empty():
		return {current_dt = 0.02, new_dt = 0.02, biome_count = 0}

	# Get current granularity from first biome
	var current_dt = 0.02
	var first_biome = biomes[0]
	if "max_evolution_dt" in first_biome:
		current_dt = first_biome.max_evolution_dt

	# Halve the substep size = finer granularity
	var new_dt = max(current_dt * 0.5, MIN_DT)

	# Apply to all biomes
	var biome_count = 0
	for biome in biomes:
		if "max_evolution_dt" in biome:
			biome.max_evolution_dt = new_dt
			biome_count += 1

	return {
		"current_dt": current_dt,
		"new_dt": new_dt,
		"biome_count": biome_count
	}


static func increase_granularity(biomes: Array) -> Dictionary:
	"""Make substeps coarser (faster, less accurate) - triggered by `=` key.

	Returns: {current_dt: float, new_dt: float, biome_count: int}
	"""
	if biomes.is_empty():
		return {current_dt = 0.02, new_dt = 0.02, biome_count = 0}

	# Get current granularity from first biome
	var current_dt = 0.02
	var first_biome = biomes[0]
	if "max_evolution_dt" in first_biome:
		current_dt = first_biome.max_evolution_dt

	# Double the substep size = coarser granularity
	var new_dt = min(current_dt * 2.0, MAX_DT)

	# Apply to all biomes
	var biome_count = 0
	for biome in biomes:
		if "max_evolution_dt" in biome:
			biome.max_evolution_dt = new_dt
			biome_count += 1

	return {
		"current_dt": current_dt,
		"new_dt": new_dt,
		"biome_count": biome_count
	}


static func get_current_granularity(biomes: Array) -> float:
	"""Get current max_evolution_dt from first biome."""
	if biomes.is_empty():
		return 0.02

	var first_biome = biomes[0]
	if "max_evolution_dt" in first_biome:
		return first_biome.max_evolution_dt

	return 0.02
