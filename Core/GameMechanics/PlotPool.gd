class_name PlotPool
extends RefCounted

## PlotPool - Pool of generic terminals for quantum soup probing (v2 Architecture)
##
## Manages a pool of Terminal objects and tracks their binding state to registers.
## Enforces the unique binding constraint: each register can only be bound by ONE terminal.
##
## Key Features:
##   - Pool of N terminals (configurable)
##   - Binding table: terminal_id → register_id
##   - Reverse binding: register_id → terminal_id
##   - Unique binding constraint enforcement
##
## Usage:
##   var pool = PlotPool.new(12)  # Create pool with 12 terminals
##   var terminal = pool.get_unbound_terminal()  # Get first available
##   pool.bind_terminal(terminal, register_id, biome)  # Bind to register
##   pool.unbind_terminal(terminal)  # Release binding

signal terminal_bound(terminal: RefCounted, register_id: int)
signal terminal_measured(terminal: RefCounted, outcome: String)
signal terminal_unbound(terminal: RefCounted)
signal pool_exhausted()  # Emitted when all terminals are bound
signal pool_available()  # Emitted when at least one terminal becomes available

const TerminalClass = preload("res://Core/GameMechanics/Terminal.gd")

## Pool of all terminals (Array of Terminal instances)
var terminals: Array = []

## Binding tables (DEPRECATED - kept for backward compatibility)
## V2 Architecture: Query Terminal directly instead of these tables
## Terminal is the single source of truth for binding state
var binding_table: Dictionary = {}  # terminal_id → {register_id, biome_name}
var reverse_binding: Dictionary = {}  # "biome_name:register_id" → terminal_id

## Pool configuration
var pool_size: int = 12  # Default number of terminals


func _init(size: int = 12):
	pool_size = size
	_initialize_pool()


func _initialize_pool() -> void:
	terminals.clear()
	binding_table.clear()
	reverse_binding.clear()

	for i in range(pool_size):
		var terminal = TerminalClass.new("T_%02d" % i)
		terminal.state_changed.connect(_on_terminal_state_changed)
		terminal.measured.connect(_on_terminal_measured.bind(terminal))
		terminals.append(terminal)


## Get the first unbound terminal, or null if all are bound
func get_unbound_terminal() -> RefCounted:
	for terminal in terminals:
		if not terminal.is_bound:
			return terminal
	return null


## Get all unbound terminals
func get_unbound_terminals() -> Array:
	var result: Array = []
	for terminal in terminals:
		if not terminal.is_bound:
			result.append(terminal)
	return result


## Get all bound terminals
func get_bound_terminals() -> Array:
	var result: Array = []
	for terminal in terminals:
		if terminal.is_bound:
			result.append(terminal)
	return result


## Get terminal by ID
func get_terminal(terminal_id: String) -> RefCounted:
	for terminal in terminals:
		if terminal.terminal_id == terminal_id:
			return terminal
	return null


## Get terminal bound to a specific register
func get_terminal_for_register(register_id: int, biome_name: String) -> RefCounted:
	var key = "%s:%d" % [biome_name, register_id]
	if reverse_binding.has(key):
		return get_terminal(reverse_binding[key])
	return null


## Bind a terminal to a register in a biome
## Returns true if binding succeeded, false if constraint violated
func bind_terminal(terminal: RefCounted, register_id: int, biome, emoji_pair: Dictionary = {}) -> bool:
	if terminal.is_bound:
		push_warning("Terminal %s already bound" % terminal.terminal_id)
		return false

	var biome_name = biome.get_biome_type() if biome else "unknown"
	var reverse_key = "%s:%d" % [biome_name, register_id]

	# Check unique binding constraint
	if reverse_binding.has(reverse_key):
		push_warning("Register %d in %s already bound to terminal %s" % [
			register_id, biome_name, reverse_binding[reverse_key]
		])
		return false

	# Perform binding
	terminal.bind_to_register(register_id, biome, emoji_pair)

	# Update binding tables
	binding_table[terminal.terminal_id] = {
		"register_id": register_id,
		"biome_name": biome_name
	}
	reverse_binding[reverse_key] = terminal.terminal_id

	terminal_bound.emit(terminal, register_id)

	# Check if pool is now exhausted
	if get_unbound_terminals().is_empty():
		pool_exhausted.emit()

	return true


## Unbind a terminal from its register
func unbind_terminal(terminal: RefCounted) -> void:
	if not terminal.is_bound:
		return

	var terminal_id = terminal.terminal_id

	# Remove from binding tables
	if binding_table.has(terminal_id):
		var binding_info = binding_table[terminal_id]
		var reverse_key = "%s:%d" % [binding_info["biome_name"], binding_info["register_id"]]
		reverse_binding.erase(reverse_key)
		binding_table.erase(terminal_id)

	# Check if this was the last bound terminal (pool was exhausted)
	var was_exhausted = get_unbound_terminals().is_empty()

	# Perform unbinding
	terminal.unbind()

	terminal_unbound.emit(terminal)

	# Emit pool_available if we just freed a terminal from exhaustion
	if was_exhausted:
		pool_available.emit()


## Check if a register is currently bound
func is_register_bound(register_id: int, biome_name: String) -> bool:
	var key = "%s:%d" % [biome_name, register_id]
	return reverse_binding.has(key)


## Check if a terminal is currently bound
func is_terminal_bound(terminal: RefCounted) -> bool:
	return terminal.is_bound


## Get count of bound terminals
func get_bound_count() -> int:
	return binding_table.size()


## Get count of unbound terminals
func get_unbound_count() -> int:
	return pool_size - binding_table.size()


## Get all terminals (bound and unbound)
func get_all_terminals() -> Array:
	return terminals


## Get terminals that are measured but not yet popped
func get_measured_terminals() -> Array:
	var result: Array = []
	for terminal in terminals:
		if terminal.is_measured:
			result.append(terminal)
	return result


## Get terminals that are bound but not yet measured
func get_active_terminals() -> Array:
	var result: Array = []
	for terminal in terminals:
		if terminal.is_bound and not terminal.is_measured:
			result.append(terminal)
	return result


## Get terminal by grid position (bubble location)
## Returns null if no terminal is bound to that position
func get_terminal_at_grid_pos(grid_pos: Vector2i) -> RefCounted:
	for terminal in terminals:
		if terminal.is_bound and terminal.grid_position == grid_pos:
			return terminal
	return null


## Resize the pool (adds or removes terminals)
func resize(new_size: int) -> void:
	if new_size < 1:
		push_error("Pool size must be at least 1")
		return

	if new_size > pool_size:
		# Add terminals
		for i in range(pool_size, new_size):
			var terminal = TerminalClass.new("T_%02d" % i)
			terminal.state_changed.connect(_on_terminal_state_changed)
			terminals.append(terminal)
	elif new_size < pool_size:
		# Remove unbound terminals from the end
		var removed = 0
		for i in range(pool_size - 1, -1, -1):
			if removed >= (pool_size - new_size):
				break
			var terminal = terminals[i]
			if not terminal.is_bound:
				terminal.state_changed.disconnect(_on_terminal_state_changed)
				terminals.remove_at(i)
				removed += 1

	pool_size = terminals.size()


## Reset all terminals to unbound state
func reset_all() -> void:
	for terminal in terminals:
		if terminal.is_bound:
			unbind_terminal(terminal)


## Get pool state as dictionary (for debugging/serialization)
func get_state() -> Dictionary:
	var terminal_states = []
	for terminal in terminals:
		terminal_states.append(terminal.get_state())

	return {
		"pool_size": pool_size,
		"bound_count": get_bound_count(),
		"unbound_count": get_unbound_count(),
		"terminals": terminal_states
	}


## Callback when terminal state changes
func _on_terminal_state_changed(_terminal: RefCounted) -> void:
	# Could be used for pool-level state tracking
	pass


## Callback when terminal is measured
func _on_terminal_measured(outcome: String, terminal: RefCounted) -> void:
	terminal_measured.emit(terminal, outcome)


## String representation for debugging
func _to_string() -> String:
	return "PlotPool[%d terminals, %d bound, %d free]" % [
		pool_size, get_bound_count(), get_unbound_count()
	]


# ============================================================================
# V2 ARCHITECTURE: Terminal as Single Source of Truth
# ============================================================================
# These methods query Terminal directly instead of relying on binding tables.
# This eliminates redundant state and ensures consistency.

## Get terminal bound to a specific register (queries Terminal directly)
## V2 replacement for reverse_binding lookup
func get_terminal_for_register_v2(biome, register_id: int) -> RefCounted:
	"""Find which terminal (if any) is bound to a specific register.

	V2 Architecture: Queries Terminal objects directly instead of using
	reverse_binding table. Terminal is the single source of truth.

	Args:
		biome: BiomeBase instance to match
		register_id: Register ID to find

	Returns:
		Terminal bound to this register, or null if none
	"""
	for terminal in terminals:
		if terminal.is_bound and terminal.bound_biome == biome and terminal.bound_register_id == register_id:
			return terminal
	return null


## Check if a register is bound (queries Terminal directly)
## V2 replacement for is_register_bound
func is_register_bound_v2(biome, register_id: int) -> bool:
	"""Check if a register is currently bound to any terminal.

	V2 Architecture: Queries Terminal objects directly.

	Args:
		biome: BiomeBase instance
		register_id: Register ID to check

	Returns:
		true if register is bound, false otherwise
	"""
	return get_terminal_for_register_v2(biome, register_id) != null


## Get all terminals bound in a specific biome
func get_terminals_in_biome(biome) -> Array:
	"""Get all terminals currently bound in a specific biome.

	Args:
		biome: BiomeBase instance to filter by

	Returns:
		Array of Terminal instances bound to this biome
	"""
	var result: Array = []
	for terminal in terminals:
		if terminal.is_bound and terminal.bound_biome == biome:
			result.append(terminal)
	return result


# ============================================================================
# ATOMIC BINDING OPERATIONS
# ============================================================================
# These operations ensure binding/unbinding either fully succeeds or fails.
# No partial state changes.

func bind_terminal_atomic(terminal: RefCounted, register_id: int, biome, emoji_pair: Dictionary, grid_pos: Vector2i) -> Dictionary:
	"""Atomic binding operation - either fully succeeds or returns error.

	V2 Architecture: Single mutation point for binding. Validates all
	preconditions before making any changes.

	Args:
		terminal: Terminal instance to bind
		register_id: Register ID to bind to
		biome: BiomeBase instance
		emoji_pair: Dictionary with "north" and "south" emoji keys
		grid_pos: Grid position for the terminal's bubble

	Returns:
		Dictionary with "success" bool and either "terminal" or "error"
	"""
	# Pre-validation
	if terminal.is_bound:
		return {"success": false, "error": "terminal_already_bound"}

	if is_register_bound_v2(biome, register_id):
		return {"success": false, "error": "register_already_bound"}

	# Execute binding (single mutation point)
	terminal.bind_to_register(register_id, biome, emoji_pair)
	terminal.grid_position = grid_pos

	# Update legacy binding tables for backward compatibility
	var biome_name = biome.get_biome_type() if biome else "unknown"
	binding_table[terminal.terminal_id] = {
		"register_id": register_id,
		"biome_name": biome_name
	}
	reverse_binding["%s:%d" % [biome_name, register_id]] = terminal.terminal_id

	# Emit signal
	terminal_bound.emit(terminal, register_id)

	# Check if pool is now exhausted
	if get_unbound_terminals().is_empty():
		pool_exhausted.emit()

	return {"success": true, "terminal": terminal}


func unbind_terminal_atomic(terminal: RefCounted) -> Dictionary:
	"""Atomic unbinding operation - either fully succeeds or returns error.

	V2 Architecture: Single mutation point for unbinding.

	Args:
		terminal: Terminal instance to unbind

	Returns:
		Dictionary with "success" bool and optional "error"
	"""
	if not terminal.is_bound:
		return {"success": false, "error": "terminal_not_bound"}

	var terminal_id = terminal.terminal_id

	# Remove from legacy binding tables
	if binding_table.has(terminal_id):
		var binding_info = binding_table[terminal_id]
		var reverse_key = "%s:%d" % [binding_info["biome_name"], binding_info["register_id"]]
		reverse_binding.erase(reverse_key)
		binding_table.erase(terminal_id)

	# Check if pool was exhausted (for signal emission later)
	var was_exhausted = get_unbound_terminals().is_empty()

	# Execute unbinding (single mutation point)
	terminal.unbind()

	# Emit signal
	terminal_unbound.emit(terminal)

	# Emit pool_available if we just freed from exhaustion
	if was_exhausted:
		pool_available.emit()

	return {"success": true}
