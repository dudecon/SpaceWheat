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
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const HamiltonianBuilder = preload("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
const LindbladBuilder = preload("res://Core/QuantumSubstrate/LindbladBuilder.gd")
const BiomeLindblad = preload("res://Core/Biomes/BiomeLindblad.gd")
const OperatorCache = preload("res://Core/QuantumSubstrate/OperatorCache.gd")
const CacheKey = preload("res://Core/QuantumSubstrate/CacheKey.gd")

## Singleton instances (lazy-loaded)
static var _faction_registry: FactionRegistry = null
static var _icon_registry = null  # Autoload reference


## Get or create FactionRegistry
static func _get_faction_registry() -> FactionRegistry:
	if _faction_registry == null:
		_faction_registry = FactionRegistry.new()
	return _faction_registry


## Get IconRegistry autoload
static func _get_icon_registry():
	if _icon_registry == null:
		var tree = Engine.get_main_loop()
		if tree and tree.has_method("get_root"):
			var root = tree.get_root()
			if root:
				_icon_registry = root.get_node_or_null("/root/IconRegistry")
	return _icon_registry


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
