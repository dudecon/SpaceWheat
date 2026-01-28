class_name BiomeEvolutionBatcher
extends RefCounted

## BiomeEvolutionBatcher - Rotational batch evolution for all biomes
##
## Stage 1 Implementation: Rotate which biomes evolve each frame
## Spreads quantum evolution across multiple frames for smooth performance
##
## Performance Optimization: Skip evolution for biomes with no bound terminals
## ("Out of sight, out of mind" - don't evolve unpopulated biomes)

# Configuration
const BIOMES_PER_FRAME = 2  # Evolve 2 biomes per frame
const EVOLUTION_INTERVAL = 0.1  # 10Hz effective rate

# State
var biomes: Array = []  # All registered biomes
var current_index: int = 0
var evolution_accumulator: float = 0.0

# PlotPool reference for bound terminal checks
var plot_pool = null

# Statistics
var total_evolutions: int = 0
var skipped_evolutions: int = 0  # Biomes skipped due to no bound terminals
var last_batch_time_ms: float = 0.0

func initialize(biome_array: Array, p_plot_pool = null):
	"""Initialize batcher with all farm biomes.

	Args:
		biome_array: Array of BiomeBase instances
		p_plot_pool: Optional PlotPool for bound terminal optimization
	"""
	plot_pool = p_plot_pool

	# Filter valid biomes (not null, has quantum computer)
	biomes = biome_array.filter(func(b):
		return b != null and b.quantum_computer != null
	)

	print("BiomeEvolutionBatcher: Registered %d biomes for batch evolution" % biomes.size())
	print("  Configuration: %d biomes/frame at %.1fHz effective rate" % [
		BIOMES_PER_FRAME, 1.0 / EVOLUTION_INTERVAL
	])
	if plot_pool:
		print("  Optimization: Skip evolution for biomes with no bound terminals")

func physics_process(delta: float):
	"""Called at fixed 20Hz by physics loop (from Farm._physics_process()).

	Rotates through biomes, evolving BIOMES_PER_FRAME each evolution tick.
	Completely decoupled from visual framerate for smooth 60 FPS visuals.
	"""
	if biomes.is_empty():
		return

	evolution_accumulator += delta

	# Check if it's time to evolve
	if evolution_accumulator >= EVOLUTION_INTERVAL:
		var actual_dt = evolution_accumulator
		evolution_accumulator = 0.0

		# Evolve current batch
		_evolve_batch(actual_dt)

		# Rotate to next batch
		current_index = (current_index + BIOMES_PER_FRAME) % biomes.size()

func _evolve_batch(dt: float):
	"""Evolve a batch of biomes (Stage 1: sequential, future: batched C++ call).

	Args:
		dt: Time step (accumulated since last evolution tick)
	"""
	var batch_start = Time.get_ticks_usec()
	var evolved_count = 0
	var skipped_count = 0

	# Evolve up to BIOMES_PER_FRAME biomes starting at current_index
	for i in range(BIOMES_PER_FRAME):
		var idx = (current_index + i) % biomes.size()
		var biome = biomes[idx]

		if biome and biome.quantum_computer:
			# Update time tracker (for UI and drift mechanics) - always update
			biome.time_tracker.update(dt)

			# OPTIMIZATION: Skip evolution for biomes with no bound terminals
			# "Out of sight, out of mind" - don't waste CPU on unpopulated biomes
			if plot_pool and not _biome_has_bound_terminals(biome):
				skipped_count += 1
				continue

			# Evolve quantum state
			if biome.quantum_evolution_enabled and not biome.evolution_paused:
				biome.quantum_computer.evolve(dt)
				evolved_count += 1

				# Apply biome-specific post-evolution updates
				_post_evolution_update(biome)

	var batch_end = Time.get_ticks_usec()
	last_batch_time_ms = (batch_end - batch_start) / 1000.0
	total_evolutions += evolved_count
	skipped_evolutions += skipped_count

	# Optional: Log for debugging
	if true: # VerboseConfig and VerboseConfig.is_verbose("quantum"):
		var skip_info = " (skipped %d)" % skipped_count if skipped_count > 0 else ""
		if total_evolutions % 60 == 0:
			print("BiomeEvolutionBatcher: Evolved %d biomes in %.2fms%s" % [
				evolved_count, last_batch_time_ms, skip_info
			])


func _biome_has_bound_terminals(biome) -> bool:
	"""Check if a biome has any bound terminals (planted plots).

	Args:
		biome: BiomeBase instance to check

	Returns:
		true if biome has at least one bound terminal
	"""
	if not plot_pool:
		return true  # No pool = assume populated (conservative)

	if plot_pool.has_method("get_terminals_in_biome"):
		return plot_pool.get_terminals_in_biome(biome).size() > 0

	return true  # Method not available = assume populated

func _post_evolution_update(biome):
	"""Apply biome-specific post-evolution updates.

	Handles things like:
	- Semantic drift application
	- Attractor snapshot recording
	- Colony/eruption state tracking
	"""
	# Call biome's semantic drift (if it has one)
	if biome.has_method("_apply_semantic_drift"):
		biome._apply_semantic_drift(EVOLUTION_INTERVAL)

	# Record attractor snapshot (for semantic topology)
	if biome.has_method("_record_attractor_snapshot"):
		biome._record_attractor_snapshot()

	# Dynamics tracking
	if biome.dynamics_tracker and biome.has_method("_track_dynamics"):
		biome._track_dynamics()

	# Biome-specific state tracking
	match biome.get_biome_type():
		"FungalNetworks":
			if biome.has_method("_update_colony_dominance"):
				biome._update_colony_dominance()
		"VolcanicWorlds":
			if biome.has_method("_update_eruption_state"):
				biome._update_eruption_state()

func get_stats() -> Dictionary:
	"""Get performance statistics for monitoring."""
	return {
		"biomes": biomes.size(),
		"biomes_per_frame": BIOMES_PER_FRAME,
		"evolution_interval": EVOLUTION_INTERVAL,
		"current_batch_index": current_index,
		"total_evolutions": total_evolutions,
		"skipped_evolutions": skipped_evolutions,
		"last_batch_time_ms": last_batch_time_ms
	}
