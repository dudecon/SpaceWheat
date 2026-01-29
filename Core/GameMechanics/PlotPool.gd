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
signal terminal_unbound_at(grid_position: Vector2i, terminal_id: String)
signal pool_exhausted()  # Emitted when all terminals are bound
signal pool_available()  # Emitted when at least one terminal becomes available

const TerminalClass = preload("res://Core/GameMechanics/Terminal.gd")

## Pool of all terminals (Array of Terminal instances)
var terminals: Array = []

## Pool configuration
var pool_size: int = 12  # Default number of terminals


func _init(size: int = 12):
	pool_size = size
	_initialize_pool()


func _initialize_pool() -> void:
	terminals.clear()

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


## Get terminal bound to a specific register (queries Terminal state directly)
func get_terminal_for_register(register_id: int, biome_name: String) -> RefCounted:
	"""Query Terminal objects directly to find binding by biome NAME (not object reference)"""
	for terminal in terminals:
		if terminal.is_bound and terminal.bound_register_id == register_id and terminal.bound_biome_name == biome_name:
			return terminal
	return null


## Bind a terminal to a register in a biome
## Returns true if binding succeeded, false if constraint violated
## biome_name: String name of the biome (decoupled from object reference)
func bind_terminal(terminal: RefCounted, register_id: int, biome_name: String, emoji_pair: Dictionary = {}) -> bool:
	if terminal.is_bound:
		push_warning("Terminal %s already bound" % terminal.terminal_id)
		return false

	# Check unique binding constraint - query Terminal state directly
	if get_terminal_for_register(register_id, biome_name) != null:
		push_warning("Register %d in %s already bound to terminal" % [register_id, biome_name])
		return false

	# Perform binding (delegates to Terminal) - uses biome NAME, not object
	terminal.bind_to_register(register_id, biome_name, emoji_pair)

	terminal_bound.emit(terminal, register_id)

	# Check if pool is now exhausted
	if get_unbound_terminals().is_empty():
		pool_exhausted.emit()

	return true


## Unbind a terminal from its register
func unbind_terminal(terminal: RefCounted) -> void:
	if not terminal.is_bound:
		return

	# Check if pool was exhausted BEFORE unbinding
	var was_exhausted = get_unbound_terminals().is_empty()
	var old_pos = terminal.grid_position
	var old_id = terminal.terminal_id

	# Perform unbinding (delegates to Terminal - this is the ONLY mutation point)
	terminal.unbind()

	terminal_unbound.emit(terminal)
	if old_pos != Vector2i(-1, -1):
		terminal_unbound_at.emit(old_pos, old_id)

	# Emit pool_available if we just freed a terminal from exhaustion
	if was_exhausted:
		pool_available.emit()


## Check if a register is currently bound (queries Terminal state directly)
func is_register_bound(register_id: int, biome_name: String) -> bool:
	"""Check if a register is bound to ANY terminal in this biome"""
	return get_terminal_for_register(register_id, biome_name) != null


## Check if a terminal is currently bound
func is_terminal_bound(terminal: RefCounted) -> bool:
	return terminal.is_bound


## Get count of bound terminals
func get_bound_count() -> int:
	return get_bound_terminals().size()


## Get count of unbound terminals
func get_unbound_count() -> int:
	return get_unbound_terminals().size()


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
## Returns null if no terminal (bound or measured) occupies that slot
func get_terminal_at_grid_pos(grid_pos: Vector2i) -> RefCounted:
	for terminal in terminals:
		if terminal.grid_position == grid_pos and (terminal.is_bound or terminal.is_measured):
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


## Helper: Get all terminals bound in a specific biome
func get_terminals_in_biome(biome_name: String) -> Array:
	"""Get all terminals currently bound in a specific biome.

	Args:
		biome_name: Name of the biome to filter by (String, not object)

	Returns:
		Array of Terminal instances bound to this biome
	"""
	var result: Array = []
	for terminal in terminals:
		if terminal.is_bound and terminal.bound_biome_name == biome_name:
			result.append(terminal)
	return result
