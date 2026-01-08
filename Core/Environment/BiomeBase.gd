class_name BiomeBase
extends Node

## Abstract base class for all biomes (Model B - Physics Correct)
##
## Model B: Biome owns ONE canonical quantum state (QuantumComputer).
## Plots are hardware attachments (RegisterIds) that reference it.
## No per-plot independent quantum states.

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumRegister = preload("res://Core/QuantumSubstrate/QuantumRegister.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")
const BiomeUtilities = preload("res://Core/Environment/BiomeUtilities.gd")
const BiomeTimeTracker = preload("res://Core/Environment/BiomeTimeTracker.gd")
const BiomeDynamicsTracker = preload("res://Core/QuantumSubstrate/BiomeDynamicsTracker.gd")
const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const DensityMatrix = preload("res://Core/QuantumSubstrate/DensityMatrix.gd")

# Common infrastructure
var time_tracker: BiomeTimeTracker = BiomeTimeTracker.new()
var dynamics_tracker: BiomeDynamicsTracker = null  # Tracks quantum state evolution rate
var grid = null  # Injected FarmGrid reference

# ============================================================================
# MODEL B: QUANTUM COMPUTER OWNERSHIP (Physics-Correct)
# ============================================================================

## Central quantum state manager for this biome (ONLY source of truth)
var quantum_computer: QuantumComputer = null

## Plot register mapping: Vector2i → QuantumRegister
var plot_registers: Dictionary = {}  # Vector2i → QuantumRegister (metadata only)

## Legacy QuantumBath (being deprecated - integrated into QuantumComputer)
var bath: QuantumBath = null  # TODO: Remove after full migration

## Active projections (legacy - to be removed)
var active_projections: Dictionary = {}

# Visual Properties for QuantumForceGraph rendering
var visual_color: Color = Color(0.5, 0.5, 0.5, 0.3)  # Default gray
var visual_label: String = ""  # Display name with emoji (defaults to get_biome_type())
var visual_center_offset: Vector2 = Vector2.ZERO  # Position offset in graph
var visual_circle_radius: float = 150.0  # Circle radius override
var visual_enabled: bool = true  # Whether to show in force graph

# Oval shape properties for QuantumForceGraph rendering
var visual_oval_width: float = 300.0   # Horizontal semi-axis (a)
var visual_oval_height: float = 185.0  # Vertical semi-axis (b) - golden ratio: 300/1.618

# Bell Gates: Historical entanglement relationships
# Tracks which plots have been entangled together in the past
# Structure: Array of [pos1, pos2, pos3] triplets (for kitchen) or [pos1, pos2] pairs (for 2-qubit)
var bell_gates: Array = []  # Array of Vector2i arrays (triplets or pairs)

# Resource Registration System
# Biomes declare which emojis they can produce or consume
# Used for wide design space - any biome can define its own resources
var producible_emojis: Array[String] = []  # Emojis this biome can produce via harvest
var consumable_emojis: Array[String] = []  # Emojis this biome can consume via costs
var emoji_pairings: Dictionary = {}  # North ↔ South emoji pairs for quantum states

# Signals - common interface for all biomes
signal qubit_created(position: Vector2i, qubit: Resource)
signal qubit_measured(position: Vector2i, outcome: String)
signal qubit_evolved(position: Vector2i)
signal bell_gate_created(positions: Array)  # New: emitted when plots are entangled
signal resource_registered(emoji: String, is_producible: bool, is_consumable: bool)

# HAUNTED UI FIX: Prevent double-initialization when _ready() called multiple times
var _is_initialized: bool = false

# Performance: Control quantum evolution frequency
var quantum_evolution_accumulator: float = 0.0
var quantum_evolution_timestep: float = 0.033  # 30 Hz (60 FPS / 2)
var quantum_evolution_enabled: bool = true  # Can be toggled for debugging

# Performance: Lazy evolution for idle biomes
# Lazy = no active farm plots (user not involved)
var is_idle: bool = false
var active_plot_count: int = 0  # Tracked by plot system


## Safe VerboseConfig access wrapper (works even during compilation)
func _verbose_log(level: String, category: String, emoji: String, message: String) -> void:
	"""Safely log to VerboseConfig if available (avoids compile-time errors)"""
	if not has_node("/root/VerboseConfig"):
		return

	var logger = get_node("/root/VerboseConfig")
	match level:
		"debug":
			logger.debug(category, emoji, message)
		"info":
			logger.info(category, emoji, message)
		"warn":
			logger.warn(category, emoji, message)
		"error":
			logger.error(category, emoji, message)


func _ready() -> void:
	"""Initialize biome - called by Godot when node enters scene tree"""
	# Guard: Only initialize once (prevents double-init from manual calls)
	if _is_initialized:
		return
	_is_initialized = true

	# Initialize Model B quantum computer (new)
	quantum_computer = QuantumComputer.new(get_biome_type())

	# Initialize quantum bath (child classes override _initialize_bath())
	# TODO: Eventually deprecate bath in favor of quantum_computer
	_initialize_bath()

	# Processing will be enabled by BootManager in Stage 3D after all deps verified
	set_process(false)


func _process(dt: float) -> void:
	"""Main process loop - delegates to biome-specific evolution"""
	advance_simulation(dt)


func advance_simulation(dt: float) -> void:
	"""Advance simulation by dt seconds (for manual time control in tests)"""
	time_tracker.update(dt)

	# OPTIMIZATION: Skip evolution for idle biomes (no active plots)
	# DISABLED FOR NOW - we want to see baseline evolution even without plots
	#update_idle_status()
	#if is_idle:
	#	if Engine.get_frames_drawn() % 300 == 0:  # Print every 5 seconds
	#		print("⏸️ %s: IDLE (skipping evolution)" % get_biome_type())
	#	return  # Skip quantum evolution entirely

	# OPTIMIZATION: Accumulate time and evolve at lower frequency (30 Hz instead of 60 Hz)
	if quantum_evolution_enabled:
		quantum_evolution_accumulator += dt

		# Only evolve when accumulated time exceeds timestep
		if quantum_evolution_accumulator >= quantum_evolution_timestep:
			var actual_dt = quantum_evolution_accumulator
			quantum_evolution_accumulator = 0.0

			# Model C: QuantumComputer-based evolution (new architecture)
			if quantum_computer and not bath:
				_update_quantum_substrate(actual_dt)

				# Track quantum state evolution for dynamics calculation (lazy init)
				if not dynamics_tracker:
					dynamics_tracker = BiomeDynamicsTracker.new()
				if dynamics_tracker:
					_track_dynamics()

			# Legacy: Bath-based evolution (deprecated, but still supported)
			elif bath:
				# Emergency rebuild if operators are missing (should not happen with BootManager fix)
				var icon_count = bath.active_icons.size()
				var h_count = bath.hamiltonian_sparse.size()
				var l_count = bath.lindblad_terms.size()

				if icon_count > 0 and (h_count == 0 or l_count == 0):
					push_warning("⚠️ %s: Icons present but operators missing - emergency rebuild" % get_biome_type())
					bath.build_hamiltonian_from_icons(bath.active_icons)
					bath.build_lindblad_from_icons(bath.active_icons)
					_verbose_log("debug", "biome", "🔧", "Emergency rebuild: %s now has H=%d L=%d" % [
						get_biome_type(),
						bath.hamiltonian_sparse.size(),
						bath.lindblad_terms.size()
					])

				bath.evolve(actual_dt)
				update_projections(actual_dt)  # Pass dt for radius growth

				# Track quantum state evolution for dynamics calculation (lazy init)
				if not dynamics_tracker:
					dynamics_tracker = BiomeDynamicsTracker.new()
				if dynamics_tracker:
					_track_dynamics()

			# Warning only if NEITHER quantum_computer nor bath exists
			elif not quantum_computer and not bath:
				push_warning("Biome %s has no quantum backend - evolution disabled" % get_biome_type())
	else:
		# Evolution disabled (for debugging/testing)
		pass


func _update_quantum_substrate(dt: float) -> void:
	"""Virtual method: Override in child classes for Model C evolution.

	Called by advance_simulation() when quantum_computer exists.
	Default implementation does nothing - child classes implement their own physics.
	"""
	pass


func update_idle_status() -> void:
	"""Check if biome should go idle (no active plots = user not involved)"""
	# Biome is idle if no active plots (nothing planted or growing)
	if active_plot_count == 0:
		if not is_idle:
			is_idle = true
			# Optional debug: print("💤 Biome %s going idle (no active plots)" % get_biome_type())
	else:
		if is_idle:
			is_idle = false
			# Optional debug: print("⚡ Biome %s waking up (%d active plots)" % [get_biome_type(), active_plot_count])


func on_plot_planted(position: Vector2i) -> void:
	"""Called when a plot is planted in this biome"""
	active_plot_count += 1
	is_idle = false


func on_plot_harvested(position: Vector2i) -> void:
	"""Called when a plot is harvested in this biome"""
	active_plot_count = max(0, active_plot_count - 1)


# ============================================================================
# MODEL B: Register & Quantum Computer API
# ============================================================================

func allocate_register_for_plot(position: Vector2i, north_emoji: String = "🌾", south_emoji: String = "🌽") -> int:
	"""
	Allocate a new logical qubit register for a planted plot.

	Model B: Creates 1-qubit component in quantum_computer, stores metadata in plot_registers.

	Returns: register_id (unique per biome)
	"""
	if not quantum_computer:
		push_error("QuantumComputer not initialized!")
		return -1

	# Allocate register in quantum computer
	var reg_id = quantum_computer.allocate_register(north_emoji, south_emoji)

	# Create metadata register
	var qubit_reg = QuantumRegister.new(reg_id, get_biome_type(), 0)
	qubit_reg.north_emoji = north_emoji
	qubit_reg.south_emoji = south_emoji
	qubit_reg.is_planted = true

	plot_registers[position] = qubit_reg

	qubit_created.emit(position, qubit_reg)
	return reg_id


# ============================================================================
# MODEL C: Bath & Subplot API (Analog Model Support)
# ============================================================================

func allocate_subplot_for_plot(position: Vector2i, north_emoji: String = "🔥", south_emoji: String = "❄️") -> int:
	"""
	Allocate a subplot in bath for a planted plot (Model C - Analog).

	Model C: Bath manages full composite state - plots define measurement axes.
	This method tracks subplot metadata without creating independent quantum states.

	Args:
		position: Grid position of the plot
		north_emoji: North pole measurement basis
		south_emoji: South pole measurement basis

	Returns:
		subplot_id (0 for success, -1 for failure)
	"""
	# Model C uses quantum_computer, Model B uses bath - check for either
	if not bath and not quantum_computer:
		push_warning("BiomeBase.allocate_subplot_for_plot: neither bath nor quantum_computer available! Biome may not have initialized.")
		return -1

	# Model C: Bath manages the full state - plots just track their measurement axis
	# No need to allocate separate quantum states
	# Just track metadata (subplot_id could be sequential, or just 0 for success)

	# Store metadata in plot_registers for compatibility
	var qubit_reg = QuantumRegister.new(0, get_biome_type(), 0)
	qubit_reg.north_emoji = north_emoji
	qubit_reg.south_emoji = south_emoji
	qubit_reg.is_planted = true
	plot_registers[position] = qubit_reg

	qubit_created.emit(position, qubit_reg)

	# Subplot allocation succeeds - bath manages full state
	return 0


func clear_subplot_for_plot(position: Vector2i) -> void:
	"""
	Clear subplot metadata when plot is unplanted (Model C - Analog).

	Model C: Bath state persists - this only clears the measurement axis metadata.
	The underlying bath continues evolving with all emojis intact.

	Args:
		position: Grid position of the plot to clear
	"""
	if position in plot_registers:
		plot_registers.erase(position)

	# Note: Bath state is NOT cleared - it's shared across all plots in the biome
	# Only the measurement axis reference is removed

func get_register_for_plot(position: Vector2i) -> QuantumRegister:
	"""Get the QuantumRegister metadata for a plot."""
	return plot_registers.get(position, null)

func get_component_for_plot(position: Vector2i) -> Resource:  # Actually QuantumComponent
	"""Get the connected component containing this plot's register."""
	var reg = get_register_for_plot(position)
	if not reg:
		return null
	return quantum_computer.get_component_containing(reg.register_id)

func get_register_id_for_plot(position: Vector2i) -> int:
	"""Get the logical register ID for a plot."""
	var reg = get_register_for_plot(position)
	if not reg:
		return -1
	return reg.register_id

func clear_register_for_plot(position: Vector2i) -> void:
	"""Remove register metadata when plot is unplanted."""
	if position in plot_registers:
		plot_registers.erase(position)

# ============================================================================
# Common Quantum Operations (Model B API)
# ============================================================================

func create_quantum_state(position: Vector2i, north: String, south: String, theta: float = PI/2) -> int:
	"""Create and store a quantum state at grid position (Model B version)

	Model B: This allocates a register in quantum_computer, not an independent state.
	Returns: register_id in quantum_computer
	"""
	return allocate_register_for_plot(position, north, south)


func get_qubit(position: Vector2i) -> Resource:
	"""Retrieve quantum register at position (legacy interface)"""
	return get_register_for_plot(position)


func measure_qubit(position: Vector2i) -> String:
	"""Measure (collapse) quantum register at position (Model B version)

	Physical projective measurement via QuantumComputer (MEASURE operation).
	Collapses quantum state to measurement outcome.
	"""
	var reg = get_register_for_plot(position)
	if not reg:
		return ""

	var comp = quantum_computer.get_component_containing(reg.register_id)
	if not comp:
		return ""

	var outcome = quantum_computer.measure_register(comp, reg.register_id)
	reg.measurement_outcome = outcome
	reg.has_been_measured = true

	qubit_measured.emit(position, outcome)
	return outcome


func inspect_qubit(position: Vector2i) -> Dictionary:
	"""Inspect quantum register WITHOUT collapsing state (Model B - Phase 2)

	Non-destructive measurement probability inspection (INSPECT operation).
	Returns probabilities without affecting quantum state.

	Args:
		position: Plot position

	Returns:
		Dictionary with marginal probabilities {"north": P0, "south": P1}
	"""
	var reg = get_register_for_plot(position)
	if not reg:
		return {"north": 0.0, "south": 0.0}

	var comp = quantum_computer.get_component_containing(reg.register_id)
	if not comp:
		return {"north": 0.0, "south": 0.0}

	return quantum_computer.inspect_register_distribution(comp, reg.register_id)


func clear_qubit(position: Vector2i) -> void:
	"""Remove quantum register at position"""
	clear_register_for_plot(position)

# ============================================================================
# PHASE 4: Biome Evolution Control (Icon Modification API)
# ============================================================================

func boost_coupling(emoji: String, target_emoji: String, factor: float = 1.5) -> bool:
	"""Increase Hamiltonian coupling between two emoji states (Model B)

	Modifies the Icon's hamiltonian_couplings dictionary to scale coupling strength.
	Rebuilds Hamiltonian for next evolution step.

	Args:
		emoji: Source emoji
		target_emoji: Target emoji
		factor: Multiplication factor (1.5 = 50% increase, 2.0 = double, 0.5 = halve)

	Returns:
		true if successful, false if Icons not found
	"""
	if not bath or not bath.active_icons:
		push_error("Biome %s has no active Icons!" % get_biome_type())
		return false

	var source_icon: Icon = null
	for icon in bath.active_icons:
		if icon.emoji == emoji:
			source_icon = icon
			break

	if not source_icon:
		push_warning("Icon for %s not found in biome %s" % [emoji, get_biome_type()])
		return false

	# Modify coupling: scale existing coupling or set to default
	var current_coupling = source_icon.hamiltonian_couplings.get(target_emoji, 0.5)
	var new_coupling = current_coupling * factor
	source_icon.hamiltonian_couplings[target_emoji] = new_coupling

	# Rebuild Hamiltonian with new coupling
	bath.build_hamiltonian_from_icons(bath.active_icons)
	_verbose_log("info","biome", "✅", "Boosted coupling %s → %s by %.1f× (%.3f → %.3f)" %
		[emoji, target_emoji, factor, current_coupling, new_coupling])

	return true


func tune_decoherence(emoji: String, factor: float = 1.5) -> bool:
	"""Tune Lindblad decoherence rates for an emoji (Model B)

	Modifies the Icon's lindblad_outgoing rates to scale decoherence strength.
	Rebuilds Lindblad operators for next evolution step.

	Args:
		emoji: Target emoji
		factor: Multiplication factor (1.5 = 50% faster decay, 0.5 = slower decay)

	Returns:
		true if successful, false if Icon not found
	"""
	if not bath or not bath.active_icons:
		push_error("Biome %s has no active Icons!" % get_biome_type())
		return false

	var target_icon: Icon = null
	for icon in bath.active_icons:
		if icon.emoji == emoji:
			target_icon = icon
			break

	if not target_icon:
		push_warning("Icon for %s not found in biome %s" % [emoji, get_biome_type()])
		return false

	# Modify all outgoing Lindblad rates for this emoji
	var old_rates = {}
	for target_emoji in target_icon.lindblad_outgoing:
		old_rates[target_emoji] = target_icon.lindblad_outgoing[target_emoji]
		target_icon.lindblad_outgoing[target_emoji] *= factor

	# Also scale decay rate
	target_icon.decay_rate *= factor

	# Rebuild Lindblad with new rates
	bath.build_lindblad_from_icons(bath.active_icons)
	_verbose_log("info","biome", "✅", "Tuned decoherence for %s by %.1f× (decay: %.4f)" %
		[emoji, factor, target_icon.decay_rate])

	return true


func add_time_dependent_driver(emoji: String, driver_type: String = "cosine", frequency: float = 1.0, amplitude: float = 1.0) -> bool:
	"""Add time-dependent driving field to emoji (Model B - Phase 4)

	Enables oscillating Hamiltonian term, e.g., for day/night cycles or external fields.
	Updates Icon and rebuilds time-dependent Hamiltonian.

	Args:
		emoji: Target emoji
		driver_type: "cosine", "sine", "pulse", or "" (disable)
		frequency: Oscillation frequency in Hz
		amplitude: Amplitude multiplier for self-energy

	Returns:
		true if successful
	"""
	if not bath or not bath.active_icons:
		push_error("Biome %s has no active Icons!" % get_biome_type())
		return false

	var target_icon: Icon = null
	for icon in bath.active_icons:
		if icon.emoji == emoji:
			target_icon = icon
			break

	if not target_icon:
		push_warning("Icon for %s not found in biome %s" % [emoji, get_biome_type()])
		return false

	# Set driving parameters
	target_icon.self_energy_driver = driver_type
	target_icon.driver_frequency = frequency
	target_icon.driver_amplitude = amplitude

	# Rebuild Hamiltonian with time-dependent terms
	bath.build_hamiltonian_from_icons(bath.active_icons)
	_verbose_log("info","biome", "✅", "Added %s driver to %s (freq: %.1f Hz, amp: %.1f)" %
		[driver_type, emoji, frequency, amplitude])

	return true


# ============================================================================
# PHASE 4: Lindblad Channel Operations (Pump/Reset)
# ============================================================================

func pump_to_emoji(source_emoji: String, target_emoji: String, pump_rate: float = 0.01) -> bool:
	"""Pump population from source to target via Lindblad pump operator (Model B)

	Creates/modifies a Lindblad pump channel: L_pump = √Γ |target⟩⟨source|
	This gradually transfers population from source to target emoji.

	Args:
		source_emoji: Source emoji to pump from
		target_emoji: Target emoji to pump to
		pump_rate: Pump rate Γ (typical: 0.01-0.1 per second)

	Returns:
		true if successful
	"""
	if not bath or not bath.active_icons:
		push_error("Biome %s has no active Icons!" % get_biome_type())
		return false

	var source_icon: Icon = null
	for icon in bath.active_icons:
		if icon.emoji == source_emoji:
			source_icon = icon
			break

	if not source_icon:
		push_warning("Source icon %s not found in biome %s" % [source_emoji, get_biome_type()])
		return false

	# Add incoming transfer: source loses population to target
	if not source_icon.lindblad_outgoing.has(target_emoji):
		source_icon.lindblad_outgoing[target_emoji] = 0.0

	var old_rate = source_icon.lindblad_outgoing[target_emoji]
	source_icon.lindblad_outgoing[target_emoji] += pump_rate

	# Rebuild Lindblad with new pump channel
	bath.build_lindblad_from_icons(bath.active_icons)
	_verbose_log("info","biome", "✅", "Added pump %s → %s (rate: %.4f, total: %.4f)" %
		[source_emoji, target_emoji, pump_rate, source_icon.lindblad_outgoing[target_emoji]])

	return true


func reset_to_pure_state(emoji: String, reset_rate: float = 0.1) -> bool:
	"""Reset emoji to pure |0⟩ state via Lindblad reset channel (Model B)

	Creates a Lindblad reset channel that mixes state toward |0⟩⟨0|.
	Parameter: ρ ← (1-α)ρ + α|0⟩⟨0| where α = reset_rate × dt

	Args:
		emoji: Target emoji
		reset_rate: Reset strength per second (typical: 0.05-0.5)

	Returns:
		true if successful
	"""
	if not bath or not bath.active_icons:
		push_error("Biome %s has no active Icons!" % get_biome_type())
		return false

	var target_icon: Icon = null
	for icon in bath.active_icons:
		if icon.emoji == emoji:
			target_icon = icon
			break

	if not target_icon:
		push_warning("Icon %s not found in biome %s" % [emoji, get_biome_type()])
		return false

	# Store reset target in icon metadata (custom property)
	if not target_icon.has_meta("reset_target"):
		target_icon.set_meta("reset_target", "0")
	if not target_icon.has_meta("reset_rate"):
		target_icon.set_meta("reset_rate", reset_rate)
	else:
		var old_rate = target_icon.get_meta("reset_rate")
		target_icon.set_meta("reset_rate", old_rate + reset_rate)

	_verbose_log("info","biome", "✅", "Set reset for %s to pure state (rate: %.3f)" % [emoji, reset_rate])
	return true


func reset_to_mixed_state(emoji: String, reset_rate: float = 0.1) -> bool:
	"""Reset emoji to maximally mixed state via Lindblad reset channel (Model B)

	Creates a Lindblad reset channel that mixes state toward I/N.
	Parameter: ρ ← (1-α)ρ + α(I/N) where α = reset_rate × dt

	Args:
		emoji: Target emoji
		reset_rate: Reset strength per second (typical: 0.05-0.5)

	Returns:
		true if successful
	"""
	if not bath or not bath.active_icons:
		push_error("Biome %s has no active Icons!" % get_biome_type())
		return false

	var target_icon: Icon = null
	for icon in bath.active_icons:
		if icon.emoji == emoji:
			target_icon = icon
			break

	if not target_icon:
		push_warning("Icon %s not found in biome %s" % [emoji, get_biome_type()])
		return false

	# Store reset target in icon metadata (custom property)
	if not target_icon.has_meta("reset_target"):
		target_icon.set_meta("reset_target", "mixed")
	if not target_icon.has_meta("reset_rate"):
		target_icon.set_meta("reset_rate", reset_rate)
	else:
		var old_rate = target_icon.get_meta("reset_rate")
		target_icon.set_meta("reset_rate", old_rate + reset_rate)

	_verbose_log("info","biome", "✅", "Set reset for %s to mixed state (rate: %.3f)" % [emoji, reset_rate])
	return true


# ============================================================================
# PHASE 4: Gate Infrastructure (Entanglement Management)
# ============================================================================

func create_cluster_state(positions: Array[Vector2i]) -> bool:
	"""Create multi-qubit cluster state from selected plots (Model B)

	Entangles multiple plots into a chain topology (linear cluster).
	Uses sequential Bell pair entanglement: plot[0]↔plot[1]↔plot[2]↔...

	Args:
		positions: Array of plot positions to cluster

	Returns:
		true if cluster successfully created
	"""
	if not quantum_computer or positions.size() < 2:
		return false

	_verbose_log("debug","quantum", "🌐", "Creating cluster state with %d plots" % positions.size())

	var success_count = 0
	for i in range(positions.size() - 1):
		var pos_a = positions[i]
		var pos_b = positions[i + 1]

		# Get register IDs
		var reg_a = get_register_id_for_plot(pos_a)
		var reg_b = get_register_id_for_plot(pos_b)

		if reg_a < 0 or reg_b < 0:
			push_warning("Invalid registers for cluster: %d, %d" % [reg_a, reg_b])
			continue

		# Create Bell pair entanglement
		if quantum_computer.entangle_plots(reg_a, reg_b):
			success_count += 1
			_verbose_log("debug","quantum", "🔗", "Entangled %s ↔ %s" % [pos_a, pos_b])

	# Store in bell_gates history for UI visualization
	if success_count > 0:
		bell_gates.append(positions.duplicate())
		bell_gate_created.emit(positions)

	_verbose_log("info","quantum", "✅", "Cluster created with %d entanglements" % success_count)
	return success_count > 0


func set_measurement_trigger(trigger_pos: Vector2i, target_positions: Array[Vector2i]) -> bool:
	"""Set up conditional measurement trigger (Model B - Phase 4 Infrastructure)

	When trigger_pos is measured, its outcome affects measurements at target_positions.
	Requires both trigger and targets to be in same entangled component.

	Args:
		trigger_pos: Plot whose measurement triggers condition
		target_positions: Plots affected by trigger measurement

	Returns:
		true if trigger successfully set up
	"""
	if not quantum_computer:
		return false

	var trigger_reg = get_register_id_for_plot(trigger_pos)
	if trigger_reg < 0:
		push_warning("Invalid trigger register at %s" % trigger_pos)
		return false

	# Verify all targets are in same component as trigger
	var trigger_comp = quantum_computer.get_component_containing(trigger_reg)
	if not trigger_comp:
		push_warning("Trigger not in valid component")
		return false

	var valid_targets = 0
	for target_pos in target_positions:
		var target_reg = get_register_id_for_plot(target_pos)
		if target_reg < 0:
			continue

		var target_comp = quantum_computer.get_component_containing(target_reg)
		if target_comp and target_comp.component_id == trigger_comp.component_id:
			valid_targets += 1

	if valid_targets == 0:
		push_warning("No valid targets in trigger component")
		return false

	_verbose_log("info","quantum", "✅", "Measurement trigger set: %s → %d targets" % [trigger_pos, valid_targets])
	return true


func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	"""Remove entanglement between two plots (Model B - Phase 4 Infrastructure)

	Decouples two plots by clearing their entanglement metadata.
	Actual quantum state remains entangled (full disentanglement requires projection).

	Args:
		pos_a: First plot
		pos_b: Second plot

	Returns:
		true if decouplng successful
	"""
	if not quantum_computer:
		return false

	var reg_a = get_register_id_for_plot(pos_a)
	var reg_b = get_register_id_for_plot(pos_b)

	if reg_a < 0 or reg_b < 0:
		push_warning("Invalid registers for removal: %d, %d" % [reg_a, reg_b])
		return false

	# Clear entanglement graph edges
	if quantum_computer.entanglement_graph.has(reg_a):
		quantum_computer.entanglement_graph[reg_a].erase(reg_b)
	if quantum_computer.entanglement_graph.has(reg_b):
		quantum_computer.entanglement_graph[reg_b].erase(reg_a)

	_verbose_log("info","quantum", "✅", "Removed entanglement between %s and %s" % [pos_a, pos_b])
	return true


func batch_entangle(positions: Array[Vector2i]) -> bool:
	"""Create Bell pairs between all adjacent plot pairs (Model B)

	Entangles all consecutive plot pairs in the selection.
	Creates multiple independent Bell pairs: (0,1), (1,2), (2,3), etc.

	Args:
		positions: Array of plot positions

	Returns:
		true if at least one entanglement succeeded
	"""
	if not quantum_computer or positions.size() < 2:
		return false

	_verbose_log("debug","quantum", "🔗", "Batch entangling %d plots" % positions.size())

	var success_count = 0
	for i in range(positions.size() - 1):
		var pos_a = positions[i]
		var pos_b = positions[i + 1]

		var reg_a = get_register_id_for_plot(pos_a)
		var reg_b = get_register_id_for_plot(pos_b)

		if reg_a < 0 or reg_b < 0:
			continue

		if quantum_computer.entangle_plots(reg_a, reg_b):
			success_count += 1
			_verbose_log("debug","quantum", "🔗", "Entangled %s ↔ %s" % [pos_a, pos_b])

	if success_count > 0:
		bell_gates.append(positions.duplicate())
		bell_gate_created.emit(positions)

	_verbose_log("info","quantum", "✅", "Created %d Bell pairs" % success_count)
	return success_count > 0


# ============================================================================
# PHASE 4: Energy Tap System (Sink State with Lindblad Drain)
# ============================================================================

func initialize_energy_tap_system() -> void:
	"""Initialize sink state infrastructure in bath if not already present"""
	if not bath or not bath.active_icons:
		return

	# Check if sink emoji already exists
	for icon in bath.active_icons:
		if icon.emoji == "⬇️":
			return  # Already initialized

	# Create sink state icon if needed (passive, no outgoing transfer)
	var sink_icon = Icon.new()
	sink_icon.emoji = "⬇️"
	sink_icon.display_name = "Sink"
	sink_icon.description = "Energy dissipation sink state"
	sink_icon.self_energy = 0.0
	sink_icon.hamiltonian_couplings = {}
	sink_icon.lindblad_outgoing = {}

	bath.active_icons.append(sink_icon)
	_verbose_log("info","biome", "✅", "Energy tap system initialized with sink state")


func place_energy_tap(target_emoji: String, drain_rate: float = 0.05) -> bool:
	"""Place energy drain tap on emoji (Model B - Phase 4)

	Creates Lindblad drain operator: L_drain = √κ |sink⟩⟨target|
	Population from target_emoji drains to sink state ⬇️.

	Args:
		target_emoji: Emoji to tap energy from
		drain_rate: Drain rate κ (typical: 0.01-0.1 per second)

	Returns:
		true if tap successfully placed
	"""
	if not bath or not bath.active_icons:
		push_error("Biome %s has no active Icons!" % get_biome_type())
		return false

	# Initialize tap system if needed
	initialize_energy_tap_system()

	var target_icon: Icon = null
	for icon in bath.active_icons:
		if icon.emoji == target_emoji:
			target_icon = icon
			break

	if not target_icon:
		push_warning("Target icon %s not found in biome %s" % [target_emoji, get_biome_type()])
		return false

	# Add drain operator: target → sink
	# Store in lindblad_outgoing as if target is losing to sink
	var sink_emoji = "⬇️"
	if not target_icon.lindblad_outgoing.has(sink_emoji):
		target_icon.lindblad_outgoing[sink_emoji] = 0.0

	var old_rate = target_icon.lindblad_outgoing[sink_emoji]
	target_icon.lindblad_outgoing[sink_emoji] += drain_rate

	# Rebuild Lindblad with new drain operator
	bath.build_lindblad_from_icons(bath.active_icons)

	_verbose_log("info","biome", "✅", "Energy tap placed on %s (rate: %.4f → sink)" %
		[target_emoji, target_icon.lindblad_outgoing[sink_emoji]])

	return true


func get_tap_flux(emoji: String) -> float:
	"""Get accumulated energy flux drained from emoji this frame

	Returns flux accumulated by quantum_computer during evolution.

	Args:
		emoji: Target emoji to check flux for

	Returns:
		Flux value (energy per second drained)
	"""
	if not quantum_computer:
		return 0.0

	return quantum_computer.sink_flux_per_emoji.get(emoji, 0.0)


func clear_tap_flux() -> void:
	"""Clear accumulated tap flux (call after harvesting)"""
	if quantum_computer:
		quantum_computer.sink_flux_per_emoji.clear()

# ============================================================================
# MODEL B: Gate Operations (Tool 5 Backend)
# ============================================================================

func apply_gate_1q(position: Vector2i, gate_name: String) -> bool:
	"""Apply 1-qubit unitary gate to a plot's register (Model B version)

	Model B: Validates plot is unmeasured, gets component from quantum_computer,
	applies gate via QuantumComputer.apply_unitary_1q().

	Args:
		position: Plot position
		gate_name: Gate name (e.g., "X", "H", "Z")

	Returns:
		true if successful, false if failed
	"""
	var reg = get_register_for_plot(position)
	if not reg or not reg.is_planted:
		push_error("Plot %s not planted!" % position)
		return false

	# Validate: no gates on measured plots
	if reg.has_been_measured:
		push_error("Cannot apply gates to measured plots!")
		return false

	# Get gate matrix from library
	var gate_dict = QuantumGateLibrary.get_gate(gate_name)
	if not gate_dict or not gate_dict.has("matrix"):
		push_error("Gate not found: %s" % gate_name)
		return false

	var U = gate_dict["matrix"]

	# Get component
	var comp = quantum_computer.get_component_containing(reg.register_id)
	if not comp:
		push_error("Register %d not in any component!" % reg.register_id)
		return false

	# Apply gate
	var success = quantum_computer.apply_unitary_1q(comp, reg.register_id, U)

	if success:
		reg.record_gate_application(gate_name, time_tracker.turn_count)

	return success

func apply_gate_2q(position_a: Vector2i, position_b: Vector2i, gate_name: String) -> bool:
	"""Apply 2-qubit unitary gate to two plots' registers (Model B version)

	Model B: Validates both plots are unmeasured, merges components if needed,
	applies gate via QuantumComputer.apply_unitary_2q().

	Args:
		position_a: Control plot position
		position_b: Target plot position
		gate_name: Gate name (e.g., "CNOT", "CZ", "SWAP")

	Returns:
		true if successful, false if failed
	"""
	var reg_a = get_register_for_plot(position_a)
	var reg_b = get_register_for_plot(position_b)

	if not reg_a or not reg_a.is_planted or not reg_b or not reg_b.is_planted:
		push_error("One or both plots not planted!")
		return false

	# Validate: no gates on measured plots
	if reg_a.has_been_measured or reg_b.has_been_measured:
		push_error("Cannot apply gates to measured plots!")
		return false

	# Get gate matrix from library
	var gate_dict = QuantumGateLibrary.get_gate(gate_name)
	if not gate_dict or gate_dict["arity"] != 2:
		push_error("Invalid 2-qubit gate: %s" % gate_name)
		return false

	var U = gate_dict["matrix"]

	# Get components (may be different)
	var comp_a = quantum_computer.get_component_containing(reg_a.register_id)
	var comp_b = quantum_computer.get_component_containing(reg_b.register_id)

	if not comp_a or not comp_b:
		push_error("Invalid component for registers!")
		return false

	# Merge components if different
	if comp_a.component_id != comp_b.component_id:
		var merged = quantum_computer.merge_components(comp_a, comp_b)
		if not merged:
			push_error("Failed to merge components!")
			return false
		comp_a = merged

	# Apply gate
	var success = quantum_computer.apply_unitary_2q(comp_a, reg_a.register_id, reg_b.register_id, U)

	if success:
		reg_a.record_gate_application(gate_name + "(ctrl)", time_tracker.turn_count)
		reg_b.record_gate_application(gate_name + "(tgt)", time_tracker.turn_count)

	return success

# ============================================================================
# MODEL B: Entanglement Operations (Tool 1 Backend)
# ============================================================================

func entangle_plots(position_a: Vector2i, position_b: Vector2i) -> bool:
	"""Entangle two plots using Bell circuit (Model B version)

	Creates Bell Φ+ = (|00⟩ + |11⟩)/√2 between two registers.
	Automatically merges their components into one.

	Args:
		position_a: First plot
		position_b: Second plot

	Returns:
		true if successful, false if failed
	"""
	var reg_a = get_register_for_plot(position_a)
	var reg_b = get_register_for_plot(position_b)

	if not reg_a or not reg_b or not reg_a.is_planted or not reg_b.is_planted:
		push_error("Both plots must be planted to entangle!")
		return false

	# Validate: no entangling measured plots
	if reg_a.has_been_measured or reg_b.has_been_measured:
		push_error("Cannot entangle measured plots!")
		return false

	# Call quantum_computer entanglement
	var success = quantum_computer.entangle_plots(reg_a.register_id, reg_b.register_id)

	if success:
		# Record entanglement
		reg_a.entangled_with.append(reg_b.register_id)
		reg_b.entangled_with.append(reg_a.register_id)

		# Emit signal for visualization/tracking
		bell_gate_created.emit([position_a, position_b])

		_verbose_log("info","quantum", "🔗", "Entangled plots %s ↔ %s" % [position_a, position_b])

	return success


func batch_measure_plots(position: Vector2i) -> Dictionary:
	"""Measure entire entangled component when one plot is measured (Phase 3 - Spooky Action at Distance)

	When you measure one qubit in an entangled component, all qubits in that component collapse.
	This implements batch measurement across the entire entangled network.

	Manifest Section 4.2: Batch measurement - one measurement collapses entire component.

	Args:
		position: Position of plot to trigger measurement

	Returns:
		Dictionary mapping register_ids to measurement outcomes
		Example: {reg_0: "north", reg_1: "south", reg_2: "north"}
	"""
	var reg = get_register_for_plot(position)
	if not reg:
		return {}

	var comp = quantum_computer.get_component_containing(reg.register_id)
	if not comp:
		return {}

	# Batch measure entire component
	var outcomes = quantum_computer.batch_measure_component(comp)

	# Update all registers in component with their outcomes
	for reg_id in outcomes.keys():
		# Find which plot owns this register
		for plot_pos in plot_registers.keys():
			var plot_reg = plot_registers[plot_pos]
			if plot_reg and plot_reg.register_id == reg_id:
				plot_reg.measurement_outcome = outcomes[reg_id]
				plot_reg.has_been_measured = true
				qubit_measured.emit(plot_pos, outcomes[reg_id])
				break

	_verbose_log("debug","quantum", "🌀", "Batch measurement on component %d: %s" % [comp.component_id, outcomes])
	return outcomes

# ============================================================================
# Bath-First Projection Management (Phase 3 - Legacy, to be deprecated)
# ============================================================================

func _initialize_bath() -> void:
	"""Override in subclasses to set up the quantum bath

	Example:
		bath = QuantumBath.new()
		bath.initialize_with_emojis(["☀", "🌾", "🍄", "💀"])
		bath.initialize_uniform()

		var icons: Array[Icon] = []
		icons.append(IconRegistry.get_icon("☀"))
		# ... get other icons

		bath.active_icons = icons
		bath.build_hamiltonian_from_icons(icons)
		bath.build_lindblad_from_icons(icons)
	"""
	pass


func rebuild_quantum_operators() -> void:
	"""Rebuild Hamiltonian and Lindblad operators (call after IconRegistry is ready)

	This is needed when biomes initialize before IconRegistry is available.
	Child classes can override to implement custom rebuild logic.
	"""
	if bath:
		# Always rebuild if bath exists - icons may be incomplete from partial IconRegistry init
		_rebuild_bath_operators()


func _rebuild_bath_operators() -> void:
	"""Attempt to rebuild bath operators from IconRegistry (override in child classes)"""
	pass


# ============================================================================
# Compositional Bath Helpers
# ============================================================================

static func merge_emoji_sets(set_a: Array[String], set_b: Array[String]) -> Array[String]:
	"""Merge two emoji sets (union with deduplication)

	Example:
		var bioticflux = ["☀", "🌾", "🌿"]
		var forest = ["🌿", "🐺", "🐰"]
		var merged = merge_emoji_sets(bioticflux, forest)
		# Result: ["☀", "🌾", "🌿", "🐺", "🐰"]
	"""
	var merged_dict: Dictionary = {}

	for emoji in set_a:
		merged_dict[emoji] = true

	for emoji in set_b:
		merged_dict[emoji] = true

	# Convert to typed array
	var result: Array[String] = []
	for emoji in merged_dict.keys():
		result.append(emoji)

	return result


func initialize_bath_from_emojis(emojis: Array[String], initial_weights: Dictionary = {}) -> void:
	"""Initialize bath with emoji set + auto-build operators from Icons

	This is the compositional initialization - Icons define all physics.

	Args:
		emojis: List of emoji strings to include in bath
		initial_weights: Optional initial population weights (emoji → float)

	Example:
		initialize_bath_from_emojis(["☀", "🌾", "🍄"], {
			"☀": 0.5,
			"🌾": 0.3,
			"🍄": 0.2
		})
	"""
	bath = QuantumBath.new()
	bath.initialize_with_emojis(emojis)

	# Apply initial weights (if provided)
	if not initial_weights.is_empty():
		bath.initialize_weighted(initial_weights)

	# Get Icons from IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("🛁 IconRegistry not available - bath init failed!")
		return

	var icons: Array[Icon] = []
	for emoji in emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons.append(icon)
		else:
			push_warning("No Icon found for emoji: %s" % emoji)

	# Build operators from Icon composition
	if not icons.is_empty():
		bath.active_icons = icons
		bath.build_hamiltonian_from_icons(icons)
		bath.build_lindblad_from_icons(icons)

	_verbose_log("info","biome", "🛁", "Bath initialized: %d emojis, %d icons" % [emojis.size(), icons.size()])


func hot_drop_emoji(emoji: String, initial_amplitude: Complex = null) -> bool:
	"""Dynamically inject an emoji into a running biome bath

	This "hot drops" an emoji into the ecosystem at runtime, bringing
	its full Icon physics (Hamiltonian + Lindblad operators).

	Args:
		emoji: The emoji to inject
		initial_amplitude: Starting amplitude (default: Complex.zero())

	Returns:
		true if successful, false if failed

	Example:
		# Drop a new predator into the ecosystem
		biome.hot_drop_emoji("🐺", Complex.new(0.1, 0.0))
	"""
	if not bath:
		push_error("No bath to hot drop into!")
		return false

	# Check if already exists
	if bath.emoji_to_index.has(emoji):
		push_warning("Emoji %s already in bath" % emoji)
		return false

	# Get Icon from registry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("IconRegistry not available for hot drop!")
		return false

	var icon = icon_registry.get_icon(emoji)
	if not icon:
		push_error("No Icon found for emoji: %s" % emoji)
		return false

	# Default amplitude
	if initial_amplitude == null:
		initial_amplitude = Complex.zero()

	# Inject into bath
	bath.inject_emoji(emoji, icon, initial_amplitude)

	# Rebuild operators to include new emoji's physics
	var all_icons: Array[Icon] = []
	for e in bath.emoji_list:
		var e_icon = icon_registry.get_icon(e)
		if e_icon:
			all_icons.append(e_icon)

	bath.active_icons = all_icons
	bath.build_hamiltonian_from_icons(all_icons)
	bath.build_lindblad_from_icons(all_icons)

	# Renormalize after injection
	bath.normalize()

	_verbose_log("info","biome", "🚁", "Hot dropped %s into %s biome (now %d emojis)" % [emoji, get_biome_type(), bath.emoji_list.size()])
	return true


# ============================================================================
# EVOLUTION CONTROL METHODS (Tool 4: Biome Evolution Controller)
# ============================================================================
# These methods allow players to tune quantum dynamics WITHOUT directly
# manipulating the density matrix. They modify evolution PARAMETERS:
# - Hamiltonian couplings (coherent dynamics)
# - Lindblad rates (decoherence/dissipation)
# - Time-dependent drivers (AC fields)
#
# This is how real quantum control works in laboratories!
# ============================================================================

func boost_hamiltonian_coupling(emoji_a: String, emoji_b: String, boost_factor: float) -> bool:
	"""Increase Hamiltonian coupling between two emojis

	Physics: Modifies H[i,j] coupling strength → faster coherent oscillations

	Args:
		emoji_a: First emoji (source of coupling)
		emoji_b: Second emoji (target of coupling)
		boost_factor: Multiplicative factor (e.g., 1.5 = 50% faster, 0.5 = 50% slower)

	Returns:
		true if successful, false if emoji or icon not found

	Example:
		# Make wheat → bread conversion 2x faster
		biome.boost_hamiltonian_coupling("🌾", "🍞", 2.0)
	"""
	if not bath:
		push_error("No bath to control!")
		return false

	# Get IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("IconRegistry not available")
		return false

	# Get icon for emoji_a
	var icon_a = icon_registry.get_icon(emoji_a)
	if not icon_a:
		push_warning("No Icon for %s - cannot boost coupling" % emoji_a)
		return false

	# Check if coupling exists
	if not icon_a.hamiltonian_couplings.has(emoji_b):
		push_warning("%s has no Hamiltonian coupling to %s" % [emoji_a, emoji_b])
		return false

	# Modify coupling strength
	var old_coupling = icon_a.hamiltonian_couplings[emoji_b]
	icon_a.hamiltonian_couplings[emoji_b] = old_coupling * boost_factor

	# Rebuild Hamiltonian with new coupling
	bath.build_hamiltonian_from_icons(bath.active_icons)

	_verbose_log("info","biome", "⚡", "Boosted coupling %s ↔ %s: %.3f → %.3f (×%.2f)" %
		[emoji_a, emoji_b, old_coupling, icon_a.hamiltonian_couplings[emoji_b], boost_factor])

	return true


func tune_lindblad_rate(source: String, target: String, rate_factor: float) -> bool:
	"""Modify Lindblad dissipation rate between emojis

	Physics: Changes γ in the Lindblad term L = √γ |target⟩⟨source|
	Controls decoherence/transfer speed

	Args:
		source: Source emoji (decays FROM this state)
		target: Target emoji (decays TO this state)
		rate_factor: Multiplicative factor for rate

	Returns:
		true if successful, false if not found

	Example:
		# Reduce decoherence (maintain purity)
		biome.tune_lindblad_rate("🌾", "💀", 0.5)  # Half decay rate

		# Speed up transfer
		biome.tune_lindblad_rate("🍄", "🍂", 2.0)  # Double composting rate
	"""
	if not bath:
		push_error("No bath to control!")
		return false

	# Get IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("IconRegistry not available")
		return false

	# Get icon for source emoji
	var icon_source = icon_registry.get_icon(source)
	if not icon_source:
		push_warning("No Icon for %s - cannot tune Lindblad" % source)
		return false

	# Check if Lindblad term exists
	if not icon_source.lindblad_outgoing.has(target):
		push_warning("%s has no Lindblad outgoing to %s" % [source, target])
		return false

	# Modify rate
	var old_rate = icon_source.lindblad_outgoing[target]
	icon_source.lindblad_outgoing[target] = old_rate * rate_factor

	# Rebuild Lindblad operators with new rate
	bath.build_lindblad_from_icons(bath.active_icons)

	_verbose_log("info","biome", "🌊", "Tuned Lindblad %s → %s: γ=%.4f → %.4f (×%.2f)" %
		[source, target, old_rate, icon_source.lindblad_outgoing[target], rate_factor])

	return true


func add_time_driver(emoji: String, frequency: float, amplitude: float, phase: float = 0.0) -> bool:
	"""Add time-dependent driving field to an emoji

	Physics: Adds H_drive(t) = A·cos(ωt + φ) to self-energy
	Creates resonant driving (like AC voltage in qubits)

	Args:
		emoji: Target emoji to drive
		frequency: Angular frequency ω (rad/s)
		amplitude: Drive amplitude A (energy units)
		phase: Initial phase φ (radians)

	Returns:
		true if successful, false if not found

	Example:
		# Resonantly drive wheat at natural frequency
		biome.add_time_driver("🌾", 0.5, 0.1, 0.0)

		# Remove driver (amplitude = 0)
		biome.add_time_driver("🌾", 0.0, 0.0, 0.0)
	"""
	if not bath:
		push_error("No bath to control!")
		return false

	# Get IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("IconRegistry not available")
		return false

	# Get icon
	var icon = icon_registry.get_icon(emoji)
	if not icon:
		push_warning("No Icon for %s - cannot add driver" % emoji)
		return false

	# Set driver parameters
	icon.self_energy_driver = "cosine" if amplitude > 0.0 else "none"
	icon.driver_frequency = frequency
	icon.driver_amplitude = amplitude
	icon.driver_phase = phase

	# Rebuild Hamiltonian with time-dependent term
	bath.build_hamiltonian_from_icons(bath.active_icons)

	if amplitude > 0.0:
		_verbose_log("info","biome", "📡", "Added driver to %s: ω=%.3f, A=%.3f, φ=%.2f" %
			[emoji, frequency, amplitude, phase])
	else:
		_verbose_log("info","biome", "📡", "Removed driver from %s" % emoji)

	return true


func create_projection(position: Vector2i, north: String, south: String) -> Resource:
	"""Create a projection of the bath onto a north/south axis

	In bath mode, this doesn't create a new quantum state - it creates
	a WINDOW into the existing bath state. Multiple projections can
	overlap (e.g., both 🌾/💀 and 🌾/🍂 can exist simultaneously).

	Args:
		position: Grid position for this projection
		north: North pole emoji
		south: South pole emoji

	Returns:
		DualEmojiQubit that reflects the current bath projection
	"""
	if not bath:
		push_error("Biome %s has no bath - cannot create projection!" % get_biome_type())
		return null

	# ========================================================================
	# INJECTION PHASE: Ensure both emojis exist in bath
	# This enables cross-biome planting - plots specify axial pairs, and
	# missing emojis are injected dynamically with their Icons
	# ========================================================================
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if icon_registry:
		var injected = false

		# Inject north if missing
		if not bath.emoji_to_index.has(north):
			var north_icon = icon_registry.get_icon(north)
			if north_icon:
				# Start with zero amplitude (will adjust after south check)
				bath.inject_emoji(north, north_icon, Complex.zero())
				injected = true
				_verbose_log("debug","biome", "💉", "Injected %s into %s bath" % [north, get_biome_type()])
			else:
				push_warning("  ⚠️  No Icon for %s in IconRegistry" % north)

		# Inject south if missing (use north's amplitude for 50/50 split)
		if not bath.emoji_to_index.has(south):
			var south_icon = icon_registry.get_icon(south)
			if south_icon:
				# For 50/50 split: give south same amplitude as north
				# This ensures theta = π/2 (equal superposition)
				var north_amp = bath.get_amplitude(north)
				bath.inject_emoji(south, south_icon, north_amp)
				injected = true
				_verbose_log("debug","biome", "💉", "Injected %s into %s bath (amplitude matched to %s)" % [south, get_biome_type(), north])
			else:
				push_warning("  ⚠️  No Icon for %s in IconRegistry" % south)

		if injected:
			# Normalize bath to maintain total probability = 1.0
			bath.normalize()
			_verbose_log("info","biome", "✅", "Bath now has %d emojis: %s" % [bath.emoji_list.size(), str(bath.emoji_list)])

	# ========================================================================
	# PROJECTION PHASE: Both emojis guaranteed to exist (or warnings issued)
	# ========================================================================

	# PHASE 3: Simplified - create live-coupled qubit (no manual computation)
	# Theta/phi/radius will be computed automatically from bath via getters
	var qubit = DualEmojiQubit.new(north, south, PI/2.0, bath)
	qubit.plot_position = position

	# No need to set theta/phi/radius - they're computed from bath!
	# The qubit is now a live viewport into the bath state

	_verbose_log("debug","biome", "🔭", "Created live projection %s↔%s at %s (θ=%.2f from bath)" % [north, south, position, qubit.theta])

	# Store projection metadata
	active_projections[position] = {
		"qubit": qubit,
		"north": north,
		"south": south
	}

	# Model B: Quantum state is owned by quantum_computer, not stored in plots
	qubit_created.emit(position, qubit)

	return qubit


func update_projections(_dt: float = 0.016) -> void:
	"""Update all projections to reflect current bath state

	Called after bath.evolve() to sync all plot visuals with the bath.
	Now uses proper density matrix formalism - qubits are pure projections,
	no manual theta/phi/radius updates needed.

	Args:
		_dt: Time delta (unused - bath evolution handles all dynamics)
	"""
	if not bath:
		return

	# Qubits are now stateless projections - they automatically compute
	# theta/phi/radius from the bath's density matrix.
	# No manual updates needed - just emit the signal for UI refresh.

	for position in active_projections:
		qubit_evolved.emit(position)


func evaluate_energy_coupling(_emoji: String, _bath_observables: Dictionary = {}) -> float:
	"""DEPRECATED: Energy coupling is now handled in Lindblad evolution

	The old energy_couplings system on Icons has been replaced with
	proper Lindblad transfer terms that directly affect the density matrix.

	This method is kept for backwards compatibility but always returns 0.0.
	"""
	return 0.0


func _query_bath_observables() -> Dictionary:
	"""Query all bath observable probabilities

	Returns dictionary mapping emoji → probability
	"""
	var obs = {}
	if bath and bath.has_method("get_probability"):
		for emoji in bath.emoji_list:
			obs[emoji] = bath.get_probability(emoji)
	return obs


func _get_lindblad_growth_rate(_emoji: String) -> float:
	"""DEPRECATED: Lindblad evolution is now handled in QuantumBath

	Lindblad transfer rates are now properly applied via the
	LindbladSuperoperator in the density matrix evolution.

	This method is kept for backwards compatibility but always returns 0.0.
	"""
	return 0.0


func measure_projection(position: Vector2i) -> String:
	"""Measure a projection, causing bath backaction

	In bath mode, measurement collapses the bath (partial collapse),
	which affects ALL projections.

	Args:
		position: Grid position to measure

	Returns:
		Outcome emoji (north or south)
	"""
	if not bath:
		push_error("Biome %s has no bath - cannot measure projection!" % get_biome_type())
		return ""

	if not active_projections.has(position):
		return ""

	var data = active_projections[position]
	var north: String = data.north
	var south: String = data.south

	# Measure the bath (causes partial collapse)
	var outcome = bath.measure_axis(north, south, 0.5)

	# Update all projections to reflect the collapsed bath
	update_projections()

	qubit_measured.emit(position, outcome)
	return outcome


func remove_projection(position: Vector2i) -> void:
	"""Remove a projection (e.g., after harvest)

	This doesn't affect the bath - just removes the observation window.
	Model B: Quantum state remains in quantum_computer, only observation window removed.
	"""
	active_projections.erase(position)


func get_projection_qubit(position: Vector2i) -> Resource:
	"""Get the qubit for a projection (for backward compatibility)"""
	if active_projections.has(position):
		return active_projections[position].qubit
	return null


# ============================================================================
# Quest System Observable Readers (Phase 4)
# ============================================================================
# Safe read-only methods that work in both bath-first and legacy modes
# Used by quest system to track quantum state progress

func get_observable_theta(north: String, south: String) -> float:
	"""Get polar angle θ for projection [0, π]

	Physical meaning: θ=0 is pure north, θ=π is pure south, θ=π/2 is equal superposition
	Safe read-only method that works in both bath and legacy modes.

	Args:
		north: North pole emoji (e.g., "🌾")
		south: South pole emoji (e.g., "👥")

	Returns:
		Polar angle in radians [0, π], or π/2 if projection doesn't exist
	"""
	if bath:
		# Project bath and read theta
		var proj = bath.project_onto_axis(north, south)
		return proj.theta if proj.valid else PI/2
	# Model B: bath always exists
	return PI/2


func get_observable_phi(north: String, south: String) -> float:
	"""Get azimuthal phase φ for projection [0, 2π]

	Physical meaning: relative quantum phase between north and south states
	This is genuine quantum information that affects interference patterns.

	Args:
		north: North pole emoji
		south: South pole emoji

	Returns:
		Azimuthal angle in radians [0, 2π], or 0.0 if projection doesn't exist
	"""
	if bath:
		# Project bath and read phi
		var proj = bath.project_onto_axis(north, south)
		return proj.phi if proj.valid else 0.0
	# Model B: bath always exists
	return 0.0


func get_observable_coherence(north: String, south: String) -> float:
	"""Get coherence (superposition strength) [0, 1]

	Physical meaning: How much in superposition vs classical mixture
	coherence = sin(θ), maximized at θ=π/2 (equal superposition)

	Args:
		north: North pole emoji
		south: South pole emoji

	Returns:
		Coherence value [0, 1], where 1.0 is maximum superposition
	"""
	var theta = get_observable_theta(north, south)
	return abs(sin(theta))


func get_observable_radius(north: String, south: String) -> float:
	"""Get amplitude radius in projection subspace [0, 1]

	Physical meaning: How much "spirit" lives in this north/south axis
	radius = √(|α_north|² + |α_south|²)

	Args:
		north: North pole emoji
		south: South pole emoji

	Returns:
		Radius [0, 1], or 0.0 if projection doesn't exist
	"""
	if bath:
		# Project bath and read radius
		var proj = bath.project_onto_axis(north, south)
		return proj.radius if proj.valid else 0.0
	# Model B: bath always exists
	return 0.0


func get_observable_amplitude(emoji: String) -> float:
	"""Get amplitude |α| of specific emoji in the bath [0, 1]

	Physical meaning: Probability amplitude for this emoji state
	Only meaningful in bath mode. Returns 0.0 in legacy mode.

	Args:
		emoji: The emoji to query (e.g., "🌾")

	Returns:
		Amplitude magnitude [0, 1]
	"""
	if bath:
		# get_amplitude returns Complex, extract magnitude
		var complex_amp = bath.get_amplitude(emoji)
		return complex_amp.abs()
	else:
		# No bath: no bath-wide amplitudes
		return 0.0


func get_observable_phase(emoji: String) -> float:
	"""Get phase arg(α) of specific emoji in the bath [-π, π]

	Physical meaning: Complex phase of this emoji's amplitude
	Only meaningful in bath mode. Returns 0.0 in legacy mode.

	Args:
		emoji: The emoji to query

	Returns:
		Phase in radians [-π, π]
	"""
	if bath:
		# get_amplitude returns Complex, extract phase
		var complex_amp = bath.get_amplitude(emoji)
		return complex_amp.arg()
	else:
		# No bath: no bath-wide phases
		return 0.0


# ============================================================================
# Helper for Observable Readers
# ============================================================================

# REMOVED: _find_qubit_with_emojis() - Legacy Model A method
# Model B: All qubit discovery goes through quantum_computer, not cached quantum_states dictionary


# ============================================================================
# Resource Registration System
# ============================================================================

func register_resource(emoji: String, is_producible: bool = true, is_consumable: bool = false) -> void:
	"""Register an emoji as a resource this biome works with

	Called during biome initialization to declare what resources
	can be harvested from or spent in this biome.

	Args:
		emoji: The emoji string (e.g., "🌾", "🐺", "💧")
		is_producible: Can this biome produce this resource via harvest?
		is_consumable: Does this biome accept this resource as cost?
	"""
	if is_producible and emoji not in producible_emojis:
		producible_emojis.append(emoji)

	if is_consumable and emoji not in consumable_emojis:
		consumable_emojis.append(emoji)

	resource_registered.emit(emoji, is_producible, is_consumable)


func register_emoji_pair(north: String, south: String) -> void:
	"""Register a quantum emoji pairing (north pole ↔ south pole)

	This defines what emojis can appear when measuring quantum states
	in this biome. Both emojis are automatically registered as producible.

	Args:
		north: North pole emoji (e.g., "🌾")
		south: South pole emoji (e.g., "👥")
	"""
	emoji_pairings[north] = south
	emoji_pairings[south] = north

	# Both ends of the pairing can be produced
	register_resource(north, true, false)
	register_resource(south, true, false)


func get_producible_emojis() -> Array[String]:
	"""Get all emojis this biome can produce"""
	return producible_emojis


func get_consumable_emojis() -> Array[String]:
	"""Get all emojis this biome accepts as cost"""
	return consumable_emojis


func get_emoji_pairings() -> Dictionary:
	"""Get all north/south emoji pairings for this biome"""
	return emoji_pairings.duplicate()


func can_produce(emoji: String) -> bool:
	"""Check if this biome can produce the given emoji"""
	return emoji in producible_emojis


func can_consume(emoji: String) -> bool:
	"""Check if this biome accepts the given emoji as cost"""
	return emoji in consumable_emojis


## ========================================
## Harvestable Resource Filtering
## ========================================

## Environmental icons that exist in bath but cannot be harvested from plots
## These are observable influences (sun/moon cycles, weather) not farm products
const ENVIRONMENTAL_ICONS = ["☀", "☀️", "🌙", "🌑", "💧", "🌊", "🔥", "⚡", "🌬️"]

func get_harvestable_emojis() -> Array[String]:
	"""Get only emojis that can be harvested from plots

	Filters out environmental icons (sun, moon, water, fire) that affect
	quantum evolution but cannot be obtained through farming.

	Used by quest generation to ensure quests only request farmable resources.

	Returns:
		Array of emoji strings that can be obtained via planting/measuring/harvesting

	Example:
		var harvestable = biome.get_harvestable_emojis()
		# BioticFlux returns: ["🌾", "🍄", "💀", "🍂"]
		# Excludes: ["☀", "🌙"] (environmental)
	"""
	var harvestable: Array[String] = []

	for emoji in producible_emojis:
		if not emoji in ENVIRONMENTAL_ICONS:
			harvestable.append(emoji)

	return harvestable


# ============================================================================
# Bell Gates - Historical Entanglement Relationships
# ============================================================================

func mark_bell_gate(positions: Array) -> void:
	"""
	Mark plots as having been entangled (creates a Bell gate)

	This records the historical relationship - even if plots are no longer
	entangled now, they can be used as a measurement target later.

	NOTE: Biome subclasses can override to apply energy boosts to entangled qubits.

	Args:
		positions: [Vector2i, Vector2i] for 2-qubit OR [Vector2i, Vector2i, Vector2i] for 3-qubit
	"""
	if positions.size() < 2:
		push_error("Bell gate requires at least 2 positions")
		return

	# Check if this exact gate already exists
	for existing_gate in bell_gates:
		if _gates_equal(existing_gate, positions):
			return  # Already recorded

	bell_gates.append(positions.duplicate())
	bell_gate_created.emit(positions)

	_verbose_log("info","quantum", "🔔", "Bell gate created at biome %s: %s" % [get_biome_type(), _format_positions(positions)])


func get_bell_gate(index: int) -> Array:
	"""Get a specific Bell gate by index"""
	if index >= 0 and index < bell_gates.size():
		return bell_gates[index]
	return []


func get_all_bell_gates() -> Array:
	"""Get all Bell gates in this biome"""
	return bell_gates.duplicate()


func get_bell_gates_of_size(size: int) -> Array:
	"""Get all Bell gates with specific size (2 for pairs, 3 for triplets)"""
	var filtered = []
	for gate in bell_gates:
		if gate.size() == size:
			filtered.append(gate)
	return filtered


func get_triplet_bell_gates() -> Array:
	"""Get all 3-qubit Bell gates (for kitchen use)"""
	return get_bell_gates_of_size(3)


func get_pair_bell_gates() -> Array:
	"""Get all 2-qubit Bell gates"""
	return get_bell_gates_of_size(2)


func has_bell_gates() -> bool:
	"""Check if any Bell gates exist"""
	return bell_gates.size() > 0


func bell_gate_count() -> int:
	"""Get number of Bell gates"""
	return bell_gates.size()


# ============================================================================
# Status & Debug
# ============================================================================

func get_status() -> Dictionary:
	"""Get current biome status (override to add custom fields)"""
	# Get quantum system size (works for both bath and quantum_computer)
	var quantum_size = 0
	if bath and bath.emoji_list:
		quantum_size = bath.emoji_list.size()
	elif quantum_computer and quantum_computer.register_map:
		quantum_size = quantum_computer.register_map.num_qubits

	return BiomeUtilities.create_status_dict({
		"type": get_biome_type(),
		"qubits": quantum_size,
		"time": time_tracker.time_elapsed,
		"cycles": time_tracker.cycle_count
	})


func get_biome_type() -> String:
	"""Override in subclasses to return biome type name"""
	return "Base"


func get_visual_config() -> Dictionary:
	"""Get visual configuration for QuantumForceGraph rendering

	Override to customize appearance (or set visual_* properties in _ready())

	Returns: {color, label, center_offset, circle_radius, oval_width, oval_height, enabled}
	"""
	return {
		"color": visual_color,
		"label": visual_label if visual_label != "" else get_biome_type(),
		"center_offset": visual_center_offset,
		"circle_radius": visual_circle_radius,  # LEGACY - kept for compatibility
		"oval_width": visual_oval_width,
		"oval_height": visual_oval_height,
		"enabled": visual_enabled
	}


func render_biome_content(graph: Node2D, center: Vector2, radius: float) -> void:
	"""Render custom biome-specific content inside biome region circle

	Override in subclasses to draw custom visualizations.
	Called during QuantumForceGraph._draw() for each biome.

	Args:
		graph: QuantumForceGraph instance (access to draw_* methods)
		center: Screen position of biome circle center
		radius: Radius of the biome circle

	Default: does nothing (generic biomes have no custom rendering)
	"""
	pass  # Subclasses override to add custom drawing


func get_plot_positions_in_oval(plot_count: int, center: Vector2, viewport_scale: float = 1.0) -> Array[Vector2]:
	"""Calculate parametric ring pattern positions for plots within this biome's oval

	Returns Array[Vector2] of screen positions arranged in concentric oval rings.
	Uses golden ratio proportions (visual_oval_width : visual_oval_height)

	Args:
		plot_count: Number of plots to position
		center: Center point of the biome oval
		viewport_scale: Scale factor based on graph_radius (default 1.0 for no scaling)

	Returns: Array of screen positions for each plot
	"""
	var positions: Array[Vector2] = []

	if plot_count == 0:
		return positions

	# Apply viewport scaling to oval dimensions for consistency with rendering
	# CRITICAL: Divide by 2 to get semi-axes (visual_oval_width/height are DIAMETERS)
	var semi_a = (visual_oval_width * viewport_scale) / 2.0
	var semi_b = (visual_oval_height * viewport_scale) / 2.0

	# Calculate number of rings needed (inner to outer)
	# Rule: innermost ring has 1-3 plots, each ring adds ~6 plots
	var rings = max(1, ceil(sqrt(float(plot_count) / 3.0)))
	var plots_per_ring = []
	var remaining = plot_count

	# Distribute plots across rings (outer rings have more plots)
	for ring_idx in range(rings):
		var plots_in_ring = int(ceil(float(remaining) / float(rings - ring_idx)))
		plots_per_ring.append(plots_in_ring)
		remaining -= plots_in_ring

	# Generate positions for each ring
	var ring_idx = 0
	for num_plots in plots_per_ring:
		# Ring scale factor (0.3 for innermost, 0.9 for outermost)
		var scale = 0.3 + (0.6 * float(ring_idx) / float(max(1, rings - 1)))

		# Parametric oval equation: x = a*cos(t), y = b*sin(t)
		# Uses semi-axes (NOT full width/height)
		for plot_in_ring in range(num_plots):
			var t = (float(plot_in_ring) / float(num_plots)) * TAU
			var x = center.x + semi_a * cos(t) * scale
			var y = center.y + semi_b * sin(t) * scale
			positions.append(Vector2(x, y))

		ring_idx += 1

	# Sort positions left-to-right so keyboard order matches visual order
	# Without this, oval parametric positioning starts at angle 0 (right side)
	# and goes counter-clockwise, scrambling the order
	positions.sort_custom(func(a, b): return a.x < b.x)

	return positions


# ============================================================================
# Dynamics Tracking
# ============================================================================

func _track_dynamics() -> void:
	"""Record current quantum observables for dynamics tracking"""
	if not bath or not dynamics_tracker:
		return

	# Calculate current observables
	var purity = bath.get_purity()
	var entropy = _calculate_bath_entropy()
	var coherence = _calculate_bath_coherence()

	# Record snapshot
	dynamics_tracker.add_snapshot({
		"purity": purity,
		"entropy": entropy,
		"coherence": coherence
	})


func _calculate_bath_entropy() -> float:
	"""Calculate normalized entropy of bath state"""
	if not bath or not bath._density_matrix:
		return 0.5

	var purity = bath.get_purity()
	var dim = bath._density_matrix.dimension()

	if purity <= 0 or dim <= 1:
		return 0.0

	var max_entropy = log(dim)
	if max_entropy <= 0:
		return 0.0

	return clamp(-log(purity) / max_entropy, 0.0, 1.0)


func _calculate_bath_coherence() -> float:
	"""Calculate total off-diagonal magnitude squared"""
	if not bath or not bath._density_matrix:
		return 0.0

	var dim = bath._density_matrix.dimension()
	if dim < 2:
		return 0.0

	var mat = bath._density_matrix.get_matrix()
	if not mat:
		return 0.0

	var total = 0.0

	for i in range(dim):
		for j in range(dim):
			if i != j:
				var element = mat.get_element(i, j)
				if element:
					total += element.re * element.re + element.im * element.im

	# Normalize by maximum possible coherence
	var max_coherence = float(dim * (dim - 1))
	return clamp(total / max_coherence, 0.0, 1.0) if max_coherence > 0 else 0.0


# ============================================================================
# Reset & Lifecycle
# ============================================================================

func reset() -> void:
	"""Reset biome to initial state"""
	# Model B: quantum_computer manages the state, clear it if needed
	if quantum_computer:
		quantum_computer.clear()
	active_projections.clear()
	bell_gates.clear()
	time_tracker.reset()

	# Clear dynamics tracking history
	if dynamics_tracker:
		dynamics_tracker.clear_history()

	_reset_custom()


func _reset_custom() -> void:
	"""Override in subclasses for biome-specific reset logic"""
	pass


# ============================================================================
# Gozinta Operations (Input Channels - Manifest Section 3)
# ============================================================================

func pump_emoji(rest_emoji: String, target_emoji: String, pump_rate: float, duration: float) -> float:
	"""Reservoir pumping: transfer amplitude from rest state to target state

	Manifest Section 3.1: L_t = √Γ |t⟩⟨r| (Lindblad incoming operator)
	Physical interpretation: Amplitude flows from rest reservoir into target.

	Args:
		rest_emoji: Source emoji (rest state/reservoir)
		target_emoji: Target emoji to pump amplitude into
		pump_rate: Pump rate Γ in amplitude/sec
		duration: Duration of pumping in seconds

	Returns: Amount of amplitude pumped (≈ pump_rate * duration)
	"""
	if not bath:
		push_error("pump_emoji(): No bath available")
		return 0.0

	# Ensure both emojis are in the bath
	if not bath.has_emoji(rest_emoji):
		_verbose_log("debug","biome", "ℹ️", "Injecting %s into bath for pumping" % rest_emoji)
		var rest_icon = Icon.new()
		rest_icon.emoji = rest_emoji
		rest_icon.display_name = rest_emoji
		bath.inject_emoji(rest_emoji, rest_icon)

	if not bath.has_emoji(target_emoji):
		_verbose_log("debug","biome", "ℹ️", "Injecting %s into bath for pumping" % target_emoji)
		var target_icon = Icon.new()
		target_icon.emoji = target_emoji
		target_icon.display_name = target_emoji
		bath.inject_emoji(target_emoji, target_icon)

	# Create temporary pump icon with Lindblad incoming
	# This will be added to active_icons for evolution
	var pump_icon = Icon.new()
	pump_icon.emoji = rest_emoji
	pump_icon.display_name = "Pump(%s→%s)" % [rest_emoji, target_emoji]

	# Add Lindblad incoming: target gains from rest
	# L = √Γ |target⟩⟨rest|
	pump_icon.lindblad_incoming[target_emoji] = pump_rate

	# Rebuild operators to include pump
	var original_icons = bath.active_icons.duplicate()
	bath.active_icons.append(pump_icon)
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	# Evolve with pump for specified duration
	var dt = 0.016  # 60 FPS timestep
	var steps = int(duration / dt)
	var total_amplitude_pumped = 0.0

	_verbose_log("debug","biome", "💧", "Pumping %s → %s at rate %.3f/sec for %.2f sec (%d steps)" % [
		rest_emoji, target_emoji, pump_rate, duration, steps
	])

	for i in range(steps):
		bath.evolve(dt)
		# Track approximate amplitude transfer per step
		total_amplitude_pumped += pump_rate * dt

	# Restore original operators (remove pump)
	bath.active_icons = original_icons
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	var p_target = bath.get_probability(target_emoji)
	_verbose_log("info","biome", "✅", "Pump complete: %s now at P=%.3f" % [target_emoji, p_target])

	return total_amplitude_pumped


func apply_reset(alpha: float, ref_state: String = "pure") -> void:
	"""Reset channel: mix density matrix with reference state

	Manifest Section 3.4: ρ ← (1-α)ρ + α ρ_ref
	Physical interpretation: Partial reset toward reference state.

	Args:
		alpha: Mix strength in [0, 1]. α=0 (no reset), α=1 (full reset)
		ref_state: Reference state to reset toward:
			- "pure": Pure state in each qubit's north emoji
			- "maximally_mixed": Maximally mixed state I/N
			- specific emoji name: Pure state |emoji⟩⟨emoji|
	"""
	if not bath:
		push_error("apply_reset(): No bath available")
		return

	var dim = bath._density_matrix.dimension()
	if dim == 0:
		return

	var rho_current = bath._density_matrix.get_matrix()

	# Create reference density matrix
	var rho_ref = ComplexMatrix.new(dim)

	match ref_state:
		"pure":
			# Pure state in first emoji (north pole of each qubit)
			var amps: Array = []
			amps.append(Complex.one())
			for i in range(1, dim):
				amps.append(Complex.zero())
			var pure_rho = DensityMatrix.new()
			pure_rho.initialize_with_emojis(bath._density_matrix.emoji_list)
			pure_rho.set_pure_state(amps)
			rho_ref = pure_rho.get_matrix()

		"maximally_mixed":
			# I/N: all diagonal elements = 1/N
			var one_over_n = 1.0 / float(dim)
			for i in range(dim):
				rho_ref.set_element(i, i, Complex.new(one_over_n, 0.0))

		_:
			# Specific emoji: pure state |emoji⟩⟨emoji|
			var emoji_idx = bath._density_matrix.emoji_to_index.get(ref_state, -1)
			if emoji_idx >= 0:
				rho_ref.set_element(emoji_idx, emoji_idx, Complex.one())
			else:
				push_warning("apply_reset(): Unknown reference state '%s'" % ref_state)
				return

	# Apply reset: ρ ← (1-α)ρ + α ρ_ref
	var alpha_complex = Complex.new(alpha, 0.0)
	var one_minus_alpha = Complex.new(1.0 - alpha, 0.0)

	var rho_reset = rho_current.scale(one_minus_alpha).add(rho_ref.scale(alpha_complex))

	bath._density_matrix.set_matrix(rho_reset)
	bath._density_matrix._enforce_trace_one()

	var trace = bath._density_matrix.get_trace()
	_verbose_log("debug","biome", "🔄", "Reset applied: α=%.3f, ref='%s', Tr(ρ)=%.6f" % [alpha, ref_state, trace])


# ============================================================================
# Vector Harvest Operations (Manifest Section 4.4)
# ============================================================================

func harvest_all_plots() -> Array:
	"""Harvest all plots in this biome in vector fashion

	Manifest Section 4.4: Bulk harvest operation for entire biome.
	This is more efficient than harvesting plots individually.

	Returns: Array of harvest result dictionaries
		Each element is {success, outcome, yield, ...} from FarmPlot.harvest()
	"""
	if not grid:
		push_warning("BiomeBase.harvest_all_plots(): No grid reference")
		return []

	var results: Array = []

	# Get all plots in the grid that belong to this biome
	for position in active_projections.keys():
		var plot = grid.get_plot(position)
		if plot and plot.is_planted:
			# Harvest this plot
			var result = plot.harvest()
			results.append(result)
			_verbose_log("debug","farm", "📍", "Harvested plot at %s: yield=%d" % [position, result.get("yield", 0)])

	# Aggregate results
	var total_yield = 0
	var successful_harvests = 0

	for result in results:
		if result.get("success", false):
			successful_harvests += 1
			total_yield += result.get("yield", 0)

	_verbose_log("info","farm", "✂️", "BiomeBase.harvest_all_plots(): %d harvested, %d credits total" % [
		successful_harvests, total_yield
	])

	return results


# ============================================================================
# PHASE 4: Energy Tap Processing (Lindblad Drain Channels)
# ============================================================================

func process_energy_taps(delta: float = 0.016) -> Dictionary:
	"""
	Process energy taps: collect accumulated flux from sink state.

	This is called each frame to harvest energy from active Lindblad drain operators.
	The energy accumulated in the sink state is converted to classical resources.

	Manifest Section 4.1: Implements gozouta ("energy exit") for the quantum system.

	Args:
		delta: Time step for this frame (used for rate calculations)

	Returns:
		Dictionary: {emoji: accumulated_flux_this_frame}
			Used to update energy tap plots' accumulated resources.
	"""
	if not quantum_computer:
		return {}

	# Query accumulated flux from QuantumComputer
	# (which aggregates from QuantumBath's Lindblad evolution)
	var fluxes = quantum_computer.get_all_sink_fluxes()

	# Reset flux counter for next frame
	quantum_computer.reset_sink_flux()

	return fluxes


func setup_energy_tap(target_emoji: String, drain_rate: float = 0.1) -> bool:
	"""
	Configure energy tap drain operators for a target emoji.

	This ensures that the target emoji has Lindblad drain operators configured
	to flow probability to the sink state. Called when energy tap is planted.

	Manifest Section 4.1: Lindblad drain operators L_e = |sink⟩⟨e| with rate κ.

	Args:
		target_emoji: The emoji to tap (must already be in bath)
		drain_rate: Drain rate κ in probability/sec

	Returns:
		true if setup succeeded
	"""
	if not bath:
		push_error("Cannot setup energy tap: no bath in biome %s" % get_biome_type())
		return false

	# Get or create Icon for target emoji
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("Cannot setup energy tap: IconRegistry not found")
		return false

	var target_icon = icon_registry.get_icon(target_emoji)
	if not target_icon:
		push_error("Cannot setup energy tap: Icon not found for %s" % target_emoji)
		return false

	# Configure Icon as drain target
	target_icon.is_drain_target = true
	target_icon.drain_to_sink_rate = drain_rate

	# Ensure target emoji is in bath
	if not bath.has_emoji(target_emoji):
		var injected = bath.inject_emoji(target_emoji, target_icon)
		if not injected:
			push_error("Cannot setup energy tap: Failed to inject %s into bath" % target_emoji)
			return false

	# Ensure sink state is in bath
	if not bath.has_emoji(bath.sink_emoji):
		var sink_icon = Icon.new()
		sink_icon.emoji = bath.sink_emoji
		sink_icon.display_name = "Sink"
		sink_icon.is_eternal = true  # Sink never decays
		var sink_injected = bath.inject_emoji(bath.sink_emoji, sink_icon)
		if not sink_injected:
			push_error("Cannot setup energy tap: Failed to inject sink state into bath")
			return false

	# Rebuild Lindblad operators to include drain channels
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	_verbose_log("info","biome", "⚡", "Setup energy tap drain for %s (κ=%.3f/sec) in %s" % [
		target_emoji, drain_rate, get_biome_type()
	])

	return true


# ============================================================================
# Helper Functions - Bell Gate Utilities
# ============================================================================

func _gates_equal(gate1: Array, gate2: Array) -> bool:
	"""Check if two gates are equal (same positions, any order)"""
	if gate1.size() != gate2.size():
		return false

	var g1_sorted = gate1.duplicate()
	var g2_sorted = gate2.duplicate()
	g1_sorted.sort()
	g2_sorted.sort()

	for i in range(g1_sorted.size()):
		if g1_sorted[i] != g2_sorted[i]:
			return false

	return true


func _format_positions(positions: Array) -> String:
	"""Format position array as readable string"""
	var parts = []
	for pos in positions:
		parts.append(str(pos))
	return "[" + ", ".join(parts) + "]"
