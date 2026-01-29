class_name BiomeQuantumSystemBuilder
extends RefCounted

## Quantum System Builder Component
##
## Extracted from BiomeBase to handle:
## - expand_quantum_system() - Add qubit axis, rebuild operators
## - inject_coupling() - Add Hamiltonian coupling
## - build_operators_cached() - Build H and L with caching

const CacheKey = preload("res://Core/QuantumSubstrate/CacheKey.gd")
const OperatorCache = preload("res://Core/QuantumSubstrate/OperatorCache.gd")

# Signals
signal coupling_updated(emoji_a: String, emoji_b: String, strength: float)

# Injected dependencies
var quantum_computer = null
var resource_registry = null  # BiomeResourceRegistry
var _icon_registry = null  # IconRegistry autoload


func set_dependencies(qc, res_registry, icon_reg) -> void:
	"""Set all required dependencies"""
	quantum_computer = qc
	resource_registry = res_registry
	_icon_registry = icon_reg


func get_biome_type() -> String:
	"""Get biome type name from quantum_computer"""
	if quantum_computer:
		return quantum_computer.biome_name
	return "Unknown"


# ============================================================================
# Quantum System Expansion (BUILD Mode)
# ============================================================================

func expand_quantum_system(north_emoji: String, south_emoji: String) -> Dictionary:
	"""Expand the biome's quantum computer to include a new emoji axis.

	Adds a new qubit axis to the quantum system, rebuilds Hamiltonian and
	Lindblad operators with coupling terms from the faction/icon system.

	Rejects if EITHER emoji is already in the biome (prevents axis conflicts).

	Args:
		north_emoji: North pole emoji (|0> basis state)
		south_emoji: South pole emoji (|1> basis state)

	Returns:
		Dictionary with:
		- success: bool
		- error: String (if failure)
		- qubit_index: int (new qubit index if success)
		- old_dim: int (dimension before expansion)
		- new_dim: int (dimension after expansion)
	"""
	# 1. Check if quantum_computer exists
	if not quantum_computer:
		return {
			"success": false,
			"error": "no_quantum_computer",
			"message": "Biome has no quantum computer to expand"
		}

	# 2. Reject if EITHER emoji already exists (prevents axis conflicts)
	if quantum_computer.register_map.has(north_emoji):
		return {
			"success": false,
			"error": "emoji_conflict",
			"message": "Emoji %s already exists in this biome" % north_emoji
		}
	if quantum_computer.register_map.has(south_emoji):
		return {
			"success": false,
			"error": "emoji_conflict",
			"message": "Emoji %s already exists in this biome" % south_emoji
		}

	# 4. Get IconRegistry for coupling terms
	if not _icon_registry:
		push_warning("expand_quantum_system: IconRegistry not available - using default couplings")

	# 5. Record old dimension
	var old_dim = quantum_computer.register_map.dim()
	var old_num_qubits = quantum_computer.register_map.num_qubits

	# 6. Add new axis to quantum computer
	var new_qubit_index = old_num_qubits
	quantum_computer.allocate_axis(new_qubit_index, north_emoji, south_emoji)

	# 7. Update resource_registry emoji pairings
	if resource_registry:
		resource_registry.add_emoji_pair_to_producible(north_emoji, south_emoji)

	# 8. Gather ALL icons for this biome (existing + new)
	var all_icons = {}
	if _icon_registry:
		# Get icons for all emojis in the quantum system
		for emoji in quantum_computer.register_map.coordinates.keys():
			var icon = _icon_registry.get_icon(emoji)
			if icon:
				all_icons[emoji] = icon

	# 9. Rebuild Hamiltonian and Lindblad operators with new coupling terms
	var HamBuilder = load("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
	var LindBuilder = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")
	var verbose = Engine.get_singleton("VerboseConfig") if Engine.has_singleton("VerboseConfig") else null

	quantum_computer.hamiltonian = HamBuilder.build(all_icons, quantum_computer.register_map, verbose)
	var lindblad_result = LindBuilder.build(all_icons, quantum_computer.register_map, verbose)
	quantum_computer.lindblad_operators = lindblad_result.get("operators", [])
	quantum_computer.gated_lindblad_configs = lindblad_result.get("gated_configs", [])

	# 9b. Extract and set time-dependent driver configurations
	var driven_configs = HamBuilder.get_driven_icons(all_icons, quantum_computer.register_map)
	quantum_computer.set_driven_icons(driven_configs)

	var new_dim = quantum_computer.register_map.dim()

	print("🔬 Expanded %s quantum system: %d -> %d qubits (%dD -> %dD)" % [
		get_biome_type(), old_num_qubits, new_qubit_index + 1, old_dim, new_dim])
	print("   New axis: %s <-> %s (qubit %d)" % [north_emoji, south_emoji, new_qubit_index])

	return {
		"success": true,
		"qubit_index": new_qubit_index,
		"old_dim": old_dim,
		"new_dim": new_dim,
		"north_emoji": north_emoji,
		"south_emoji": south_emoji
	}


func inject_coupling(emoji_a: String, emoji_b: String, strength: float) -> Dictionary:
	"""Inject a Hamiltonian coupling between two existing axes.

	Unlike expand_quantum_system(), this does NOT add new qubits.
	It modifies the Hamiltonian to create ZZ dynamics between existing axes.

	Args:
		emoji_a: First emoji (must exist in register_map)
		emoji_b: Second emoji (must exist in register_map)
		strength: Coupling strength J (ZZ interaction term)

	Returns:
		Dictionary with success/error keys
	"""
	if not quantum_computer:
		return {"success": false, "error": "no_quantum_computer"}

	var rm = quantum_computer.register_map
	if not rm.has(emoji_a):
		return {"success": false, "error": "missing_emoji", "emoji": emoji_a}
	if not rm.has(emoji_b):
		return {"success": false, "error": "missing_emoji", "emoji": emoji_b}

	# Get qubit indices for the emojis
	var qubit_a = rm.qubit(emoji_a)
	var qubit_b = rm.qubit(emoji_b)

	if qubit_a == -1 or qubit_b == -1:
		return {"success": false, "error": "qubit_lookup_failed"}

	# Add coupling to Hamiltonian via QuantumComputer
	var result = quantum_computer.add_coupling(qubit_a, qubit_b, strength)

	if result.success:
		coupling_updated.emit(emoji_a, emoji_b, strength)
		print("🔗 Injected coupling: %s <-> %s (J=%.3f)" % [emoji_a, emoji_b, strength])

	return result


# ============================================================================
# Operator Building with Caching
# ============================================================================

func build_operators_cached(biome_name: String, icons: Dictionary) -> void:
	"""Build quantum operators with caching.

	Call this after quantum_computer and register_map are initialized.

	Args:
		biome_name: Name of the biome (e.g. "BioticFluxBiome")
		icons: Dictionary of emoji -> Icon used by this biome

	First boot: Builds operators and caches them (~8s per biome)
	Subsequent boots: Loads from cache (~0.01s per biome)
	"""
	if not quantum_computer:
		push_error("build_operators_cached: quantum_computer not set")
		return

	# Generate cache key from Icon configs
	var cache_key = CacheKey.for_biome(biome_name, _icon_registry)

	# Safe VerboseConfig access
	var verbose = null
	if Engine.has_singleton("VerboseConfig"):
		verbose = Engine.get_singleton("VerboseConfig")
	else:
		# Try node path
		var root = Engine.get_main_loop()
		if root and root.has_method("get_root"):
			var scene_root = root.get_root()
			if scene_root:
				verbose = scene_root.get_node_or_null("/root/VerboseConfig")

	if verbose:
		verbose.info("cache", "🔑", "%s cache key: %s" % [biome_name, cache_key])

	# Try to load from cache (user cache first, then bundled cache)
	var cache = OperatorCache.get_instance()
	var bundled_hit_before = cache.bundled_hit_count
	var cached_ops = cache.try_load(biome_name, cache_key)

	if not cached_ops.is_empty():
		# Cache HIT - use cached operators
		quantum_computer.hamiltonian = cached_ops.hamiltonian
		quantum_computer.lindblad_operators = cached_ops.lindblad_operators

		# Set up time-dependent drivers (not cached - must always be extracted from icons)
		var HamBuilder = load("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
		var driven_configs = HamBuilder.get_driven_icons(icons, quantum_computer.register_map)
		quantum_computer.set_driven_icons(driven_configs)


		if verbose:
			var h_dim = quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
			var l_count = quantum_computer.lindblad_operators.size()
			var from_bundled = cache.bundled_hit_count > bundled_hit_before
			var cache_source = "[BUNDLED]" if from_bundled else "[USER CACHE]"
			verbose.info("cache", "✅", "Cache HIT: Loaded H (%dx%d) + %d Lindblad operators %s" % [h_dim, h_dim, l_count, cache_source])
	else:
		# Cache MISS - build operators
		if verbose:
			verbose.info("cache", "🔨", "Cache MISS: Building operators from scratch...")
		var start_time = Time.get_ticks_msec()

		# Build using HamiltonianBuilder and LindbladBuilder
		var HamBuilder = load("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
		var LindBuilder = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")

		# Pass verbose logger to builders for detailed logging
		quantum_computer.hamiltonian = HamBuilder.build(icons, quantum_computer.register_map, verbose)

		var lindblad_result = LindBuilder.build(icons, quantum_computer.register_map, verbose)
		quantum_computer.lindblad_operators = lindblad_result.get("operators", [])
		quantum_computer.gated_lindblad_configs = lindblad_result.get("gated_configs", [])

		# Set up time-dependent drivers for oscillating self-energies
		var driven_configs = HamBuilder.get_driven_icons(icons, quantum_computer.register_map)
		quantum_computer.set_driven_icons(driven_configs)

		var elapsed = Time.get_ticks_msec() - start_time
		if verbose:
			verbose.info("cache", "💾", "Built in %d ms - saving to cache for next boot" % elapsed)

		# Save to cache for next time
		cache.save(biome_name, cache_key, quantum_computer.hamiltonian, quantum_computer.lindblad_operators)

