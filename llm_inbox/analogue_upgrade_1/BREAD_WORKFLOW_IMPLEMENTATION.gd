# ==============================================================================
# BREAD WORKFLOW IMPLEMENTATION
# ==============================================================================
# This is the COMPLETE implementation of how bread works in the analog model.
# Copy this into QuantumKitchen_Biome.gd
# ==============================================================================

class_name QuantumKitchen_Biome
extends BiomeBase

# ------------------------------------------------------------------------------
# STATE
# ------------------------------------------------------------------------------

var quantum_computer: QuantumComputer = null
var active_drives: Array = []  # [{emoji, rate, remaining}, ...]

# Ideal conditions (the "sweet spot")
const IDEAL_FIRE = 0.7
const IDEAL_WATER = 0.5
const IDEAL_FLOUR = 0.6

# Physics constants
const COUPLING_OMEGA = 0.15  # |111⟩ ↔ |000⟩ coupling strength
const DRIVE_RATE = 0.5       # Lindblad drive rate
const DECAY_RATE = 0.05      # Natural decay toward |111⟩

# ------------------------------------------------------------------------------
# INITIALIZATION
# ------------------------------------------------------------------------------

func _ready():
	_initialize_kitchen()


func _initialize_kitchen() -> void:
	"""Create 3-qubit system. Start in |111⟩ (cold, dry, grain)."""
	
	quantum_computer = QuantumComputer.new("Kitchen")
	
	# Register three axes
	# Qubit 0: Temperature  |0⟩=🔥  |1⟩=❄️
	# Qubit 1: Moisture     |0⟩=💧  |1⟩=🏜️
	# Qubit 2: Substance    |0⟩=💨  |1⟩=🌾
	quantum_computer.allocate_axis("🔥", "❄️")
	quantum_computer.allocate_axis("💧", "🏜️")
	quantum_computer.allocate_axis("💨", "🌾")
	
	# Initialize to |111⟩ = index 7
	quantum_computer.initialize_basis(7)
	
	print("🍳 Kitchen ready: 8D state, starting in |111⟩ (❄️🏜️🌾)")


func reset_to_ground() -> void:
	"""Reset to |111⟩ after measurement."""
	quantum_computer.initialize_basis(7)
	active_drives.clear()
	print("🍳 Kitchen reset to |111⟩")

# ------------------------------------------------------------------------------
# PLAYER ACTIONS: Spend resources to activate drives
# ------------------------------------------------------------------------------

func add_fire(credits: int) -> bool:
	"""Player spends fire credits to heat the kitchen.
	
	Args:
		credits: Amount of fire credits to spend
	
	Returns:
		true if drive activated
	"""
	if credits <= 0:
		return false
	
	# Convert credits to drive duration
	var duration = credits * 0.1  # 10 credits = 1 second of driving
	
	active_drives.append({
		"emoji": "🔥",
		"rate": DRIVE_RATE,
		"remaining": duration
	})
	
	print("🔥 Fire drive: %.1fs (spent %d credits)" % [duration, credits])
	return true


func add_water(credits: int) -> bool:
	"""Player spends water credits to moisten the dough."""
	if credits <= 0:
		return false
	
	var duration = credits * 0.1
	active_drives.append({
		"emoji": "💧",
		"rate": DRIVE_RATE,
		"remaining": duration
	})
	
	print("💧 Water drive: %.1fs (spent %d credits)" % [duration, credits])
	return true


func add_flour(credits: int) -> bool:
	"""Player spends flour credits to add flour to dough."""
	if credits <= 0:
		return false
	
	var duration = credits * 0.1
	active_drives.append({
		"emoji": "💨",
		"rate": DRIVE_RATE,
		"remaining": duration
	})
	
	print("💨 Flour drive: %.1fs (spent %d credits)" % [duration, credits])
	return true

# ------------------------------------------------------------------------------
# POPULATION QUERIES
# ------------------------------------------------------------------------------

func p_fire() -> float:
	"""P(qubit 0 = |0⟩) = probability kitchen is hot."""
	return quantum_computer.get_population("🔥")


func p_water() -> float:
	"""P(qubit 1 = |0⟩) = probability dough is wet."""
	return quantum_computer.get_population("💧")


func p_flour() -> float:
	"""P(qubit 2 = |0⟩) = probability substance is flour."""
	return quantum_computer.get_population("💨")


func p_bread() -> float:
	"""P(|000⟩) = probability of getting bread on measurement.
	
	THIS IS THE KEY NUMBER. When this is high, player should harvest.
	🍞 is NOT a qubit. It's the outcome when we measure and find |000⟩.
	"""
	return quantum_computer.get_basis_probability(0)


func p_ground() -> float:
	"""P(|111⟩) = probability still in ground state."""
	return quantum_computer.get_basis_probability(7)

# ------------------------------------------------------------------------------
# DETUNING (Sweet Spot Physics)
# ------------------------------------------------------------------------------

func compute_detuning() -> float:
	"""How far from ideal conditions.
	
	Δ = 0 at sweet spot (resonance, fast rotation)
	Δ >> 0 off resonance (rotation suppressed)
	"""
	var d2 = 0.0
	d2 += pow(p_fire() - IDEAL_FIRE, 2)
	d2 += pow(p_water() - IDEAL_WATER, 2)
	d2 += pow(p_flour() - IDEAL_FLOUR, 2)
	
	return sqrt(d2) * 5.0  # Scale to Hamiltonian units


func effective_baking_rate() -> float:
	"""How fast population flows toward |000⟩.
	
	Ω_eff = Ω / √(1 + (Δ/Ω)²)
	
	At resonance: Ω_eff ≈ Ω (maximum)
	Off resonance: Ω_eff → 0
	"""
	var delta = compute_detuning()
	return COUPLING_OMEGA / sqrt(1.0 + pow(delta / COUPLING_OMEGA, 2))

# ------------------------------------------------------------------------------
# PHYSICS EVOLUTION (Called every frame)
# ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_process_drives(delta)
	_apply_hamiltonian(delta)
	_apply_natural_decay(delta)


func _process_drives(dt: float) -> void:
	"""Apply active Lindblad drives."""
	var completed = []
	
	for drive in active_drives:
		if drive["remaining"] <= 0:
			completed.append(drive)
			continue
		
		# Apply drive: push population toward north pole of this emoji's qubit
		quantum_computer.apply_drive(drive["emoji"], drive["rate"], dt)
		drive["remaining"] -= dt
	
	for drive in completed:
		active_drives.erase(drive)


func _apply_hamiltonian(dt: float) -> void:
	"""Apply detuning Hamiltonian: rotates |111⟩ ↔ |000⟩.
	
	H = Δ/2 (|0⟩⟨0| - |7⟩⟨7|) + Ω (|0⟩⟨7| + |7⟩⟨0|)
	
	This is simplified evolution - just update ρ[0,0] and ρ[7,7]
	based on effective rotation rate.
	"""
	var omega_eff = effective_baking_rate()
	
	# Rotation angle this frame
	var angle = omega_eff * dt
	
	# Get current populations
	var p0 = quantum_computer.get_basis_probability(0)  # |000⟩
	var p7 = quantum_computer.get_basis_probability(7)  # |111⟩
	
	# Rabi oscillation: population transfers between |0⟩ and |7⟩
	# Simplified: d(p0)/dt = omega_eff * (p7 - p0) when near resonance
	var transfer = angle * (p7 - p0) * 0.5
	
	# Apply transfer (this is approximate but captures the physics)
	quantum_computer.transfer_population(7, 0, transfer)


func _apply_natural_decay(dt: float) -> void:
	"""Everything drifts back toward |111⟩ without player input.
	
	This creates time pressure - player must maintain conditions.
	"""
	# Decay each axis toward south pole (|1⟩)
	quantum_computer.apply_decay("🔥", DECAY_RATE, dt)  # 🔥 → ❄️
	quantum_computer.apply_decay("💧", DECAY_RATE, dt)  # 💧 → 🏜️
	quantum_computer.apply_decay("💨", DECAY_RATE, dt)  # 💨 → 🌾

# ------------------------------------------------------------------------------
# MEASUREMENT (Harvest)
# ------------------------------------------------------------------------------

func harvest() -> Dictionary:
	"""Player harvests the kitchen. Performs projective measurement.
	
	Returns:
		{
			success: bool,      # Did measurement happen
			got_bread: bool,    # Did we collapse to |000⟩
			yield: int,         # Bread amount (0-100)
			collapsed_to: int   # Basis state index (0-7)
		}
	"""
	var rho = quantum_computer.density_matrix
	
	# Sample from probability distribution
	var roll = randf()
	var cumulative = 0.0
	var outcome = 7  # Default
	
	for i in range(8):
		cumulative += rho.get_element(i, i).re
		if roll < cumulative:
			outcome = i
			break
	
	# Collapse to measured state
	quantum_computer.initialize_basis(outcome)
	
	# Determine result
	var got_bread = (outcome == 0)  # |000⟩ = bread
	var bread_yield = 100 if got_bread else 0
	
	# Partial credit for close states (optional)
	# |001⟩, |010⟩, |100⟩ = one bit wrong = partial bread
	if outcome in [1, 2, 4]:
		bread_yield = 30
		got_bread = true
	
	var result = {
		"success": true,
		"got_bread": got_bread,
		"yield": bread_yield,
		"collapsed_to": outcome
	}
	
	if got_bread:
		print("🍞 BREAD! Collapsed to |%s⟩, yield=%d" % [
			_basis_string(outcome), bread_yield])
	else:
		print("💀 Failed. Collapsed to |%s⟩" % _basis_string(outcome))
	
	# Reset for next attempt
	reset_to_ground()
	
	return result


func _basis_string(index: int) -> String:
	"""Convert basis index to binary string."""
	var s = ""
	for i in range(3):
		s += "0" if ((index >> (2 - i)) & 1) == 0 else "1"
	return s

# ------------------------------------------------------------------------------
# UI HELPERS
# ------------------------------------------------------------------------------

func get_status() -> Dictionary:
	"""Get current kitchen state for UI display."""
	return {
		"p_fire": p_fire(),
		"p_water": p_water(),
		"p_flour": p_flour(),
		"p_bread": p_bread(),
		"detuning": compute_detuning(),
		"baking_rate": effective_baking_rate(),
		"active_drives": active_drives.size()
	}


# ==============================================================================
# FARMGRID INTEGRATION
# ==============================================================================
# Put this in FarmGrid.gd, in _process_kitchens()
# ==============================================================================

# IN FARMGRID.GD:

func _process_kitchens(delta: float) -> void:
	"""Process kitchen buildings each frame.
	
	Kitchen evolution happens automatically via _process().
	This method handles:
	1. Checking if player wants to harvest
	2. Converting economy resources to drives
	"""
	
	for kitchen_pos in kitchen_buildings:
		var kitchen_biome = biomes.get("Kitchen") as QuantumKitchen_Biome
		if not kitchen_biome:
			continue
		
		# Kitchen physics runs in its own _process()
		# Nothing to do here except handle player actions
		pass


func kitchen_add_resource(emoji: String, credits: int) -> bool:
	"""Called when player adds resource to kitchen.
	
	Example: Player clicks "Add Fire" button with 50 credits.
	"""
	var kitchen = biomes.get("Kitchen") as QuantumKitchen_Biome
	if not kitchen:
		return false
	
	# Validate player has credits
	if farm_economy.get_resource(emoji) < credits:
		print("Not enough %s credits!" % emoji)
		return false
	
	# Consume credits
	farm_economy.remove_resource(emoji, credits, "kitchen_input")
	
	# Activate drive
	match emoji:
		"🔥":
			return kitchen.add_fire(credits)
		"💧":
			return kitchen.add_water(credits)
		"💨":
			return kitchen.add_flour(credits)
		_:
			push_error("Unknown kitchen resource: %s" % emoji)
			return false


func kitchen_harvest() -> Dictionary:
	"""Called when player clicks harvest button."""
	var kitchen = biomes.get("Kitchen") as QuantumKitchen_Biome
	if not kitchen:
		return {"success": false}
	
	var result = kitchen.harvest()
	
	# Add bread to economy if successful
	if result["got_bread"]:
		var bread_credits = result["yield"] * FarmEconomy.QUANTUM_TO_CREDITS
		farm_economy.add_resource("🍞", bread_credits, "kitchen_harvest")
	
	return result


# ==============================================================================
# QUANTUM COMPUTER HELPER METHODS
# ==============================================================================
# Add these to QuantumComputer.gd if not already present
# ==============================================================================

# IN QUANTUMCOMPUTER.GD:

func transfer_population(from_basis: int, to_basis: int, amount: float) -> void:
	"""Transfer population between basis states.
	
	Used for simplified Hamiltonian evolution.
	Preserves trace.
	"""
	amount = clamp(amount, 0.0, density_matrix.get_element(from_basis, from_basis).re)
	
	var p_from = density_matrix.get_element(from_basis, from_basis)
	var p_to = density_matrix.get_element(to_basis, to_basis)
	
	density_matrix.set_element(from_basis, from_basis, 
		Complex.new(p_from.re - amount, 0.0))
	density_matrix.set_element(to_basis, to_basis,
		Complex.new(p_to.re + amount, 0.0))


func apply_decay(emoji: String, rate: float, dt: float) -> void:
	"""Apply decay toward south pole (|1⟩) for this emoji's qubit.
	
	Opposite of apply_drive - pushes toward |1⟩ instead of |0⟩.
	"""
	if not register_map.has(emoji):
		return
	
	var qubit = register_map.qubit(emoji)
	var north_pole = 0
	var south_pole = 1
	
	# Drive toward south (decay)
	_apply_lindblad_1q(qubit, north_pole, south_pole, rate, dt)


func get_trace() -> float:
	"""Return Tr(ρ) for validation."""
	var trace = 0.0
	for i in range(density_matrix.rows):
		trace += density_matrix.get_element(i, i).re
	return trace
