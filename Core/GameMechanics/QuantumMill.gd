class_name QuantumMill
extends Node2D

## QuantumMill v3: Coupling Injector
##
## Mill connects a power source to a conversion process via Hamiltonian coupling.
## Two-stage configuration: player selects power source, then conversion type.
##
## Power Sources (Stage 1):
##   Q = 💧 Water
##   E = 🌬️ Wind
##   R = 🔥 Fire
##
## Conversions (Stage 2):
##   Q = 🌾→💨 Wheat→Flour
##   E = 🌲→🪵 Trees→Lumber
##   R = 🍂→⚡ Organic→Energy
##
## Coupling Strength: J_effective = J_base × P(power_source)
## The stronger the power source probability, the stronger the coupling.

signal coupling_injected(power: String, source: String, product: String)

## Configuration
var grid_position: Vector2i = Vector2i.ZERO
var parent_biome = null
var is_active: bool = false

## Configured coupling (set after two-stage selection)
var power_emoji: String = ""      # 💧, 🌬️, or 🔥
var source_emoji: String = ""     # 🌾, 🌲, or 🍂
var product_emoji: String = ""    # 💨, 🪵, or ⚡

## Coupling strength
const BASE_COUPLING_STRENGTH: float = 0.5

## Statistics
var injection_time: float = 0.0
var coupling_strength: float = 0.0

## Power source definitions
const POWER_SOURCES = {
	"Q": {"emoji": "💧", "label": "Water"},
	"E": {"emoji": "🌬️", "label": "Wind"},
	"R": {"emoji": "🔥", "label": "Fire"},
}

## Conversion definitions (source → product)
const CONVERSIONS = {
	"Q": {"source": "🌾", "product": "💨", "label": "Flour"},
	"E": {"source": "🌲", "product": "🪵", "label": "Lumber"},
	"R": {"source": "🍂", "product": "⚡", "label": "Energy"},
}


func _ready():
	print("🏭 QuantumMill initialized at %s" % grid_position)


## ========================================
## Availability Checks (for UI highlighting)
## ========================================

func get_power_availability(biome) -> Dictionary:
	"""Check which power sources exist in the biome's register_map.

	Used by UI to highlight available options vs unavailable (dimmed).

	Args:
		biome: BiomeBase to check

	Returns:
		{"Q": bool, "E": bool, "R": bool}
	"""
	if not biome or not biome.quantum_computer:
		return {"Q": false, "E": false, "R": false}

	var rm = biome.quantum_computer.register_map
	return {
		"Q": rm.has(POWER_SOURCES["Q"].emoji),
		"E": rm.has(POWER_SOURCES["E"].emoji),
		"R": rm.has(POWER_SOURCES["R"].emoji),
	}


func get_conversion_availability(biome) -> Dictionary:
	"""Check which conversions are possible in the biome.

	Both source AND product must exist in register_map for conversion to work.
	Used by UI to highlight available options vs unavailable (dimmed).

	Args:
		biome: BiomeBase to check

	Returns:
		{"Q": bool, "E": bool, "R": bool}
	"""
	if not biome or not biome.quantum_computer:
		return {"Q": false, "E": false, "R": false}

	var rm = biome.quantum_computer.register_map
	return {
		"Q": rm.has(CONVERSIONS["Q"].source) and rm.has(CONVERSIONS["Q"].product),
		"E": rm.has(CONVERSIONS["E"].source) and rm.has(CONVERSIONS["E"].product),
		"R": rm.has(CONVERSIONS["R"].source) and rm.has(CONVERSIONS["R"].product),
	}


## ========================================
## Configuration (Two-Stage Selection)
## ========================================

func configure(biome, power_key: String, conversion_key: String) -> Dictionary:
	"""Configure and activate the mill coupling.

	Called after two-stage selection completes.

	Args:
		biome: Parent biome reference
		power_key: "Q", "E", or "R" for power source
		conversion_key: "Q", "E", or "R" for conversion type

	Returns:
		Dictionary with success/error keys
	"""
	if not POWER_SOURCES.has(power_key):
		return {"success": false, "error": "invalid_power_key", "key": power_key}
	if not CONVERSIONS.has(conversion_key):
		return {"success": false, "error": "invalid_conversion_key", "key": conversion_key}

	parent_biome = biome

	if not parent_biome:
		return {"success": false, "error": "no_biome"}
	if not parent_biome.quantum_computer:
		return {"success": false, "error": "no_quantum_computer"}

	# Set emoji references
	power_emoji = POWER_SOURCES[power_key].emoji
	source_emoji = CONVERSIONS[conversion_key].source
	product_emoji = CONVERSIONS[conversion_key].product

	# Verify all emojis exist in register_map
	var rm = parent_biome.quantum_computer.register_map
	for emoji in [power_emoji, source_emoji, product_emoji]:
		if not rm.has(emoji):
			return {"success": false, "error": "missing_emoji", "emoji": emoji}

	# Calculate effective coupling strength: J_base × P(power_source)
	var power_prob = parent_biome.quantum_computer.get_population(power_emoji)
	coupling_strength = BASE_COUPLING_STRENGTH * max(power_prob, 0.1)  # Minimum 10% of base

	# Inject coupling between source and product
	var result = parent_biome.inject_coupling(source_emoji, product_emoji, coupling_strength)

	if result.success:
		is_active = true
		injection_time = Time.get_ticks_msec() / 1000.0
		coupling_injected.emit(power_emoji, source_emoji, product_emoji)
		print("🏭 Mill active: %s powers %s→%s (J=%.3f)" % [
			power_emoji, source_emoji, product_emoji, coupling_strength])
	else:
		print("🏭 Mill failed: %s" % result.get("error", "unknown"))

	return result


## ========================================
## Legacy Activation (Backwards Compatibility)
## ========================================

func activate(biome) -> bool:
	"""Legacy activation method.

	Attempts default configuration: 💧 Water → 🌾→💨 Flour

	Args:
		biome: Parent biome

	Returns:
		true if successful, false otherwise
	"""
	var result = configure(biome, "Q", "Q")  # Water + Wheat→Flour
	return result.success


## ========================================
## Status
## ========================================

func get_status() -> String:
	"""Get human-readable status."""
	if not is_active:
		return "Inactive"
	return "%s powers %s→%s (J=%.2f)" % [power_emoji, source_emoji, product_emoji, coupling_strength]


func get_debug_info() -> Dictionary:
	"""Return mill state for debugging."""
	return {
		"position": grid_position,
		"is_active": is_active,
		"power": power_emoji,
		"source": source_emoji,
		"product": product_emoji,
		"coupling_strength": coupling_strength,
		"parent_biome": parent_biome.get_biome_type() if parent_biome else "none",
		"injection_time": injection_time,
	}


func is_working() -> bool:
	"""Check if mill is actively providing coupling."""
	return is_active


## ========================================
## Static Helpers (for UI without instance)
## ========================================

static func check_power_availability(biome) -> Dictionary:
	"""Static version of get_power_availability for UI use."""
	if not biome or not biome.quantum_computer:
		return {"Q": false, "E": false, "R": false}

	var rm = biome.quantum_computer.register_map
	return {
		"Q": rm.has(POWER_SOURCES["Q"].emoji),
		"E": rm.has(POWER_SOURCES["E"].emoji),
		"R": rm.has(POWER_SOURCES["R"].emoji),
	}


static func check_conversion_availability(biome) -> Dictionary:
	"""Static version of get_conversion_availability for UI use."""
	if not biome or not biome.quantum_computer:
		return {"Q": false, "E": false, "R": false}

	var rm = biome.quantum_computer.register_map
	return {
		"Q": rm.has(CONVERSIONS["Q"].source) and rm.has(CONVERSIONS["Q"].product),
		"E": rm.has(CONVERSIONS["E"].source) and rm.has(CONVERSIONS["E"].product),
		"R": rm.has(CONVERSIONS["R"].source) and rm.has(CONVERSIONS["R"].product),
	}
