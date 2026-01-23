class_name Icon
extends Resource

## Icon: The eternal Hamiltonian attached to an emoji
## Defines how this emoji interacts with others in any biome
## Icons are the VERBS of the quantum universe

## ========================================
## Identity
## ========================================

@export var emoji: String = ""
@export var display_name: String = ""
@export var description: String = ""

## ========================================
## Hamiltonian Terms (Unitary Evolution)
## ========================================

## Self-energy: diagonal term H[i,i] - natural frequency
@export var self_energy: float = 0.0

## Couplings: off-diagonal terms H[i,j]
## Key = target emoji, Value = coupling strength (real, will be symmetrized)
@export var hamiltonian_couplings: Dictionary = {}

## Time-dependent self-energy for external driving (e.g., day/night cycle)
@export var self_energy_driver: String = ""  # "cosine", "sine", "pulse", or ""
@export var driver_frequency: float = 0.0    # Hz (cycles per second)
@export var driver_phase: float = 0.0        # Radians
@export var driver_amplitude: float = 1.0    # Multiplier for self_energy

## ========================================
## Lindblad Terms (Dissipative Evolution)
## ========================================

## Outgoing transfers: this emoji loses amplitude to target
## Key = target emoji, Value = transfer rate γ (in amplitude/sec, NOT energy/sec)
##
## IMPORTANT: Rates are in AMPLITUDE units, not energy/probability
## With dt=0.016 (60 FPS), transfer per frame ≈ √(rate × dt)
## Example: rate=0.008 → ~1.13% amplitude/frame → ~88% transferred in 10 seconds
##
## Typical ranges for amplitude-based evolution:
##   Fast transfers (predation): 0.015/sec → ~88% in 6 seconds
##   Medium transfers (herbivory): 0.010/sec → ~88% in 10 seconds
##   Slow transfers (wheat growth): 0.003-0.008/sec → ~88% in 12-30 seconds
##   Very slow (soil accumulation): 0.002/sec → ~88% in 50 seconds
@export var lindblad_outgoing: Dictionary = {}

## Incoming transfers: this emoji gains amplitude from source
## (Syntactic sugar - will be converted to source's outgoing during bath construction)
## Rates are in amplitude/sec (see lindblad_outgoing documentation above)
@export var lindblad_incoming: Dictionary = {}

## Self-decay: amplitude leaks to decay_target
@export var decay_rate: float = 0.0
@export var decay_target: String = "🍂"  # Default: organic matter

## Gated Lindblad transfers: conditional transfers based on gate emoji population
## Key = target emoji, Value = Array of gate configs
## Each gate config: { "source": emoji, "rate": float, "gate": emoji, "power": float }
## Transfer only occurs when gate emoji has significant population
@export var gated_lindblad: Dictionary = {}

## ========================================
## Energy Tap Configuration (Gozouta 1)
## Manifest Section 4.1: Trickle Drain
## ========================================

## Can this emoji be targeted by energy taps?
## When true, this emoji can drain into sink state via Lindblad operator
@export var is_drain_target: bool = false

## Drain rate to sink: κ for L_e = √κ |sink⟩⟨e|
## Rate in probability/sec (typical range: 0.01-0.5 for gentle to aggressive drain)
@export var drain_to_sink_rate: float = 0.0

## ========================================
## Bath-Projection Coupling (Environmental Interactions)
## ========================================

## Energy couplings: how projections of this emoji respond to bath observables
## Key = observable emoji in bath, Value = energy coupling strength
## Positive: projection gains energy when observable is present in bath
## Negative: projection loses energy when observable is present in bath
## Zero (or missing): no interaction
##
## Example:
##   mushroom.energy_couplings = {
##       "☀": -0.20,  # Take damage from sun (proximity-based depletion)
##       "🌙": +0.40   # Grow from moon (proximity-based growth)
##   }
##
## Physics: dE/dt = base_growth + Σ_i [coupling_i × P(obs_i)]
@export var energy_couplings: Dictionary = {}

## ========================================
## Metadata
## ========================================

## Trophic level: 0=abiotic, 1=producer, 2=consumer, 3=predator
@export var trophic_level: int = 0

## Tags for organization and querying
@export var tags: Array = []

## Special behavioral flags
@export var is_driver: bool = false      # External forcing (like sun)
@export var is_adaptive: bool = false    # Dynamically changes (like tomato)
@export var is_eternal: bool = false     # Never decays

## Named drivers for time-dependent dynamics
## Key = driver name, Value = { "type": str, "period": float, "amplitude": float, ... }
## Types: "oscillator" (periodic), "pulse" (on/off), "decay" (exponential)
@export var drivers: Dictionary = {}

## ========================================
## Methods
## ========================================

## Get effective self-energy at given time (handles time-dependent drivers)
func get_self_energy(time: float) -> float:
	var base = self_energy

	match self_energy_driver:
		"cosine":
			return base * driver_amplitude * cos(driver_frequency * time * TAU + driver_phase)
		"sine":
			return base * driver_amplitude * sin(driver_frequency * time * TAU + driver_phase)
		"pulse":
			var phase = fmod(driver_frequency * time + driver_phase / TAU, 1.0)
			return base * driver_amplitude if phase < 0.5 else 0.0
		_:
			return base

## Get all emojis this icon couples to (for building bath emoji set)
func get_coupled_emojis() -> Array:
	var result: Array = []

	for e in hamiltonian_couplings.keys():
		if not result.has(e):
			result.append(e)

	for e in lindblad_outgoing.keys():
		if not result.has(e):
			result.append(e)

	for e in lindblad_incoming.keys():
		if not result.has(e):
			result.append(e)

	if decay_rate > 0 and decay_target and not result.has(decay_target):
		result.append(decay_target)

	return result

## Create a simple icon with just couplings (utility constructor)
static func create_simple(emoji_str: String, couplings: Dictionary = {}, transfers: Dictionary = {}):
	var icon_class = load("res://Core/QuantumSubstrate/Icon.gd")
	var icon = icon_class.new()
	icon.emoji = emoji_str
	icon.display_name = emoji_str
	icon.hamiltonian_couplings = couplings
	icon.lindblad_outgoing = transfers
	return icon
