class_name Faction
extends RefCounted

## Faction: A closed dynamical system over 3-7 signature emojis
##
## Factions define coupling terms between their signature emojis ONLY.
## An emoji can belong to multiple factions.
## Icons are built by collecting ALL contributions from ALL factions.
##
## Example: 🍂 belongs to both Verdant Pulse and Mycelial Web
##   → The 🍂 Icon gets hamiltonian_couplings from BOTH factions (additive)
##
## Contested emojis like 👥 will have many coupling terms from many factions.
## This is where gameplay tension emerges.

## ========================================
## Identity
## ========================================

var name: String = ""
var description: String = ""
var ring: String = "center"  # "center", "second", "third", "outer"

## The ONLY emojis this faction speaks (3-7 ideal)
var signature: Array = []

## ========================================
## Hamiltonian Terms (Unitary Evolution)
## ========================================

## Self-energies for signature emojis
## {emoji: float}
var self_energies: Dictionary = {}

## Hamiltonian couplings WITHIN signature
## {source_emoji: {target_emoji: float}}
## Both source and target MUST be in signature
var hamiltonian: Dictionary = {}

## Driver configuration for time-dependent self-energy
## {emoji: {type: "cosine"|"sine"|"pulse", freq: float, phase: float, amp: float}}
var drivers: Dictionary = {}

## ========================================
## Lindblad Terms (Dissipative Evolution)
## ========================================

## Outgoing transfers: source loses amplitude to target
## {source_emoji: {target_emoji: float}}
var lindblad_outgoing: Dictionary = {}

## Incoming transfers: target gains amplitude from source
## {target_emoji: {source_emoji: float}}
var lindblad_incoming: Dictionary = {}

## Gated Lindblad: transfers that REQUIRE a catalyst emoji
## {target_emoji: [{source: emoji, rate: float, gate: emoji, power: float, inverse: bool}]}
## Normal: effective_rate = base_rate × P(gate)^power
## Inverse (inverse=true): effective_rate = base_rate × (1 - P(gate))^power
## Use inverse for "starvation" mechanics where LOW gate = HIGH transfer
var gated_lindblad: Dictionary = {}

## Measurement behavior: how this emoji responds to measurement/observation
## {emoji: {inverts: bool}}
## If inverts=true, measuring this emoji collapses to the OPPOSITE pole of its axis
## Example: On axis (🧤, 🗑), measuring 🧤 → collapses to 🗑
##          On axis (🧤, 💀), measuring 🧤 → collapses to 💀
## Use to "sneak mass" into a basis state - the refugee appears as its opposite
## This is a quantum mask: measurement reveals what's hidden beneath
var measurement_behavior: Dictionary = {}

## Decay configuration
## {emoji: {rate: float, target: String}}
## Note: decay_target can be outside signature (e.g., 💀)
var decay: Dictionary = {}

## ========================================
## Alignment Couplings (Parametric Effects)
## ========================================

## Alignment couplings: how emoji responds to presence of other emojis
## {emoji: {observable_emoji: float}}
## Positive = enhanced when observable is high (☀️ helps 🌾 grow)
## Negative = suppressed when observable is high (☀️ hurts 🍄)
##
## These create "alignment" effects where growth rates scale with
## the probability of the observable. When P(☀️) is high AND 🌾 is
## trying to grow, the growth is enhanced.
##
## Note: observable_emoji can be OUTSIDE signature (cross-faction alignment)
var alignment_couplings: Dictionary = {}

## ========================================
## Bell State Conditional Features
## ========================================

## Bell-activated features: icon mechanics that only work during entanglement
## {emoji: {latent_lindblad: {}, latent_hamiltonian: {}, description: ""}}
##
## These features are "dormant" until a Bell state (entanglement) is detected
## between the emoji and another. When entangled:
## - latent_lindblad transfers activate
## - latent_hamiltonian couplings strengthen
##
## Example: Knot-Shriners' oaths only bind when entangled
## {"🪢": {"latent_lindblad": {"🪢": {"📿": 0.1}}, "description": "Oaths bind when entangled"}}
var bell_activated_features: Dictionary = {}

## ========================================
## Decoherence Coupling
## ========================================

## Decoherence coupling: how emoji affects bath coherence (T2 time)
## {emoji: float}
## Positive = increases decoherence (observation, heat, noise → lower T2)
## Negative = decreases decoherence (cold, silence, stability → higher T2)
##
## Example: 🔬 (microscope) causes decoherence through observation
## Example: 🧊 (ice) preserves coherence by cooling
## Example: 🔇 (mute) destroys coherence through silence
var decoherence_coupling: Dictionary = {}

## ========================================
## Metadata
## ========================================

## Tags for organization
var tags: Array = []

## ========================================
## Methods
## ========================================

## Check if this faction speaks an emoji
func speaks(emoji: String) -> bool:
	return emoji in signature

## Get all emojis this faction contributes to (including decay targets)
func get_all_emojis() -> Array:
	var result: Array = signature.duplicate()
	for emoji in decay:
		var target = decay[emoji].get("target", "")
		if target != "" and target not in result:
			result.append(target)
	return result

## Validate that all couplings stay within signature
func validate() -> bool:
	var valid = true
	
	# Check hamiltonian couplings
	for source in hamiltonian:
		if source not in signature:
			push_error("Faction %s: hamiltonian source %s not in signature" % [name, source])
			valid = false
		for target in hamiltonian[source]:
			if target not in signature:
				push_error("Faction %s: hamiltonian target %s not in signature" % [name, target])
				valid = false
	
	# Check lindblad outgoing
	for source in lindblad_outgoing:
		if source not in signature:
			push_error("Faction %s: lindblad_outgoing source %s not in signature" % [name, source])
			valid = false
		for target in lindblad_outgoing[source]:
			if target not in signature:
				push_error("Faction %s: lindblad_outgoing target %s not in signature" % [name, target])
				valid = false
	
	# Check lindblad incoming
	for target in lindblad_incoming:
		if target not in signature:
			push_error("Faction %s: lindblad_incoming target %s not in signature" % [name, target])
			valid = false
		for source in lindblad_incoming[target]:
			if source not in signature:
				push_error("Faction %s: lindblad_incoming source %s not in signature" % [name, source])
				valid = false
	
	# Decay targets CAN be outside signature (that's how we connect to other factions)
	# So we don't validate decay targets
	
	return valid

## Get this faction's contribution to a specific Icon
func get_icon_contribution(emoji: String) -> Dictionary:
	if not speaks(emoji):
		return {}

	var contribution = {
		"faction": name,
		"self_energy": self_energies.get(emoji, 0.0),
		"hamiltonian_couplings": hamiltonian.get(emoji, {}),
		"lindblad_outgoing": lindblad_outgoing.get(emoji, {}),
		"lindblad_incoming": lindblad_incoming.get(emoji, {}),
		"gated_lindblad": gated_lindblad.get(emoji, []),
		"decay": decay.get(emoji, {}),
		"driver": drivers.get(emoji, {}),
		"alignment_couplings": alignment_couplings.get(emoji, {}),
		"measurement_behavior": measurement_behavior.get(emoji, {}),
		# New quantum mechanics features
		"bell_activated_features": bell_activated_features.get(emoji, {}),
		"decoherence_coupling": decoherence_coupling.get(emoji, 0.0),
	}

	return contribution

## Debug representation
func _to_string() -> String:
	return "Faction<%s>[%s](%d emojis)" % [name, ring, signature.size()]


## ========================================
## Serialization (JSON Data-Driven Support)
## ========================================

## Convert faction to dictionary for JSON export
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"name": name,
		"description": description,
		"ring": ring,
		"signature": signature,
		"tags": tags,
	}

	# Only include non-empty fields
	if not self_energies.is_empty():
		data["self_energies"] = self_energies

	if not hamiltonian.is_empty():
		# Convert Vector2 to [real, imag] arrays for JSON
		data["hamiltonian"] = _serialize_hamiltonian(hamiltonian)

	if not drivers.is_empty():
		data["drivers"] = drivers

	if not lindblad_outgoing.is_empty():
		data["lindblad_outgoing"] = lindblad_outgoing

	if not lindblad_incoming.is_empty():
		data["lindblad_incoming"] = lindblad_incoming

	if not gated_lindblad.is_empty():
		data["gated_lindblad"] = gated_lindblad

	if not measurement_behavior.is_empty():
		data["measurement_behavior"] = measurement_behavior

	if not decay.is_empty():
		data["decay"] = decay

	if not alignment_couplings.is_empty():
		data["alignment_couplings"] = alignment_couplings

	if not bell_activated_features.is_empty():
		data["bell_activated_features"] = bell_activated_features

	if not decoherence_coupling.is_empty():
		data["decoherence_coupling"] = decoherence_coupling

	return data


## Load faction from dictionary (JSON import)
func load_from_dict(data: Dictionary) -> void:
	name = data.get("name", "")
	description = data.get("description", "")
	ring = data.get("ring", "center")
	signature = data.get("signature", [])
	tags = data.get("tags", [])

	self_energies = data.get("self_energies", {})

	# Convert [real, imag] arrays back to Vector2
	hamiltonian = _deserialize_hamiltonian(data.get("hamiltonian", {}))

	drivers = data.get("drivers", {})
	lindblad_outgoing = data.get("lindblad_outgoing", {})
	lindblad_incoming = data.get("lindblad_incoming", {})
	gated_lindblad = data.get("gated_lindblad", {})
	measurement_behavior = data.get("measurement_behavior", {})
	decay = data.get("decay", {})
	alignment_couplings = data.get("alignment_couplings", {})
	bell_activated_features = data.get("bell_activated_features", {})
	decoherence_coupling = data.get("decoherence_coupling", {})


## Helper: Serialize hamiltonian (convert Vector2 to [real, imag])
func _serialize_hamiltonian(h: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for source in h:
		result[source] = {}
		for target in h[source]:
			var value = h[source][target]
			if value is Vector2:
				result[source][target] = [value.x, value.y]
			else:
				result[source][target] = value
	return result


## Helper: Deserialize hamiltonian (convert [real, imag] to Vector2)
func _deserialize_hamiltonian(h: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for source in h:
		result[source] = {}
		for target in h[source]:
			var value = h[source][target]
			if value is Array and value.size() == 2:
				result[source][target] = Vector2(value[0], value[1])
			else:
				result[source][target] = value
	return result


## Create faction from dictionary (static factory)
static func from_dict(data: Dictionary) -> Faction:
	var faction = Faction.new()
	faction.load_from_dict(data)
	return faction
