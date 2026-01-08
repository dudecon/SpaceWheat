class_name IconFaction
extends RefCounted

## IconFaction: A closed dynamical system over 3-7 signature emojis
## (Renamed from Faction to avoid conflict with Core/GameMechanics/Faction.gd)
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
## {target_emoji: [{source: emoji, rate: float, gate: emoji, power: float}]}
## effective_rate = base_rate × P(gate)^power
## When P(gate) = 0, transfer stops entirely. Multiplicative, not additive.
## Use for dependencies like pollination, fermentation catalysts, etc.
var gated_lindblad: Dictionary = {}

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
	}
	
	return contribution

## Debug representation
func _to_string() -> String:
	return "Faction<%s>[%s](%d emojis)" % [name, ring, signature.size()]
