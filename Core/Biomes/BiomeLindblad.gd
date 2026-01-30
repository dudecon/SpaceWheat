class_name BiomeLindblad
extends RefCounted

## BiomeLindblad: Biome-specific dissipative quantum mechanics
##
## Separates environmental dissipation (Lindblad) from universal laws (Hamiltonian).
## Factions define coherent dynamics (H), biomes define dissipative flows (L).
##
## Usage:
##   var lindblad = BiomeLindblad.new()
##   lindblad.add_pump("🌱", "☀", 0.03)  # Sun pumps seedlings
##   lindblad.add_drain("🍂", "🌲", 0.1)  # Trees decay to leaf litter

## Lindblad components per emoji
## Format: {emoji: {outgoing: {target: rate}, incoming: {source: rate}, gated: [...]}}
var components: Dictionary = {}

## Biome-wide decay processes (emoji → {target: emoji, rate: float})
var decay_processes: Array = []

## Gated Lindblad (context-dependent dissipation)
## Format: [{source: emoji, target: emoji, gate: emoji, rate: float, power: float, inverse: bool}]
var gated_configs: Array = []


## Add a Lindblad pump (source → target, irreversible flow)
func add_pump(target: String, source: String, rate: float) -> void:
	"""Environmental pump: source population increases target population.
	
	Example: add_pump('🌱', '☀', 0.03) - Sun pumps seedlings (photosynthesis)
	"""
	if not components.has(target):
		components[target] = {"outgoing": {}, "incoming": {}, "gated": []}
	components[target]["incoming"][source] = rate


## Add a Lindblad drain (source → target, irreversible decay)
func add_drain(source: String, target: String, rate: float) -> void:
	"""Environmental drain: source population decays into target.
	
	Example: add_drain('🌲', '🍂', 0.1) - Trees decay to leaf litter
	"""
	if not components.has(source):
		components[source] = {"outgoing": {}, "incoming": {}, "gated": []}
	components[source]["outgoing"][target] = rate


## Add a decay process (exponential decay to ground state)
func add_decay(emoji: String, target: String, rate: float) -> void:
	"""Exponential decay: emoji decays to target state.
	
	Example: add_decay('🌲', '🍂', 0.1) - Trees have intrinsic decay
	"""
	decay_processes.append({"emoji": emoji, "target": target, "rate": rate})


## Add a gated Lindblad (conditional dissipation)
func add_gated(source: String, target: String, gate: String, rate: float, power: float = 1.0, inverse: bool = false) -> void:
	"""Gated dissipation: flow rate depends on gate emoji population.
	
	Args:
		source: Source emoji
		target: Target emoji  
		gate: Gate emoji (controls flow)
		rate: Base dissipation rate
		power: Exponent on gate population (default 1.0)
		inverse: If true, flow is stronger when gate is LOW (default false)
	
	Example: add_gated('🍄', '🌙', '💧', 0.06, 1.0) - Mushrooms grow when wet
	"""
	gated_configs.append({
		"source": source,
		"target": target,
		"gate": gate,
		"rate": rate,
		"power": power,
		"inverse": inverse
	})


## Get Lindblad component for a specific emoji
func get_component(emoji: String) -> Dictionary:
	"""Returns {outgoing: {}, incoming: {}, gated: []} for the emoji"""
	return components.get(emoji, {"outgoing": {}, "incoming": {}, "gated": []})


## Get all emojis that have Lindblad terms
func get_all_emojis() -> Array:
	var emojis: Array = []
	for emoji in components.keys():
		if emoji not in emojis:
			emojis.append(emoji)
	for decay in decay_processes:
		var e = decay.get("emoji", "")
		if e != "" and e not in emojis:
			emojis.append(e)
	for gated in gated_configs:
		for key in ["source", "target", "gate"]:
			var e = gated.get(key, "")
			if e != "" and e not in emojis:
				emojis.append(e)
	return emojis


## Debug representation
func _to_string() -> String:
	return "BiomeLindblad(%d emojis, %d gated)" % [components.size(), gated_configs.size()]
