class_name Terminal
extends RefCounted

## Terminal - Generic probe into the quantum soup (v2 Architecture)
##
## Replaces coordinate-based FarmPlot with ID-based binding to Registers.
## Terminals are probes that bind to registers in a biome's quantum bath.
##
## Lifecycle:
##   1. UNBOUND: Terminal exists but is not probing anything
##   2. BOUND: Terminal bound to a register via EXPLORE action
##   3. MEASURED: Terminal has been measured but not harvested (frozen bubble)
##   4. POP → returns to UNBOUND
##
## Terminology:
##   Terminal = Player-facing "Plot" (generic hardware port)
##   Register = DualEmojiQubit within a biome's quantum bath

signal state_changed(terminal: Terminal)
signal bound(register_id: int, biome: Variant)
signal unbound()
signal measured(outcome: String)

## Unique identifier for this terminal (e.g., "T_01", "T_02")
var terminal_id: String = ""

## Bound register ID (-1 if unbound)
var bound_register_id: int = -1

## Reference to the biome this terminal is probing
var bound_biome = null  # BiomeBase (Node)

## Current emoji being displayed (from register or measurement outcome)
var current_emoji: String = ""

## North/South emoji pair from bound register
var north_emoji: String = ""
var south_emoji: String = ""

## State flags
var is_bound: bool = false
var is_measured: bool = false

## Grid position where this terminal's bubble is displayed
## Set when EXPLORE places the bubble, cleared when POP removes it
var grid_position: Vector2i = Vector2i(-1, -1)

## Result of measurement (emoji outcome)
var measured_outcome: String = ""

## Recorded probability at MEASURE time - the "claim"
## This is what POP will convert to credits, regardless of how ρ evolves
## Ensemble model: this represents the snapshot we took from the ensemble
var measured_probability: float = 0.0


func _init(id: String = ""):
	terminal_id = id if id else "T_%d" % randi()


## Bind this terminal to a register in a biome
func bind_to_register(register_id: int, biome, emoji_pair: Dictionary = {}) -> void:
	if is_bound:
		push_warning("Terminal %s already bound to register %d" % [terminal_id, bound_register_id])
		return

	bound_register_id = register_id
	bound_biome = biome
	is_bound = true
	is_measured = false
	measured_outcome = ""

	# Store emoji pair if provided
	if emoji_pair.has("north"):
		north_emoji = emoji_pair["north"]
	if emoji_pair.has("south"):
		south_emoji = emoji_pair["south"]

	# Set current emoji to north (default display before measurement)
	current_emoji = north_emoji if north_emoji else "?"

	bound.emit(register_id, biome)
	state_changed.emit(self)


## Unbind this terminal from its register
func unbind() -> void:
	if not is_bound:
		return

	var old_register = bound_register_id

	bound_register_id = -1
	bound_biome = null
	is_bound = false
	is_measured = false
	measured_outcome = ""
	measured_probability = 0.0
	current_emoji = ""
	north_emoji = ""
	south_emoji = ""
	grid_position = Vector2i(-1, -1)

	unbound.emit()
	state_changed.emit(self)


## Mark this terminal as measured with the given outcome
func mark_measured(outcome: String, probability: float = 0.0) -> void:
	if not is_bound:
		push_warning("Cannot measure unbound terminal %s" % terminal_id)
		return

	is_measured = true
	measured_outcome = outcome
	measured_probability = probability
	current_emoji = outcome  # Update display to show collapsed state

	measured.emit(outcome)
	state_changed.emit(self)


## Reset terminal to initial state (full cleanup)
func reset() -> void:
	unbind()


## Get current state as dictionary (for serialization/debugging)
func get_state() -> Dictionary:
	return {
		"terminal_id": terminal_id,
		"is_bound": is_bound,
		"bound_register_id": bound_register_id,
		"is_measured": is_measured,
		"measured_outcome": measured_outcome,
		"measured_probability": measured_probability,
		"current_emoji": current_emoji,
		"north_emoji": north_emoji,
		"south_emoji": south_emoji,
		"biome_name": bound_biome.get_biome_type() if bound_biome else ""
	}


## Get the emoji that should be displayed
func get_display_emoji() -> String:
	if is_measured:
		return measured_outcome
	elif is_bound:
		return current_emoji if current_emoji else "?"
	else:
		return ""


## Check if this terminal can be used for EXPLORE action
func can_explore() -> bool:
	return not is_bound


## Check if this terminal can be used for MEASURE action
func can_measure() -> bool:
	return is_bound and not is_measured


## Check if this terminal can be used for POP action
func can_pop() -> bool:
	return is_bound and is_measured


## String representation for debugging
func _to_string() -> String:
	if not is_bound:
		return "Terminal[%s]: UNBOUND" % terminal_id
	elif is_measured:
		return "Terminal[%s]: MEASURED(%s, p=%.2f)" % [terminal_id, measured_outcome, measured_probability]
	else:
		return "Terminal[%s]: BOUND(reg=%d, %s/%s)" % [terminal_id, bound_register_id, north_emoji, south_emoji]
