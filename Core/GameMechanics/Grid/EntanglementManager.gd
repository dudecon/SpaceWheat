class_name EntanglementManager
extends RefCounted

## EntanglementManager - Multi-qubit entanglement and quantum operations
##
## Extracted from FarmGrid.gd as part of decomposition.
## Handles entanglement creation/removal, cluster management, and auto-infrastructure.

const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")
const EntangledCluster = preload("res://Core/QuantumSubstrate/EntangledCluster.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")

# Signals
signal entanglement_created(from: Vector2i, to: Vector2i)
signal entanglement_removed(from: Vector2i, to: Vector2i)

# Entangled state tracking
var entangled_pairs: Array = []  # Array of EntangledPair objects
var entangled_clusters: Array = []  # Array of EntangledCluster objects

# Component dependencies (injected via set_dependencies)
var _plot_manager = null  # GridPlotManager
var _biome_routing = null  # BiomeRoutingManager
var _verbose = null


func set_dependencies(plot_manager, biome_routing) -> void:
	"""Inject component dependencies."""
	_plot_manager = plot_manager
	_biome_routing = biome_routing


func set_verbose(verbose_ref) -> void:
	"""Set verbose logger reference."""
	_verbose = verbose_ref


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API - Entanglement Creation/Removal
# ═══════════════════════════════════════════════════════════════════════════════

func create_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String = "phi_plus") -> bool:
	"""Create entanglement between two plots (PLOT INFRASTRUCTURE MODEL)

	NEW: Entanglement is plot-level infrastructure (like gates)
	- Plots remember entanglement links even after harvest/replant
	- When planting in an entangled plot, quantum states auto-entangle

	Args:
		pos_a: Position of first plot
		pos_b: Position of second plot
		bell_type: Type of Bell state (used when both plots are planted)

	Returns:
		true if entanglement infrastructure created successfully
	"""
	if not _plot_manager.is_valid_position(pos_a) or not _plot_manager.is_valid_position(pos_b):
		return false

	if pos_a == pos_b:
		return false

	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)

	if plot_a == null or plot_b == null:
		return false

	# CRITICAL: Cross-biome entanglement prevention (Semantic Revolution requirement)
	# Each biome is an isolated quantum system - entanglement cannot span biomes
	var biome_id_a = _biome_routing.get_biome_id_for_plot(pos_a)
	var biome_id_b = _biome_routing.get_biome_id_for_plot(pos_b)

	if biome_id_a != biome_id_b:
		push_warning("FORBIDDEN: Cannot entangle plots from different biomes!")
		push_warning("   Plot %s biome: %s" % [pos_a, biome_id_a if biome_id_a != "" else "unassigned"])
		push_warning("   Plot %s biome: %s" % [pos_b, biome_id_b if biome_id_b != "" else "unassigned"])
		if _verbose:
			_verbose.warn("farm", "❌", "Cross-biome entanglement blocked: %s (%s) ↔ %s (%s)" % [
				pos_a, biome_id_a, pos_b, biome_id_b
			])
		return false

	if biome_id_a == "":
		push_warning("Cannot entangle plots with no biome assignment")
		if _verbose:
			_verbose.warn("farm", "❌", "Entanglement blocked: plots must be assigned to a biome")
		return false

	# NEW: Set up register-level entanglement blueprints (works even if not planted)
	var reg_a = _biome_routing.get_register_for_plot(pos_a)
	var reg_b = _biome_routing.get_register_for_plot(pos_b)
	var biome_ref = _biome_routing.get_biome_for_plot(pos_a)
	if biome_ref and biome_ref.quantum_computer and reg_a >= 0 and reg_b >= 0:
		var qc = biome_ref.quantum_computer
		var infra_a = qc._ensure_register_infra(reg_a)
		var infra_b = qc._ensure_register_infra(reg_b)
		if reg_b not in infra_a["entanglement_blueprints"]:
			infra_a["entanglement_blueprints"].append(reg_b)
		if reg_a not in infra_b["entanglement_blueprints"]:
			infra_b["entanglement_blueprints"].append(reg_a)
		if _verbose:
			_verbose.debug("farm", "🏗️", "Register infrastructure: reg %d ↔ reg %d (entanglement blueprint installed)" % [reg_a, reg_b])

	# Mark Bell gate in biome layer (historical entanglement record)
	var biome_a = _biome_routing.get_biome_for_plot(pos_a)
	if biome_a and biome_a.has_method("mark_bell_gate"):
		biome_a.mark_bell_gate([pos_a, pos_b])

	# If both plots are NOT planted, just set up infrastructure and return
	if not plot_a.is_planted or not plot_b.is_planted:
		if _verbose:
			_verbose.info("farm", "→", "Infrastructure ready. Quantum entanglement will auto-activate when both plots are planted.")
		entanglement_created.emit(pos_a, pos_b)
		return true  # Infrastructure created successfully

	# Both plots are planted → Create quantum entanglement using helper
	var success = _create_quantum_entanglement(pos_a, pos_b, bell_type)
	if success:
		entanglement_created.emit(pos_a, pos_b)
	return success


func create_triplet_entanglement(pos_a: Vector2i, pos_b: Vector2i, pos_c: Vector2i) -> bool:
	"""Create triple entanglement (3-qubit Bell state) for kitchen measurement

	This marks three plots as a potential kitchen measurement target.
	The spatial arrangement of the plots determines the Bell state type:
	- Horizontal/Vertical/Diagonal → GHZ state
	- L-shape → W state
	- T-shape → Cluster state

	Args:
		pos_a, pos_b, pos_c: Positions of the three plots

	Returns:
		true if triplet entanglement infrastructure created successfully
	"""
	if not _plot_manager.is_valid_position(pos_a) or not _plot_manager.is_valid_position(pos_b) or not _plot_manager.is_valid_position(pos_c):
		return false

	# All positions must be different
	if pos_a == pos_b or pos_b == pos_c or pos_a == pos_c:
		return false

	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)
	var plot_c = _plot_manager.get_plot(pos_c)

	if plot_a == null or plot_b == null or plot_c == null:
		return false

	# CRITICAL: Cross-biome entanglement prevention (triplet version)
	var biome_id_a = _biome_routing.get_biome_id_for_plot(pos_a)
	var biome_id_b = _biome_routing.get_biome_id_for_plot(pos_b)
	var biome_id_c = _biome_routing.get_biome_id_for_plot(pos_c)

	if biome_id_a != biome_id_b or biome_id_b != biome_id_c:
		push_warning("FORBIDDEN: Cannot create triplet entanglement across different biomes!")
		push_warning("   Plot %s biome: %s" % [pos_a, biome_id_a])
		push_warning("   Plot %s biome: %s" % [pos_b, biome_id_b])
		push_warning("   Plot %s biome: %s" % [pos_c, biome_id_c])
		if _verbose:
			_verbose.warn("farm", "❌", "Cross-biome triplet entanglement blocked")
		return false

	if biome_id_a == "":
		push_warning("Cannot create triplet entanglement with unassigned plots")
		return false

	# Mark as triplet Bell gate in biome (kitchen can query these)
	var biome_a = _biome_routing.get_biome_for_plot(pos_a)
	if biome_a and biome_a.has_method("mark_bell_gate"):
		biome_a.mark_bell_gate([pos_a, pos_b, pos_c])
		if _verbose:
			_verbose.info("farm", "🔔", "Triple entanglement marked: %s, %s, %s (kitchen ready)" % [pos_a, pos_b, pos_c])

	# Emit signal for UI feedback
	entanglement_created.emit(pos_a, pos_b)  # Use first two positions for signal

	return true


func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i) -> void:
	"""Remove entanglement between two plots"""
	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)

	# Find and remove EntangledPair if it exists
	if plot_a and plot_a.quantum_state and plot_a.quantum_state.entangled_pair != null:
		var pair = plot_a.quantum_state.entangled_pair
		if pair in entangled_pairs:
			entangled_pairs.erase(pair)

		# Unlink from both qubits
		if plot_a:
			plot_a.quantum_state.entangled_pair = null
		if plot_b and plot_b.quantum_state:
			plot_b.quantum_state.entangled_pair = null

	# Also remove legacy entanglement tracking
	if plot_a:
		plot_a.remove_entanglement(plot_b.plot_id if plot_b else "")
	if plot_b:
		plot_b.remove_entanglement(plot_a.plot_id if plot_a else "")

	entanglement_removed.emit(pos_a, pos_b)


func are_plots_entangled(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	"""Check if two plots are entangled"""
	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)

	if plot_a == null or plot_b == null:
		return false

	return plot_a.entangled_plots.has(plot_b.plot_id)


# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-INFRASTRUCTURE - Called during planting
# ═══════════════════════════════════════════════════════════════════════════════

func auto_entangle_from_infrastructure(position: Vector2i) -> void:
	"""Auto-entangle quantum states when planting in infrastructurally entangled plot.

	Reads entanglement blueprints from register_infrastructure instead of plot fields.
	"""
	var plot = _plot_manager.get_plot(position)
	if not plot or not plot.is_planted:
		return

	var reg_id = _biome_routing.get_register_for_plot(position)
	if reg_id < 0:
		return

	var biome = _biome_routing.get_biome_for_plot(position)
	if not biome or not biome.quantum_computer:
		return

	var qc = biome.quantum_computer
	var blueprints = qc.get_register_infra_field(reg_id, "entanglement_blueprints", [])

	# Check all register-level entanglement blueprints
	for partner_reg in blueprints:
		# Find the plot bound to that register
		var partner_pos = _biome_routing.get_plot_for_register(partner_reg)
		if partner_pos == Vector2i(-1, -1):
			continue

		var partner_plot = _plot_manager.get_plot(partner_pos)

		# If partner is planted, entangle their quantum states
		if partner_plot and partner_plot.is_planted:
			# Check if already entangled (avoid duplicates)
			if not plot.entangled_plots.has(partner_plot.plot_id):
				_create_quantum_entanglement(position, partner_pos)
				if _verbose:
					_verbose.info("quantum", "⚡", "Auto-entangled %s ↔ %s (register blueprint activated)" % [position, partner_pos])


func auto_apply_persistent_gates(position: Vector2i) -> void:
	"""Apply persistent gate infrastructure to newly planted qubit.

	Called automatically from plant() after auto_entangle_from_infrastructure().
	Gates read from register_infrastructure (not plot fields).
	"""
	var plot = _plot_manager.get_plot(position)

	# Skip if plot not planted
	if not plot or not plot.is_planted:
		return

	var reg_id = _biome_routing.get_register_for_plot(position)
	if reg_id < 0:
		return

	var biome = _biome_routing.get_biome_for_plot(position)
	if not biome or not biome.quantum_computer:
		return

	var qc = biome.quantum_computer
	var active_gates = qc.get_active_gates_for_register(reg_id)
	if active_gates.is_empty():
		return

	if _verbose:
		_verbose.debug("farm", "🔧", "Auto-applying %d persistent gates to %s (reg %d)" % [active_gates.size(), position, reg_id])

	for gate in active_gates:
		var gate_type = gate.get("type", "")
		var linked_registers = gate.get("linked_registers", [])

		# Convert linked_registers to plot positions for cluster creation
		var linked_plots: Array = []
		for linked_reg in linked_registers:
			var linked_pos = _biome_routing.get_plot_for_register(linked_reg)
			if linked_pos != Vector2i(-1, -1):
				linked_plots.append(linked_pos)

		match gate_type:
			"bell":
				_auto_cluster_from_gate(position, linked_plots)
			"cluster":
				_auto_cluster_from_gate(position, linked_plots)
			"measure_trigger":
				if _verbose:
					_verbose.debug("farm", "👁️", "Measure trigger active on %s" % position)
			_:
				if _verbose:
					_verbose.warn("farm", "⚠️", "Unknown gate type: %s" % gate_type)


func _auto_cluster_from_gate(position: Vector2i, linked_plots: Array) -> void:
	"""Create cluster entanglement from persistent gate infrastructure.

	Called when planting in a plot that has a cluster gate.
	Entangles with all other planted plots in the linked_plots array.
	"""
	var plot = _plot_manager.get_plot(position)
	if not plot or not plot.quantum_state:
		return

	for linked_pos in linked_plots:
		if linked_pos == position:
			continue  # Skip self

		var linked_plot = _plot_manager.get_plot(linked_pos)
		if linked_plot and linked_plot.is_planted and linked_plot.quantum_state:
			# Check if already entangled
			if not plot.entangled_plots.has(linked_plot.plot_id):
				_create_quantum_entanglement(position, linked_pos)
				if _verbose:
					_verbose.info("quantum", "🔗", "Cluster gate: entangled %s ↔ %s" % [position, linked_pos])


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL HELPERS - Quantum Entanglement Creation
# ═══════════════════════════════════════════════════════════════════════════════

func _create_quantum_entanglement(pos_a: Vector2i, pos_b: Vector2i, _bell_type: String = "phi_plus") -> bool:
	"""Create quantum state entanglement (internal helper) - Model C: apply CNOT gate"""
	var plot_a = _plot_manager.get_plot(pos_a)
	var plot_b = _plot_manager.get_plot(pos_b)

	if not plot_a or not plot_b or not plot_a.is_planted or not plot_b.is_planted:
		return false

	# MODEL C: Entanglement via apply_gate_2q
	var biome_a = _biome_routing.get_biome_for_plot(pos_a)
	var biome_b = _biome_routing.get_biome_for_plot(pos_b)

	# Ensure both plots are in same biome
	if biome_a != biome_b:
		push_error("Cannot entangle plots from different biomes - each biome has its own quantum_computer")
		return false

	# Get register IDs from biome routing
	var reg_id_a = _biome_routing.get_register_for_plot(pos_a)
	var reg_id_b = _biome_routing.get_register_for_plot(pos_b)

	if reg_id_a < 0 or reg_id_b < 0:
		push_error("Cannot entangle: plots don't have valid register allocations")
		return false

	# Model C: Apply entangling gate (CNOT) and update entanglement graph
	if biome_a and biome_a.quantum_computer:
		var qc = biome_a.quantum_computer
		# Check if already entangled via entanglement_graph
		var entangled_ids = qc.get_entangled_component(reg_id_a)
		if reg_id_b in entangled_ids:
			if _verbose:
				_verbose.info("quantum", "ℹ️", "Plots already entangled")
			plot_a.add_entanglement(plot_b.plot_id, 1.0)
			plot_b.add_entanglement(plot_a.plot_id, 1.0)
			return true

		# Apply H then CNOT to create Bell state
		var H = QuantumGateLibrary.get_gate("H")["matrix"]
		var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]

		qc.apply_gate(reg_id_a, H)  # Put first qubit in superposition
		qc.apply_gate_2q(reg_id_a, reg_id_b, CNOT)  # Entangle

		if _verbose:
			_verbose.info("quantum", "🔗", "Created entanglement via H + CNOT: %d ↔ %d" % [reg_id_a, reg_id_b])
	else:
		push_error("Biome has no quantum_computer for entanglement")
		return false

	# Update gameplay entanglement tracking (metadata for visualization)
	plot_a.add_entanglement(plot_b.plot_id, 1.0)
	plot_b.add_entanglement(plot_a.plot_id, 1.0)

	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CLUSTER HELPERS - Multi-qubit state management
# ═══════════════════════════════════════════════════════════════════════════════

func update_cluster_gameplay_connections(cluster) -> void:
	"""Update WheatPlot.entangled_plots for all qubits in cluster (for topology)"""
	var plot_ids = cluster.get_all_plot_ids()

	# Each plot should be connected to all others in cluster
	for plot_id in plot_ids:
		var plot = _plot_manager.get_plot_by_id(plot_id)
		if not plot:
			continue

		# Clear old connections, rebuild from cluster
		plot.entangled_plots.clear()

		# Add all other plots in cluster
		for other_id in plot_ids:
			if other_id != plot_id:
				plot.entangled_plots[other_id] = 1.0  # Full strength


func add_to_cluster(cluster, new_plot, control_index: int) -> bool:
	"""Add new qubit to existing cluster via CNOT gate"""

	# Check cluster size limit (recommend 6-qubit max)
	if cluster.get_qubit_count() >= 6:
		if _verbose:
			_verbose.warn("quantum", "⚠️", "Cluster at max size (6 qubits)")
		return false

	# Add qubit to cluster with CNOT gate
	cluster.entangle_new_qubit_cnot(new_plot.quantum_state, new_plot.plot_id, control_index)

	# Link qubit to cluster
	new_plot.quantum_state.entangled_cluster = cluster
	new_plot.quantum_state.cluster_qubit_index = cluster.get_qubit_count() - 1

	# Update gameplay entanglement tracking (for topology)
	update_cluster_gameplay_connections(cluster)

	if _verbose:
		_verbose.info("quantum", "🔗", "Added %s to cluster (size: %d)" % [new_plot.plot_id, cluster.get_qubit_count()])
	return true


func upgrade_pair_to_cluster(pair, new_plot) -> bool:
	"""Upgrade 2-qubit pair to 3-qubit cluster"""

	# Create new cluster
	var cluster = EntangledCluster.new()

	# Find the two plots in the pair
	var plot_a = _plot_manager.get_plot_by_id(pair.qubit_a_id)
	var plot_b = _plot_manager.get_plot_by_id(pair.qubit_b_id)

	if not plot_a or not plot_b:
		if _verbose:
			_verbose.warn("quantum", "⚠️", "Cannot find plots in pair")
		return false

	# Add both qubits to cluster
	cluster.add_qubit(plot_a.quantum_state, plot_a.plot_id)
	cluster.add_qubit(plot_b.quantum_state, plot_b.plot_id)

	# Create GHZ state (|00⟩ + |11⟩) - equivalent to Bell state
	cluster.create_ghz_state()

	# Add third qubit via CNOT
	cluster.entangle_new_qubit_cnot(new_plot.quantum_state, new_plot.plot_id, 0)

	# Update qubit references
	plot_a.quantum_state.entangled_pair = null
	plot_a.quantum_state.entangled_cluster = cluster
	plot_a.quantum_state.cluster_qubit_index = 0

	plot_b.quantum_state.entangled_pair = null
	plot_b.quantum_state.entangled_cluster = cluster
	plot_b.quantum_state.cluster_qubit_index = 1

	new_plot.quantum_state.entangled_cluster = cluster
	new_plot.quantum_state.cluster_qubit_index = 2

	# Remove old pair, add cluster
	entangled_pairs.erase(pair)
	entangled_clusters.append(cluster)

	# Update gameplay connections
	update_cluster_gameplay_connections(cluster)

	if _verbose:
		_verbose.info("quantum", "✨", "Upgraded pair to 3-qubit cluster: %s" % cluster.get_state_string())
	return true


func handle_cluster_collapse(cluster) -> void:
	"""Handle measurement cascade when cluster is measured"""
	var plot_ids = cluster.get_all_plot_ids()

	# Update all qubits from collapsed cluster state
	for i in range(cluster.get_qubit_count()):
		var plot_id = plot_ids[i]
		var plot = _plot_manager.get_plot_by_id(plot_id)
		if not plot:
			continue

		# Get reduced density matrix for this qubit (partial trace)
		# For now: simplified - cluster measurement collapses to product state
		# Qubits become separable after measurement

		# Clear cluster reference
		plot.quantum_state.entangled_cluster = null
		plot.quantum_state.cluster_qubit_index = -1

		# Clear gameplay connections
		plot.entangled_plots.clear()

	# Remove cluster from tracking
	entangled_clusters.erase(cluster)

	if _verbose:
		_verbose.info("quantum", "💥", "Cluster collapsed - %d qubits now separable" % plot_ids.size())


func clear_plot_entanglements(plot) -> void:
	"""Clear all entanglements for a plot (called during harvest/measurement)."""
	for partner_id in plot.entangled_plots.keys():
		var partner_pos = _plot_manager.find_plot_by_id(partner_id)
		if partner_pos != Vector2i(-1, -1):
			var partner_plot = _plot_manager.get_plot(partner_pos)
			if partner_plot:
				partner_plot.entangled_plots.erase(plot.plot_id)
	plot.entangled_plots.clear()
