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

## Name of the biome this terminal is probing (decoupled from object reference)
var bound_biome_name: String = ""

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

## Purity snapshot captured when the register was measured
var measured_purity: float = 1.0
var measured_register_id: int = -1
var measured_biome_name: String = ""
var measured_snapshot: Dictionary = {}

## Frozen screen position (set on MEASURE, used by visualization)
## When measured, bubble should snap to this position instead of floating
var frozen_position: Vector2 = Vector2.ZERO


func _init(id: String = ""):
	terminal_id = id if id else "T_%d" % randi()


## Bind this terminal to a register in a biome
## biome_name: String name of the biome (decoupled from object reference)
func bind_to_register(register_id: int, biome_name: String, emoji_pair: Dictionary = {}) -> void:
	if is_bound:
		push_warning("Terminal %s already bound to register %d" % [terminal_id, bound_register_id])
		return

	bound_register_id = register_id
	bound_biome_name = biome_name  # String, not Node
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

	bound.emit(register_id, biome_name)
	state_changed.emit(self)


## Unbind this terminal from its register
func unbind() -> void:
	if not is_bound:
		return

	var _old_register = bound_register_id

	bound_register_id = -1
	bound_biome_name = ""
	is_bound = false
	is_measured = false
	measured_outcome = ""
	measured_probability = 0.0
	measured_purity = 1.0
	measured_register_id = -1
	measured_biome_name = ""
	measured_snapshot.clear()
	current_emoji = ""
	north_emoji = ""
	south_emoji = ""
	grid_position = Vector2i(-1, -1)
	frozen_position = Vector2.ZERO

	unbound.emit()
	state_changed.emit(self)


## Mark this terminal as measured with the given outcome
func mark_measured(outcome: String, probability: float = 0.0, purity: float = 1.0, snapshot: Dictionary = {}) -> void:
	if not is_bound:
		push_warning("Cannot measure unbound terminal %s" % terminal_id)
		return

	is_measured = true
	measured_outcome = outcome
	measured_probability = probability
	current_emoji = outcome  # Update display to show collapsed state
	measured_purity = purity
	measured_register_id = bound_register_id
	measured_biome_name = bound_biome_name
	measured_snapshot = snapshot.duplicate() if snapshot else {}

	measured.emit(outcome)
	state_changed.emit(self)


## Release the quantum register while keeping the measurement snapshot
## This allows the register to be explored and measured again by another terminal
func release_register() -> void:
	"""Free the quantum register but keep measurement data on terminal.

	After MEASURE:
	- Register becomes available for another terminal to bind to
	- This terminal keeps its measurement result (outcome + probability)
	- Terminal stays on the grid showing the frozen measurement

	This enables multiple measurements of the same quantum axis by chunking
	probability across multiple measurement cycles.
	"""
	if not is_bound:
		return

	bound_register_id = -1
	bound_biome_name = ""
	is_bound = false
	# KEEP: is_measured, measured_outcome, measured_probability (the measurement snapshot)
	# KEEP: grid_position (terminal stays visible on grid)
	# KEEP: north_emoji, south_emoji (reference for the measurement basis)

	state_changed.emit(self)


func clear_measurement() -> void:
	"""Clear the measured state while remaining bound."""
	if not is_measured:
		return

	is_measured = false
	measured_outcome = ""
	measured_probability = 0.0
	measured_purity = 1.0
	measured_register_id = -1
	measured_biome_name = ""
	measured_snapshot.clear()
	current_emoji = north_emoji if north_emoji != "" else "?"
	frozen_position = Vector2.ZERO
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
		"measured_snapshot": measured_snapshot,
		"current_emoji": current_emoji,
		"north_emoji": north_emoji,
		"south_emoji": south_emoji,
		"biome_name": bound_biome_name
	}


## Get the emoji that should be displayed
func get_display_emoji() -> String:
	if is_measured:
		return measured_outcome
	elif is_bound:
		return current_emoji if current_emoji else "?"
	else:
		return ""


## Get the emoji pair for this terminal's bound register
func get_emoji_pair() -> Dictionary:
	return {"north": north_emoji, "south": south_emoji}


## Get complete binding information for queries
func get_binding_info() -> Dictionary:
	return {
		"is_bound": is_bound,
		"register_id": bound_register_id,
		"biome_name": bound_biome_name,
		"grid_position": grid_position,
		"emoji_pair": get_emoji_pair(),
		"is_measured": is_measured,
		"measured_outcome": measured_outcome,
		"measured_probability": measured_probability
	}


## Check if this terminal can be used for EXPLORE action
func can_explore() -> bool:
	return not is_bound


## Check if this terminal can be used for MEASURE action
func can_measure() -> bool:
	return is_bound and not is_measured


## Check if this terminal can be used for POP action
func can_pop() -> bool:
	return is_measured


## Validate that terminal state is internally consistent
## Returns error message if invalid state detected, empty string if valid
func validate_state() -> String:
	# Valid state combinations:
	# UNBOUND: is_bound=false, is_measured=false
	# BOUND: is_bound=true, is_measured=false, bound_register_id>=0
	# MEASURED: is_bound=true, is_measured=true, measured_outcome!=""

	if not is_bound:
		# Unbound state should have no register
		if bound_register_id != -1:
			return "INVALID: unbound but has register_id"
		if bound_biome_name != "":
			return "INVALID: unbound but has biome name"

		if is_measured:
			# Allow measured snapshot even though terminal is unbound
			if measured_outcome.is_empty():
				return "INVALID: measured but no outcome recorded"
			if measured_probability <= 0.0:
				return "INVALID: measured but probability not set"
			return ""

		return ""

	# Bound state (is_bound=true)
	if bound_register_id < 0:
		return "INVALID: bound but register_id invalid"
	if bound_biome_name == "":
		return "INVALID: bound but no biome name"

	if is_measured:
		# Measured state requires outcome
		if measured_outcome.is_empty():
			return "INVALID: measured but no outcome recorded"
		if measured_probability <= 0.0:
			return "INVALID: measured but probability not set"
	else:
		# Bound but not measured - should have emojis
		if north_emoji.is_empty() or south_emoji.is_empty():
			return "INVALID: bound but no emojis set"

	return ""


## String representation for debugging
func _to_string() -> String:
	if not is_bound:
		return "Terminal[%s]: UNBOUND" % terminal_id
	elif is_measured:
		return "Terminal[%s]: MEASURED(%s, p=%.2f)" % [terminal_id, measured_outcome, measured_probability]
	else:
		return "Terminal[%s]: BOUND(reg=%d, %s/%s)" % [terminal_id, bound_register_id, north_emoji, south_emoji]
