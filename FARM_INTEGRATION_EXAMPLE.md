# Farm.gd Integration Example for BiomeEvolutionBatcher
# This shows how to modify Farm.gd to use batched evolution

# ==============================================================================
# STEP 1: Add batcher variable
# ==============================================================================

# Add near the top of Farm.gd with other system variables:
const BiomeEvolutionBatcherClass = preload("res://Core/Environment/BiomeEvolutionBatcher.gd")
var biome_evolution_batcher: BiomeEvolutionBatcherClass = null

# ==============================================================================
# STEP 2: Initialize batcher in _ready()
# ==============================================================================

# Add after all biomes are loaded and initialized (around line 240):
func _ready():
	# ... existing biome loading code ...

	# After all biomes are loaded:
	# Initialize biome evolution batcher (Stage 1: rotation)
	biome_evolution_batcher = BiomeEvolutionBatcherClass.new()
	biome_evolution_batcher.initialize([
		biotic_flux_biome,
		stellar_forges_biome,
		fungal_networks_biome,
		volcanic_worlds_biome,
		starter_forest_biome,
		village_biome
	])

	# Disable individual biome processing (batcher takes over)
	_disable_individual_biome_processing()

	# ... rest of _ready() ...

func _disable_individual_biome_processing():
	"""Disable individual biome _process() to prevent double evolution."""
	var biomes_to_disable = [
		biotic_flux_biome,
		stellar_forges_biome,
		fungal_networks_biome,
		volcanic_worlds_biome,
		starter_forest_biome,
		village_biome
	]

	for biome in biomes_to_disable:
		if biome:
			# Set a flag that biomes check before evolving
			biome.set_meta("batched_evolution", true)

# ==============================================================================
# STEP 3: Call batcher in _process()
# ==============================================================================

# Modify _process() to use batcher:
func _process(delta: float):
	"""Handle passive effects like mushroom composting and grid processing"""

	# BATCHED QUANTUM EVOLUTION (replaces individual biome evolution)
	if biome_evolution_batcher:
		biome_evolution_batcher.process(delta)

	# Process grid (mills, markets, kitchens, etc.)
	if grid:
		grid._process(delta)

# ==============================================================================
# STEP 4: Modify BiomeBase._process() to check for batched mode
# ==============================================================================

# In Core/Environment/BiomeBase.gd, modify _process():

func _process(dt: float) -> void:
	# Check if batched evolution is enabled
	if has_meta("batched_evolution") and get_meta("batched_evolution"):
		# Batcher handles quantum evolution
		# We only need to update non-quantum systems here
		return

	# Original behavior (for biomes not using batcher)
	advance_simulation(dt)

# ==============================================================================
# OPTIONAL: Add performance monitoring
# ==============================================================================

# Add to Farm.gd for debugging:
func _on_debug_key_pressed():
	if biome_evolution_batcher:
		var stats = biome_evolution_batcher.get_stats()
		print("Biome Evolution Batcher Stats:")
		print("  Total evolutions: %d" % stats.total_evolutions)
		print("  Last batch: %.2fms" % stats.last_batch_time_ms)
		print("  Current batch: %d/%d" % [
			stats.current_batch_index,
			stats.biomes
		])

# ==============================================================================
# TESTING: Verify smooth frame times
# ==============================================================================

# Run the performance benchmark to compare:
# Before: Spiky (0, 0, 0, 38ms, 0, 0) every 6 frames
# After:  Smooth (8ms, 8ms, 8ms) every frame

# Command:
# godot --headless --script res://Tests/PerformanceBenchmark.gd

# Expected results:
# - P95 frame time: Lower variance
# - Frame time distribution: Much smoother (no big spikes)
# - Average frame time: Similar or slightly better
