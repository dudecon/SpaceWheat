class_name BasePlot
extends Resource

## BasePlot - Foundation class for all farm plots (Thin Plot Architecture)
##
## Terminal is the single source of truth for game mechanics state.
## Plot keeps only visual projection + infrastructure.
##
## Accessors delegate to bound_terminal:
##   get_register_id(), get_biome_name(), is_active(),
##   get_north_emoji(), get_south_emoji(),
##   get_is_measured(), get_measured_outcome()

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")


## Safely log via VerboseConfig (Resource can't use @onready)
func _log(level: String, category: String, emoji: String, message: String) -> void:
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		return
	var verbose = tree.root.get_node_or_null("/root/VerboseConfig")
	if not verbose:
		return
	match level:
		"info":
			verbose.info(category, emoji, message)
		"debug":
			verbose.debug(category, emoji, message)
		"warn":
			verbose.warn(category, emoji, message)

signal growth_complete
signal state_collapsed(final_state: String)

# ============================================================================
# IDENTITY (kept on plot)
# ============================================================================

@export var plot_id: String = ""
@export var grid_position: Vector2i = Vector2i.ZERO

# ============================================================================
# TERMINAL BINDING (single source of truth for game mechanics)
# ============================================================================

## Reference to bound terminal — source of truth for register_id, biome,
## emoji pair, measurement state, and outcome.
var bound_terminal = null  # Terminal instance

## Cached biome Node (resolved from bound_terminal.bound_biome_name)
var _cached_biome = null

# ============================================================================
# INFRASTRUCTURE (computed from register_infrastructure — survives harvest/replant)
# ============================================================================

## theta_frozen: delegates to register_infrastructure
var theta_frozen: bool:
	get: return _get_infra_field("theta_frozen", false)
	set(value): _set_infra_field("theta_frozen", value)

# Positional — NOT per-register
@export var replant_cycles: int = 0

# Entanglement tracking (updated via parent_biome quantum computer)
var entangled_plots: Dictionary = {}  # plot_id -> strength
const MAX_ENTANGLEMENTS = 3

## persistent_gates: delegates to register_infrastructure
var persistent_gates: Array[Dictionary]:
	get:
		var raw = _get_infra_field("persistent_gates", [])
		var typed: Array[Dictionary] = []
		for g in raw:
			typed.append(g)
		return typed
	set(value): _set_infra_field("persistent_gates", value)

## Lindblad computed properties — delegate to register_infrastructure
var lindblad_pump_active: bool:
	get: return _get_infra_field("lindblad_pump_active", false)
	set(value): _set_infra_field("lindblad_pump_active", value)

var lindblad_drain_active: bool:
	get: return _get_infra_field("lindblad_drain_active", false)
	set(value): _set_infra_field("lindblad_drain_active", value)

var lindblad_pump_rate: float:
	get: return _get_infra_field("lindblad_pump_rate", 0.5)
	set(value): _set_infra_field("lindblad_pump_rate", value)

var lindblad_drain_rate: float:
	get: return _get_infra_field("lindblad_drain_rate", 0.5)
	set(value): _set_infra_field("lindblad_drain_rate", value)

var lindblad_drain_accumulator: float:
	get: return _get_infra_field("lindblad_drain_accumulator", 0.0)
	set(value): _set_infra_field("lindblad_drain_accumulator", value)


func _init():
	plot_id = "plot_%d" % randi()


# ============================================================================
# TERMINAL ACCESSORS (delegate to bound_terminal)
# ============================================================================

func get_register_id() -> int:
	return bound_terminal.bound_register_id if bound_terminal else -1

func get_biome_name() -> String:
	return bound_terminal.bound_biome_name if bound_terminal else ""

func is_active() -> bool:
	return bound_terminal != null and bound_terminal.is_bound

func get_north_emoji() -> String:
	return bound_terminal.north_emoji if bound_terminal else ""

func get_south_emoji() -> String:
	return bound_terminal.south_emoji if bound_terminal else ""

func get_is_measured() -> bool:
	return bound_terminal.is_measured if bound_terminal else false

func get_measured_outcome() -> String:
	return bound_terminal.measured_outcome if bound_terminal else ""

# ============================================================================
# BIOME RESOLUTION (cached from terminal binding)
# ============================================================================

func _resolve_biome():
	"""Resolve biome Node from bound_terminal.bound_biome_name."""
	if _cached_biome:
		return _cached_biome
	if not bound_terminal:
		return null
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		var abm = tree.root.get_node_or_null("/root/ActiveBiomeManager")
		if abm and abm.has_method("get_biome_by_name"):
			_cached_biome = abm.get_biome_by_name(bound_terminal.bound_biome_name)
			return _cached_biome
		# Fallback: try farm.grid.biomes
		var farm = tree.root.get_node_or_null("Farm")
		if farm and farm.grid and "biomes" in farm.grid:
			_cached_biome = farm.grid.biomes.get(bound_terminal.bound_biome_name)
			return _cached_biome
	return null


func _resolve_quantum_computer():
	var biome = _resolve_biome()
	if biome and "quantum_computer" in biome and biome.quantum_computer:
		return biome.quantum_computer
	return null


func _get_infra_field(field: String, default = null):
	if not bound_terminal or bound_terminal.bound_register_id < 0:
		return default
	var qc = _resolve_quantum_computer()
	if not qc: return default
	return qc.get_register_infra_field(bound_terminal.bound_register_id, field, default)


func _set_infra_field(field: String, value) -> void:
	if not bound_terminal or bound_terminal.bound_register_id < 0: return
	var qc = _resolve_quantum_computer()
	if not qc: return
	qc.set_register_infra_field(bound_terminal.bound_register_id, field, value)

# ============================================================================
# BACKWARD-COMPATIBLE PROPERTIES
# These allow existing code to read plot.is_planted, plot.register_id, etc.
# without changing every caller at once. They delegate to bound_terminal.
# ============================================================================

## is_planted: true when terminal is bound (backward compat)
var is_planted: bool:
	get:
		return is_active()
	set(value):
		pass  # No-op: terminal binding is the source of truth

## register_id: from bound terminal (backward compat)
var register_id: int:
	get:
		return get_register_id()
	set(value):
		pass  # No-op: terminal binding is the source of truth

## parent_biome: resolved from terminal's biome name (backward compat)
var parent_biome:
	get:
		return _resolve_biome()
	set(value):
		_cached_biome = value  # Allow explicit set for legacy code paths

## north_emoji: from bound terminal (backward compat)
var north_emoji: String:
	get:
		return get_north_emoji()
	set(value):
		pass  # No-op: terminal binding is the source of truth

## south_emoji: from bound terminal (backward compat)
var south_emoji: String:
	get:
		return get_south_emoji()
	set(value):
		pass  # No-op: terminal binding is the source of truth

## has_been_measured: from bound terminal (backward compat)
var has_been_measured: bool:
	get:
		return get_is_measured()
	set(value):
		pass  # No-op: terminal binding is the source of truth

## measured_outcome: from bound terminal (backward compat)
var measured_outcome: String:
	get:
		return get_measured_outcome()
	set(value):
		pass  # No-op: terminal binding is the source of truth

# ============================================================================
# QUANTUM STATE ACCESS (Computed from Terminal → Biome's Bath)
# ============================================================================

## Get basis labels for this plot's measurement basis
func get_basis_labels() -> Array[String]:
	return [get_north_emoji(), get_south_emoji()]

## Get purity from parent biome's quantum computer
func get_purity() -> float:
	"""Query purity from parent biome's quantum computer."""
	if not is_active():
		return 0.0
	var biome = _resolve_biome()
	if not biome or not biome.viz_cache:
		return 0.0
	var purity = biome.viz_cache.get_purity()
	return purity if purity >= 0.0 else 0.0

## Get coherence from parent biome's quantum computer
func get_coherence() -> float:
	"""Query coherence from parent biome's quantum computer."""
	if not is_active():
		return 0.0
	var biome = _resolve_biome()
	if not biome or not biome.viz_cache:
		return 0.0
	var q = biome.viz_cache.get_qubit(get_north_emoji())
	if q < 0:
		return 0.0
	var bloch = biome.viz_cache.get_bloch(q)
	if bloch.is_empty():
		return 0.0
	var x = bloch.get("x", 0.0)
	var y = bloch.get("y", 0.0)
	return 0.5 * sqrt(x * x + y * y)

## Get mass (probability in subspace)
func get_mass() -> float:
	"""Get probability mass in measurement basis subspace."""
	if not is_active():
		return 0.0
	var biome = _resolve_biome()
	if not biome or not biome.viz_cache:
		return 0.0
	var q = biome.viz_cache.get_qubit(get_north_emoji())
	if q < 0:
		return 0.0
	var snap = biome.viz_cache.get_snapshot(q)
	if snap.is_empty():
		return 0.0
	var p_north = snap.get("p0", 0.5)
	var p_south = snap.get("p1", 0.5)
	return p_north + p_south

## Core Methods

func get_dominant_emoji() -> String:
	"""Get the current outcome emoji (measured or dominant basis state)."""
	if get_is_measured() and get_measured_outcome() != "":
		return get_measured_outcome()
	return get_north_emoji() if (randf() < 0.5) else get_south_emoji()


func get_plot_emojis() -> Dictionary:
	"""Get the dual-emoji pair for this plot.

	Delegates to bound_terminal when available.
	Falls back to biome capabilities or empty dict.
	"""
	if bound_terminal and bound_terminal.is_bound:
		return bound_terminal.get_emoji_pair()

	var biome = _resolve_biome()
	if biome and biome.has_method("get_plantable_capabilities"):
		var type_name = get("plot_type_name")
		if type_name:
			for cap in biome.get_plantable_capabilities():
				if cap.plant_type == type_name:
					return cap.emoji_pair

	return {"north": get_north_emoji(), "south": get_south_emoji()}


## Is this plot measured? Delegates to bound_terminal.
func is_measured() -> bool:
	return get_is_measured()


## Is this plot occupied (bound to a terminal)?
func is_occupied() -> bool:
	return is_active()


func register_in_biome(biome: Node) -> bool:
	"""Register this plot's measurement axis in the biome's quantum computer.

	Called by FarmGrid.plant() after emoji pairs are set.
	Caches biome reference for _resolve_biome().
	"""
	if not biome or not "quantum_computer" in biome or not biome.quantum_computer:
		push_error("Biome has no quantum_computer for plot %s!" % grid_position)
		return false

	_cached_biome = biome

	# Get register_id - axis should already exist from expand_quantum_system
	var reg_id = -1
	var n_emoji = get_north_emoji()
	if biome.viz_cache:
		reg_id = biome.viz_cache.get_qubit(n_emoji)
	if reg_id < 0 and biome.quantum_computer and biome.quantum_computer.register_map:
		if biome.quantum_computer.register_map.has(n_emoji):
			reg_id = biome.quantum_computer.register_map.qubit(n_emoji)
	if reg_id < 0:
		push_error("Axis %s/%s not found in quantum computer - was expand_quantum_system called?" % [
			get_north_emoji(), get_south_emoji()])
		return false

	_log("debug", "farm", "~", "Plot %s: registered axis %d (%s/%s) in %s" % [
		grid_position, reg_id, get_north_emoji(), get_south_emoji(), biome.get_biome_type()])
	return true


func measure(_icon_network = null) -> String:
	"""Measure (collapse) quantum state at this plot.

	Delegates to parent biome's quantum_computer.measure_axis().
	"""
	var biome = _resolve_biome()
	if not biome:
		push_error("Plot %s not properly planted - no parent biome!" % grid_position)
		return ""

	if not is_active():
		push_error("Cannot measure unplanted plot!")
		return ""

	if get_is_measured():
		var outcome = get_measured_outcome()
		push_warning("Plot %s already measured - outcome: %s" % [grid_position, outcome])
		if outcome == get_north_emoji():
			return "north"
		elif outcome == get_south_emoji():
			return "south"
		return outcome

	if not biome.quantum_computer:
		push_error("Parent biome %s has no quantum_computer!" % biome.get_biome_type())
		return ""

	var outcome_emoji = biome.quantum_computer.measure_axis(get_north_emoji(), get_south_emoji())

	if outcome_emoji == "":
		push_error("Measurement failed for plot %s!" % grid_position)
		return ""

	var basis_outcome = "north" if outcome_emoji == get_north_emoji() else "south"

	_log("debug", "farm", "~", "Plot %s measured: outcome=%s (emoji: %s)" % [grid_position, basis_outcome, outcome_emoji])

	return basis_outcome


func harvest() -> Dictionary:
	"""Harvest this plot - collect yield and clear quantum state."""
	if not is_active():
		return {"success": false, "yield": 0, "energy": 0.0}

	var biome = _resolve_biome()
	if not biome:
		return {"success": false, "yield": 0, "energy": 0.0}

	var outcome = ""

	if not get_is_measured():
		measure()

	if not get_is_measured():
		return {"success": false, "yield": 0, "energy": 0.0}

	var measured = get_measured_outcome()
	if measured == "north" or measured == get_north_emoji():
		outcome = get_north_emoji()
	elif measured == "south" or measured == get_south_emoji():
		outcome = get_south_emoji()
	else:
		outcome = measured if measured != "" else "?"

	var purity = get_purity()
	if purity == 0.0:
		purity = 1.0

	var purity_multiplier = 2.0 * purity
	var base_yield = 10.0
	var yield_with_purity = base_yield * purity_multiplier
	var yield_amount = max(1, int(yield_with_purity))

	replant_cycles += 1

	if biome.has_method("clear_subplot_for_plot"):
		biome.clear_subplot_for_plot(grid_position)

	var result_dict = {
		"success": true,
		"outcome": outcome,
		"energy": base_yield,
		"yield": yield_amount,
		"purity": purity,
		"purity_multiplier": purity_multiplier
	}

	_log("debug", "farm", "~", "Plot %s harvested: purity=%.3f (x%.2f), outcome=%s, yield=%d" % [
		grid_position, purity, purity_multiplier, outcome, yield_amount])

	return result_dict


func collapse_to_measurement(outcome: String) -> void:
	"""Legacy: No-op in thin plot architecture.
	Measurement state lives on Terminal, not Plot."""
	state_collapsed.emit(outcome)


func reset() -> void:
	"""Reset plot to initial state.
	NOTE: Infrastructure (gates, lindblad, etc.) lives on register_infrastructure
	and naturally survives harvest/replant."""
	bound_terminal = null
	_cached_biome = null
	entangled_plots.clear()


func remove_entanglement(partner_id: String) -> void:
	"""Remove entanglement with a specific plot.
	Called when breaking entanglement or when partner plot is harvested."""
	if entangled_plots.has(partner_id):
		entangled_plots.erase(partner_id)


# ============================================================================
# PERSISTENT GATE INFRASTRUCTURE
# ============================================================================

func add_persistent_gate(gate_type: String, linked_plots: Array[Vector2i] = []) -> void:
	"""Add a persistent gate to this plot. Gates survive harvest/replant."""
	if not bound_terminal or bound_terminal.bound_register_id < 0: return
	var qc = _resolve_quantum_computer()
	if not qc: return
	qc.add_persistent_gate_to_register(bound_terminal.bound_register_id, gate_type, [])
	_log("debug", "farm", "🔧", "Added persistent gate '%s' to plot %s (linked: %d plots)" % [gate_type, grid_position, linked_plots.size()])


func clear_persistent_gates() -> void:
	"""Remove ALL persistent gate infrastructure from this plot."""
	var count = persistent_gates.size()
	_set_infra_field("persistent_gates", [])
	if count > 0:
		_log("debug", "farm", "🔧", "Cleared %d persistent gates from plot %s" % [count, grid_position])


func has_active_gate(gate_type: String) -> bool:
	"""Check if this plot has an active gate of the specified type."""
	for gate in persistent_gates:
		if gate.get("type", "") == gate_type and gate.get("active", false):
			return true
	return false


func get_active_gates() -> Array[Dictionary]:
	"""Get all active persistent gates on this plot."""
	var active: Array[Dictionary] = []
	for gate in persistent_gates:
		if gate.get("active", false):
			active.append(gate)
	return active
