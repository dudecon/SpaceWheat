class_name BiomeBuilder
extends RefCounted

## BiomeBuilder: Unified machinery for building biome quantum systems
##
## DESIGN INVARIANT: Boot and live-rebuild use the SAME code path.
## This ensures consistent behavior whether building at startup or
## when faction standings change or new biomes are discovered.
##
## Architecture:
##   1. Factions → Icons (Hamiltonian only)
##   2. Icons → H matrix (universal coherent dynamics)
##   3. Biome Lindblad spec → L operators (environmental dissipation)
##   4. H + L → QuantumComputer (unified evolution)
##
## Usage:
##   var builder = BiomeBuilder.new()
##   var result = builder.build_biome_quantum_system(
##       biome_name, 
##       emoji_pairs,
##       faction_standings,
##       lindblad_spec
##   )
##   quantum_computer = result.quantum_computer

const IconBuilder = preload("res://Core/Factions/IconBuilder.gd")
const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")
const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const BiomeCharacteristics = preload("res://Core/Biomes/BiomeCharacteristics.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const HamiltonianBuilder = preload("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
const LindbladBuilder = preload("res://Core/QuantumSubstrate/LindbladBuilder.gd")
const BiomeLindblad = preload("res://Core/Biomes/BiomeLindblad.gd")
const OperatorCache = preload("res://Core/QuantumSubstrate/OperatorCache.gd")
const CacheKey = preload("res://Core/QuantumSubstrate/CacheKey.gd")
const DynamicBiome = preload("res://Core/Environment/DynamicBiome.gd")

## Singleton instances (lazy-loaded)
static var _faction_registry: FactionRegistry = null
static var _biome_registry: BiomeRegistry = null
static var _icon_registry = null  # Autoload reference


## Get or create FactionRegistry
static func _get_faction_registry() -> FactionRegistry:
	if _faction_registry == null:
		_faction_registry = FactionRegistry.new()
	return _faction_registry


## Get or create BiomeRegistry
static func _get_biome_registry() -> BiomeRegistry:
	if _biome_registry == null:
		_biome_registry = BiomeRegistry.new()
	return _biome_registry


## Get IconRegistry autoload
static func _get_icon_registry():
	if _icon_registry == null:
		var tree = Engine.get_main_loop()
		if tree and tree.has_method("get_root"):
			var root = tree.get_root()
			if root:
				_icon_registry = root.get_node_or_null("/root/IconRegistry")
	return _icon_registry


## ============================================================================
## UNIFIED BIOME CONSTRUCTION FROM REGISTRY
## ============================================================================

## Build complete biome from BiomeRegistry (JSON-driven)
## This is the NEW unified entry point for all contexts:
## - BootManager (game boot)
## - TestBootManager (test harness)
## - Dynamic biome toggle (runtime)
static func build_from_registry(
	biome_name: String,
	parent_node: Node,
	options: Dictionary = {}
) -> Dictionary:
	"""Build a complete DynamicBiome from BiomeRegistry.

	This method:
	1. Loads biome definition from BiomeRegistry
	2. Extracts emoji pairs from biome.emojis
	3. Builds Lindblad spec from biome.icon_components
	4. Calls build_biome_quantum_system() to create QuantumComputer
	5. Creates DynamicBiome node with viz_cache
	6. Adds biome to parent_node

	Args:
		biome_name: Name of biome in BiomeRegistry (e.g., "StarterForest")
		parent_node: Node to add biome as child
		options: Optional parameters {
			faction_standings: Dictionary (faction_name -> weight),
			skip_tree_add: bool (don't add to parent_node),
		}

	Returns:
		{
			success: bool,
			biome_node: DynamicBiome (if success),
			quantum_computer: QuantumComputer (if success),
			icons: Dictionary (emoji -> Icon),
			error: String (if failure)
		}
	"""
	var result = {
		"success": false,
		"biome_node": null,
		"quantum_computer": null,
		"icons": {},
		"error": ""
	}

	# 1. Load biome from registry
	var biome_registry = _get_biome_registry()
	var biome_def = biome_registry.get_by_name(biome_name)

	if not biome_def:
		result.error = "Biome '%s' not found in BiomeRegistry" % biome_name
		return result

	# 2. Extract emoji pairs from biome.emojis
	var emoji_pairs = _group_emojis_into_pairs(biome_def.emojis)

	if emoji_pairs.is_empty():
		result.error = "No emoji pairs for biome '%s'" % biome_name
		return result

	# 3. Build Lindblad spec from biome icon_components
	var lindblad_spec = _build_lindblad_spec_from_biome(biome_def)

	# 4. Build quantum system (H + L)
	var faction_standings = options.get("faction_standings", {})
	var quantum_result = build_biome_quantum_system(
		biome_name,
		emoji_pairs,
		faction_standings,
		lindblad_spec
	)

	if not quantum_result.success:
		result.error = quantum_result.error
		return result

	var qc = quantum_result.quantum_computer
	var icons = quantum_result.icons

	# 5. Create DynamicBiome node
	var biome = DynamicBiome.new()
	biome.set_biome_type(biome_name)
	biome.name = biome_name
	biome.quantum_computer = qc

	# Store icons for viz_cache coupling data
	biome.set_meta("icons", icons)

	# Store biome definition for later reference
	biome.set_meta("biome_def", biome_def)

	# 6. CRITICAL: Initialize components manually (before tree add)
	# BiomeBase._ready() normally does this, but we need it before tree entry
	_initialize_biome_components(biome, qc)

	# 7. Create viz_cache with metadata
	var viz_metadata = _build_viz_metadata(emoji_pairs, biome_def)
	var QuantumVizCache = load("res://Core/Visualization/QuantumVizCache.gd")
	biome.viz_cache = QuantumVizCache.new()
	biome.viz_cache.update_metadata_from_payload(viz_metadata)

	# 8. Seed viz_cache with coupling data from icons
	# (Must be done AFTER icons are set but BEFORE biome enters tree)
	if biome.has_method("_seed_viz_couplings"):
		biome._seed_viz_couplings()

	# 8b. Apply optimal evolution granularity from characteristics
	BiomeCharacteristics.apply_to_biome(biome)

	# 9. Add to tree (unless skip_tree_add)
	if not options.get("skip_tree_add", false) and parent_node:
		parent_node.add_child(biome)

	result.success = true
	result.biome_node = biome
	result.quantum_computer = qc
	result.icons = icons
	return result


## INTERNAL: Group emojis into north/south pairs
static func _group_emojis_into_pairs(emojis: Array) -> Array:
	"""Convert flat emoji list into axis pairs.

	Pairs emojis sequentially: [0,1], [2,3], [4,5], ...
	If odd count, last emoji pairs with itself.

	Returns: [{north: emoji, south: emoji}]
	"""
	var pairs: Array = []

	for i in range(0, emojis.size(), 2):
		var north = emojis[i]
		var south = emojis[i + 1] if i + 1 < emojis.size() else emojis[i]
		pairs.append({"north": north, "south": south})

	return pairs


## INTERNAL: Build BiomeLindblad spec from Biome definition
static func _build_lindblad_spec_from_biome(biome_def) -> BiomeLindblad:
	"""Extract Lindblad dissipation spec from biome icon_components.

	Converts biome.icon_components into BiomeLindblad format.
	"""
	var spec = BiomeLindblad.new()

	# Extract Lindblad terms from each emoji's icon_component
	for emoji in biome_def.icon_components:
		var component = biome_def.icon_components[emoji]

		# Outgoing transitions (drains: emoji → target)
		var lindblad_out = component.get("lindblad_outgoing", {})
		if not lindblad_out.is_empty():
			for target in lindblad_out:
				var rate = lindblad_out[target]
				spec.add_drain(emoji, target, rate)

		# Incoming transitions (pumps: source → emoji)
		var lindblad_in = component.get("lindblad_incoming", {})
		if not lindblad_in.is_empty():
			for source in lindblad_in:
				var rate = lindblad_in[source]
				spec.add_pump(emoji, source, rate)

		# Decay processes
		var decay = component.get("decay", {})
		if not decay.is_empty():
			var decay_rate = decay.get("rate", 0.0)
			var decay_target = decay.get("target", "")
			if decay_rate > 0.0 and decay_target != "":
				spec.add_decay(emoji, decay_target, decay_rate)

	return spec


## INTERNAL: Build viz_cache metadata from emoji pairs
static func _build_viz_metadata(emoji_pairs: Array, biome_def) -> Dictionary:
	"""Create visualization metadata for QuantumVizCache.

	Returns metadata dict with axes, emoji mappings, and emoji list.
	"""
	var metadata = {
		"num_qubits": emoji_pairs.size(),
		"axes": {},
		"emoji_to_qubit": {},
		"emoji_to_pole": {},
		"emoji_list": []
	}

	for i in range(emoji_pairs.size()):
		var pair = emoji_pairs[i]
		metadata.axes[i] = {"north": pair.north, "south": pair.south}
		metadata.emoji_to_qubit[pair.north] = i
		metadata.emoji_to_qubit[pair.south] = i
		metadata.emoji_to_pole[pair.north] = 0
		metadata.emoji_to_pole[pair.south] = 1
		metadata.emoji_list.append(pair.north)
		metadata.emoji_list.append(pair.south)

	return metadata


## INTERNAL: Initialize BiomeBase components manually (before tree add)
static func _initialize_biome_components(biome, quantum_computer) -> void:
	"""Initialize BiomeBase component instances.

	This is normally done in BiomeBase._ready(), but when building biomes
	that might not immediately enter the tree, we need to initialize
	components manually to avoid null reference errors.

	IDEMPOTENCY: Sets _is_initialized flag to prevent double-initialization
	when the node later enters the tree and _ready() is called.

	Args:
		biome: DynamicBiome or BiomeBase instance
		quantum_computer: QuantumComputer to wire to components
	"""
	# Skip if already initialized
	if biome.get("_is_initialized"):
		return

	# Load component classes
	const BiomeResourceRegistry = preload("res://Core/Environment/Components/BiomeResourceRegistry.gd")
	const BiomeBellGateTracker = preload("res://Core/Environment/Components/BiomeBellGateTracker.gd")
	const BiomeQuantumObserver = preload("res://Core/Environment/Components/BiomeQuantumObserver.gd")
	const BiomeGateOperations = preload("res://Core/Environment/Components/BiomeGateOperations.gd")
	const BiomeQuantumSystemBuilder = preload("res://Core/Environment/Components/BiomeQuantumSystemBuilder.gd")
	const BiomeDensityMatrixMutator = preload("res://Core/Environment/Components/BiomeDensityMatrixMutator.gd")

	# Initialize components (same order as BiomeBase._ready())
	biome._resource_registry = BiomeResourceRegistry.new()
	biome._bell_gate_tracker = BiomeBellGateTracker.new()
	biome._quantum_observer = BiomeQuantumObserver.new()
	biome._gate_operations = BiomeGateOperations.new()
	biome._system_builder = BiomeQuantumSystemBuilder.new()
	biome._density_mutator = BiomeDensityMatrixMutator.new()

	# Wire quantum_computer to components that need it
	if quantum_computer:
		biome._quantum_observer.set_quantum_computer(quantum_computer)
		biome._density_mutator.set_quantum_computer(quantum_computer)

	# Set flag to prevent double-initialization in _ready()
	biome._is_initialized = true


## Build complete quantum system for a biome
## INVARIANT: Can be called at boot OR during gameplay (same logic)
static func build_biome_quantum_system(
	biome_name: String,
	emoji_pairs: Array,  # [{north: String, south: String}]
	faction_standings: Dictionary = {},  # {faction_name: weight (0.0-1.0)}
	lindblad_spec: BiomeLindblad = null
) -> Dictionary:
	"""Build a complete quantum system for a biome.
	
	This is the UNIFIED entry point for both boot-time and live rebuilds.
	
	Args:
		biome_name: Name of the biome (e.g. "StarterForest")
		emoji_pairs: Qubit axes [(north, south)] defining the quantum registers
		faction_standings: Faction weights (for reputation-based icon building)
		lindblad_spec: Biome-specific dissipation rules (pumps, drains, gated)
	
	Returns:
		{
			success: bool,
			quantum_computer: QuantumComputer,
			icons: Dictionary,  # emoji -> Icon (Hamiltonian-only)
			hamiltonian: ComplexMatrix,
			lindblad_operators: Array,
			error: String (if failure)
		}
	"""
	var result = {
		"success": false,
		"quantum_computer": null,
		"icons": {},
		"hamiltonian": null,
		"lindblad_operators": [],
		"error": ""
	}
	
	# 1. Create QuantumComputer with register map
	var qc = QuantumComputer.new(biome_name)
	
	# 2. Allocate axes from emoji pairs
	for i in range(emoji_pairs.size()):
		var pair = emoji_pairs[i]
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			result.error = "Invalid emoji pair at index %d" % i
			return result
		qc.allocate_axis(i, north, south)
	
	print("🔧 BiomeBuilder: Allocated %d axes for %s" % [emoji_pairs.size(), biome_name])
	
	# 3. Build Icons (Hamiltonian-only) from factions with standings
	var icons = _build_icons_from_factions(qc.register_map, faction_standings)
	if icons.is_empty():
		result.error = "No icons could be built for biome"
		return result
	
	result.icons = icons
	print("🔧 BiomeBuilder: Built %d icons (H-only)" % icons.size())
	
	# 4. Build Hamiltonian (universal coherent dynamics)
	var verbose = _get_verbose_config()
	var H = HamiltonianBuilder.build(icons, qc.register_map, verbose)
	if not H:
		result.error = "Failed to build Hamiltonian"
		return result
	
	qc.hamiltonian = H
	result.hamiltonian = H
	print("🔧 BiomeBuilder: Built Hamiltonian (%dx%d)" % [H.n, H.n])
	
	# 5. Build Lindblad (biome-specific dissipation)
	var lindblad_result = _build_lindblad_from_biome_spec(lindblad_spec, qc.register_map, verbose)
	qc.lindblad_operators = lindblad_result.get("operators", [])
	qc.gated_lindblad_configs = lindblad_result.get("gated_configs", [])
	result.lindblad_operators = qc.lindblad_operators
	
	print("🔧 BiomeBuilder: Built %d Lindblad operators + %d gated" % [
		qc.lindblad_operators.size(),
		qc.gated_lindblad_configs.size()
	])
	
	# 6. Set up time-dependent drivers (from Hamiltonian icons)
	var driven_configs = HamiltonianBuilder.get_driven_icons(icons, qc.register_map)
	qc.set_driven_icons(driven_configs)
	
	# 7. Initialize to uniform superposition (fallback default)
	qc.initialize_uniform_superposition()
	
	result.success = true
	result.quantum_computer = qc
	return result


## Rebuild just the Icons when faction standings change
## (Hamiltonian needs rebuild, Lindblad stays the same)
static func rebuild_icons_for_standings(
	register_map,
	faction_standings: Dictionary
) -> Dictionary:
	"""Rebuild icons when faction reputation changes.
	
	Returns: {emoji -> Icon} with updated Hamiltonian weights
	"""
	return _build_icons_from_factions(register_map, faction_standings)


## INTERNAL: Build Icons from factions (Hamiltonian-only)
static func _build_icons_from_factions(register_map, faction_standings: Dictionary) -> Dictionary:
	"""Build Hamiltonian-only Icons from faction contributions.
	
	Each Icon represents the UNIVERSAL (faction-based) coherent dynamics,
	weighted by current faction standings.
	"""
	var faction_registry = _get_faction_registry()
	var all_factions = faction_registry.get_all()
	
	# Build faction index for fast emoji lookup
	IconBuilder.build_faction_index(all_factions)
	
	# Get all emojis from register map
	var emojis = register_map.coordinates.keys() if register_map else []
	
	# Build each icon (H-only, no Lindblad terms)
	var icons: Dictionary = {}
	for emoji in emojis:
		var icon = _build_hamiltonian_icon(emoji, all_factions, faction_standings)
		if icon:
			icons[emoji] = icon
	
	return icons


## INTERNAL: Build a single Hamiltonian-only Icon
static func _build_hamiltonian_icon(emoji: String, factions: Array, standings: Dictionary):
	"""Build an Icon with ONLY Hamiltonian terms (no Lindblad).
	
	Faction contributions are weighted by standing values.
	"""
	var IconScript = load("res://Core/QuantumSubstrate/Icon.gd")
	var icon = IconScript.new()
	icon.emoji = emoji
	icon.display_name = emoji
	
	var contributing_factions: Array[String] = []
	
	# Merge faction contributions (Hamiltonian only)
	for faction in factions:
		if not faction.speaks(emoji):
			continue
		
		var standing = standings.get(faction.name, 1.0)
		if standing <= 0.0:
			continue  # Skip muted factions
		
		contributing_factions.append(faction.name)
		var contribution = faction.get_icon_contribution(emoji)
		
		# Merge self_energy (weighted by standing)
		icon.self_energy += contribution.get("self_energy", 0.0) * standing
		
		# Merge hamiltonian_couplings (weighted)
		var h_couplings = contribution.get("hamiltonian_couplings", {})
		for target in h_couplings:
			var current = icon.hamiltonian_couplings.get(target, null)
			var incoming = h_couplings[target]
			
			# Apply standing weight
			if incoming is Vector2:
				incoming = Vector2(incoming.x * standing, incoming.y * standing)
			else:
				incoming = incoming * standing
			
			# Merge (handle float + Vector2 mixing)
			icon.hamiltonian_couplings[target] = IconBuilder._add_hamiltonian_values(current, incoming)
		
		# Merge alignment couplings (weighted)
		var align = contribution.get("alignment_couplings", {})
		for observable in align:
			var current = icon.energy_couplings.get(observable, 0.0)
			icon.energy_couplings[observable] = current + (align[observable] * standing)
		
		# Merge driver (take first driver found with non-zero standing)
		var driver = contribution.get("driver", {})
		if driver.has("type") and icon.self_energy_driver == "":
			icon.self_energy_driver = driver.get("type", "")
			icon.driver_frequency = driver.get("freq", 0.0)
			icon.driver_phase = driver.get("phase", 0.0)
			icon.driver_amplitude = driver.get("amp", 1.0) * standing
	
	# Set description
	if contributing_factions.is_empty():
		icon.description = "Unaffiliated"
	elif contributing_factions.size() == 1:
		icon.description = "Speaks for %s" % contributing_factions[0]
	else:
		icon.description = "Contested by: %s" % ", ".join(contributing_factions)
	
	# Set tags
	var tags: Array[String] = []
	for name in contributing_factions:
		tags.append(name.to_lower().replace(" ", "_"))
	icon.tags = tags
	
	# Set flags
	icon.is_driver = icon.self_energy_driver != ""
	icon.is_eternal = icon.is_driver  # Drivers don't decay
	
	return icon


## INTERNAL: Build Lindblad operators from BiomeLindblad spec
static func _build_lindblad_from_biome_spec(
	lindblad_spec: BiomeLindblad,
	register_map,
	verbose
) -> Dictionary:
	"""Build Lindblad superoperators from biome-specific dissipation rules.
	
	Returns: {operators: Array, gated_configs: Array}
	"""
	if not lindblad_spec:
		return {"operators": [], "gated_configs": []}
	
	# Convert BiomeLindblad to Icon-like format for LindbladBuilder
	# This is a temporary adapter until we refactor LindbladBuilder
	var pseudo_icons: Dictionary = {}
	
	for emoji in lindblad_spec.get_all_emojis():
		var IconScript = load("res://Core/QuantumSubstrate/Icon.gd")
		var pseudo_icon = IconScript.new()
		pseudo_icon.emoji = emoji
		
		var component = lindblad_spec.get_component(emoji)
		pseudo_icon.lindblad_outgoing = component.get("outgoing", {})
		pseudo_icon.lindblad_incoming = component.get("incoming", {})
		
		# Handle decay processes
		for decay in lindblad_spec.decay_processes:
			if decay.get("emoji", "") == emoji:
				pseudo_icon.decay_rate = decay.get("rate", 0.0)
				pseudo_icon.decay_target = decay.get("target", "")
		
		pseudo_icons[emoji] = pseudo_icon
	
	# Build using existing LindbladBuilder
	var result = LindbladBuilder.build(pseudo_icons, register_map, verbose)
	
	# Add gated configs from spec
	if lindblad_spec.gated_configs.size() > 0:
		result["gated_configs"] = lindblad_spec.gated_configs
	
	return result


## Get VerboseConfig singleton (safe access)
static func _get_verbose_config():
	if Engine.has_singleton("VerboseConfig"):
		return Engine.get_singleton("VerboseConfig")
	
	var tree = Engine.get_main_loop()
	if tree and tree.has_method("get_root"):
		var root = tree.get_root()
		if root:
			return root.get_node_or_null("/root/VerboseConfig")
	
	return null
