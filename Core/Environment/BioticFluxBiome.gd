class_name BioticFluxBiome
extends "res://Core/Environment/BiomeBase.gd"

## BioticFlux Biome - Environmental quantum ecosystem with sun/moon cycling
## Manages all quantum objects: celestial (sun/moon), native (biome-specific), farm (plantable)
## Manages Icons: wheat_icon (🌾↔🏰 agrarian/imperium)
## Manages temperature, decoherence, and all quantum couplings

# Celestial objects (immutable, drive the system)
var sun_qubit: DualEmojiQubit = null  # (☀️, 🌙) - immutable celestial anchor
var sun_moon_period: float = 20.0  # seconds for full day-night cycle

# Icon system moved to faction-based IconRegistry (deprecated variables removed)

# Energy transfer parameters (non-Hamiltonian, affects radius/energy only)
# Tuned for 3-day growth: 0.3→0.9 in 60 seconds (3 full sun-moon cycles)
# With alignment formula: rate_avg = base * amplitude * alignment_avg * icon_influence
# Alignment averages to 0.5 over a full day-night cycle
var base_energy_rate: float = 2.45
var wheat_energy_influence: float = 0.034  # cos²(165°/2) - weak (wheat grows minimally alone) - 2x for better growth
var mushroom_energy_influence: float = 0.983  # cos²(15°/2) - strong (mushrooms grow well)

# Plot type system: Biome owns ALL qubits regardless of type
enum PlotType { CELESTIAL, NATIVE, FARM }
var plots_by_type: Dictionary = {  # PlotType -> Array[Vector2i]
	PlotType.CELESTIAL: [],
	PlotType.NATIVE: [],
	PlotType.FARM: []
}
var plot_types: Dictionary = {}  # Vector2i -> PlotType (to look up type of position)

# Static mode flag (for testing without quantum evolution)
var is_static: bool = false  # If true, disable all quantum evolution

# Temperature control (Kelvin)
var base_temperature: float = 300.0  # 300K baseline
var temperature_grid: Dictionary = {}  # Vector2i(x,y) -> local_temperature

# Decoherence base rates (modified by temperature)
var T1_base_rate: float = 0.001  # Amplitude damping
var T2_base_rate: float = 0.002  # Phase damping

# Visualization - Celestial object colors and positions
var sun_color: Color = Color.YELLOW  # Updated each frame based on sun.theta
var sun_display_theta: float = 0.0  # Sun theta for UI (0=☀️ yellow, π=🌑 purple)

# ═══════════════════════════════════════════════════════════════════════════
# EMOJI PAIRINGS: Registered in _ready() via BiomeBase.register_emoji_pair()
# ═══════════════════════════════════════════════════════════════════════════


func _ready():
	"""Initialize biome with sun/moon qubit and icon states"""
	super._ready()

	# Note: Bath initialization happens in BiomeBase._ready() → _initialize_bath()
	# which calls our _initialize_bath_biotic_flux() override

	# Register emoji pairings for this biome (uses BiomeBase system)
	# Must align with quantum_computer axes: ☀/🌙, 🌾/🍄, 🍂/💀
	register_emoji_pair("🌾", "🍄")  # Wheat ↔ Mushroom (Flora axis - qubit 1)
	register_emoji_pair("🍄", "🍂")  # Mushroom ↔ Detritus (for mushroom plots)
	register_emoji_pair("☀", "🌙")   # Sun ↔ Moon (Celestial axis - qubit 0)
	register_emoji_pair("🍂", "💀")  # Detritus ↔ Death (Matter axis - qubit 2)

	# Register planting capabilities (Parametric System - Phase 1)
	# Costs from BUILD_CONFIGS, emoji pairs for quantum superposition
	register_planting_capability("🌾", "👥", "wheat", {"🌾": 1}, "Wheat", false)
	register_planting_capability("🍄", "🍂", "mushroom", {"🍄": 10, "🍂": 10}, "Mushroom", false)
	register_planting_capability("🍅", "🌌", "tomato", {"🌾": 1}, "Tomato", false)

	# Configure visual properties for QuantumForceGraph
	# Layout: BioticFlux (UIOP) in bottom-center
	visual_color = Color(0.4, 0.6, 0.8, 0.3)  # Blue
	visual_label = "🌿 Biotic Flux"
	visual_center_offset = Vector2(0.0, 0.45)  # Bottom-center
	visual_oval_width = 640.0   # 2x larger for prominent display
	visual_oval_height = 400.0  # Golden ratio maintained



func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "BioticFlux"


func get_paired_emoji(emoji: String) -> String:
	"""Get the paired emoji for this biome's quantum axis

	When a qubit is harvested/measured, the biome specifies what
	the 'other side' of the superposition was. This preserves
	quantum heritage information in classical resources.
	"""
	return emoji_pairings.get(emoji, "?")


func _update_sun_visualization() -> void:
	"""Update sun color based on quantum state - yellow (day) to deep blue/purple (night)"""
	if not sun_qubit:
		return

	sun_display_theta = sun_qubit.theta

	# Color transition: θ=0 (yellow ☀️) → θ=π (deep purple/blue 🌙)
	# Using HSV interpolation for smooth color shift
	var day_night_progress = sun_display_theta / PI  # 0.0 (day) to 1.0 (night)

	# Yellow (day): HSV(60°, 1.0, 1.0)
	# Deep purple (night): HSV(270°, 0.8, 0.3)
	var day_hue = 60.0 / 360.0  # Yellow
	var night_hue = 270.0 / 360.0  # Deep purple

	var hue = lerp(day_hue, night_hue, day_night_progress)
	var saturation = lerp(1.0, 0.8, day_night_progress)
	var brightness = lerp(1.0, 0.3, day_night_progress)

	sun_color = Color.from_hsv(hue, saturation, brightness, 1.0)


func _initialize_bath() -> void:
	"""Initialize Model C quantum computer for BioticFlux biome.

	MODEL C: 3-qubit analog system with RegisterMap
	  Qubit 0 (Celestial): ☀ (north) ↔ 🌙 (south)
	  Qubit 1 (Flora):     🌾 (north) ↔ 🍄 (south)
	  Qubit 2 (Matter):    🍂 (north) ↔ 💀 (south)

	Basis states (8 total):
	  |000⟩ = ☀🌾🍂 = Sunny wheat with organic matter
	  |111⟩ = 🌙🍄💀 = Moonlit mushrooms with death/decay
	  ... and 6 intermediate states

	Dynamics (via Icon-defined operators):
	  - Sun/Moon: Hamiltonian oscillation (Rabi-like)
	  - Wheat←Sun: Lindblad transfer (growth from sunlight)
	  - Mushroom←Moon: Lindblad transfer (growth from moonlight)
	  - Decay: Lindblad relaxation toward equilibrium
	"""
	print("🌿 Initializing BioticFlux Model C quantum computer...")

	# Create QuantumComputer with RegisterMap
	quantum_computer = QuantumComputer.new("BioticFlux")

	# Allocate 3 qubits with emoji axes
	quantum_computer.allocate_axis(0, "☀", "🌙")   # Celestial: Sun/Moon
	quantum_computer.allocate_axis(1, "🌾", "🍄")  # Flora: Wheat/Mushroom
	quantum_computer.allocate_axis(2, "🍂", "💀")  # Matter: Organic/Death

	# Initialize to balanced state (½☀ + ½🌙)(½🌾 + ½🍄)(½🍂 + ½💀)
	# For simplicity, start with |000⟩ = ☀🌾🍂 (sunny, wheat, organic)
	quantum_computer.initialize_basis(0)

	print("  📊 RegisterMap configured (3 qubits, 8 basis states)")

	# Get Icons from IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("🌿 IconRegistry not available!")
		return

	var icon_emojis = ["☀", "🌙", "🌾", "🍄", "🍂", "💀"]
	var icons = {}

	for emoji in icon_emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons[emoji] = icon
		else:
			push_warning("🌿 Icon not found: %s" % emoji)

	# Tune BioticFlux-specific Icon parameters
	var wheat_icon_ref = icon_registry.get_icon("🌾")
	if wheat_icon_ref:
		wheat_icon_ref.lindblad_incoming["☀"] = 0.017
		print("  🌾 Wheat: Lindblad incoming from ☀ = 0.017")

	var mushroom_icon_ref = icon_registry.get_icon("🍄")
	if mushroom_icon_ref:
		mushroom_icon_ref.lindblad_incoming["🌙"] = 0.40
		print("  🍄 Mushroom: Lindblad incoming from 🌙 = 0.40")

	# Build operators using cached method
	build_operators_cached("BioticFluxBiome", icons)

	print("  ✅ Hamiltonian: %dx%d matrix" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
	])
	print("  ✅ Lindblad: %d operators + %d gated configs" % [
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()])
	print("  ✅ BioticFlux Model C ready (analog evolution enabled)")


func rebuild_quantum_operators() -> void:
	"""Rebuild Hamiltonian and Lindblad operators after IconRegistry is ready.

	Called by BootManager in Stage 3A to ensure operators are built with
	complete Icon definitions from the faction system.
	"""
	if not quantum_computer:
		return

	print("  🔧 BioticFlux: Rebuilding quantum operators...")

	# Get Icons from IconRegistry (now guaranteed to be ready)
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_warning("🌿 IconRegistry not available for BioticFlux rebuild!")
		return

	var icon_emojis = ["☀", "🌙", "🌾", "🍄", "🍂", "💀"]
	var icons = {}

	for emoji in icon_emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons[emoji] = icon
		else:
			push_warning("🌿 Icon not found during rebuild: %s" % emoji)

	# Tune BioticFlux-specific Icon parameters
	var wheat = icon_registry.get_icon("🌾")
	if wheat:
		wheat.lindblad_incoming["☀"] = 0.017  # Wheat gains from sun

	var mushroom = icon_registry.get_icon("🍄")
	if mushroom:
		mushroom.lindblad_incoming["🌙"] = 0.40  # Mushroom gains from moon

	# Rebuild operators using cached method
	build_operators_cached("BioticFluxBiome", icons)

	print("  ✅ BioticFlux: Hamiltonian %dx%d, Lindblad %d operators + %d gated" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()])


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Update biome with quantum evolution (Model C)"""
	# Skip all evolution if in static mode (for testing)
	if is_static:
		return

	# MODEL C: Evolve quantum computer under Lindblad master equation
	if quantum_computer:
		quantum_computer.evolve(dt)

		# SEMANTIC TOPOLOGY: Record phase space trajectory
		_record_attractor_snapshot()

	# Apply semantic drift game mechanics (🌀 chaos vs ✨ stability)
	# This perturbs icon couplings when 🌀 population is high
	super._update_quantum_substrate(dt)

	# Update visualizations from quantum state
	_update_sun_visualization_from_quantum()
	_update_temperature_from_quantum()


func _update_sun_visualization_from_quantum() -> void:
	"""Update sun color based on quantum state (Model C)

	Queries quantum_computer for ☀/🌙 populations
	Color transition: yellow (day) → deep purple (night)
	"""
	if not quantum_computer:
		return

	# Get sun/moon populations from quantum computer
	var p_sun = quantum_computer.get_population("☀")
	var p_moon = quantum_computer.get_population("🌙")

	# Convert populations to theta (0 = sun, π = moon)
	# p_sun = cos²(θ/2) → θ = 2 * acos(√p_sun)
	var theta = 0.0
	if p_sun + p_moon > 0.001:
		# Normalize and compute angle
		var p_sun_norm = p_sun / (p_sun + p_moon)
		theta = 2.0 * acos(clamp(sqrt(p_sun_norm), 0.0, 1.0))
	sun_display_theta = theta

	# Color transition: θ=0 (yellow ☀️) → θ=π (deep purple/blue 🌙)
	var day_night_progress = sun_display_theta / PI  # 0.0 (day) to 1.0 (night)

	# Yellow (day): HSV(60°, 1.0, 1.0) → Deep purple (night): HSV(270°, 0.8, 0.3)
	var day_hue = 60.0 / 360.0  # Yellow
	var night_hue = 270.0 / 360.0  # Deep purple

	var hue = lerp(day_hue, night_hue, day_night_progress)
	var saturation = lerp(1.0, 0.8, day_night_progress)
	var brightness = lerp(1.0, 0.3, day_night_progress)

	sun_color = Color.from_hsv(hue, saturation, brightness, 1.0)


func _update_temperature_from_quantum() -> void:
	"""Update temperature based on quantum state (Model C)

	Temperature varies with sun/moon dominance
	Peaks at both noon (sun dominant) and midnight (moon dominant)
	"""
	if not quantum_computer:
		return

	# Rabi-like oscillation: peaks at both θ=0 (noon) and θ=π (midnight)
	# Using the cached sun_display_theta from visualization update
	var intensity = (1.0 + cos(2.0 * sun_display_theta)) / 2.0

	# Temperature ranges from 300K (twilight) to 400K (noon/midnight)
	var heat_factor = intensity * 100.0
	base_temperature = 300.0 + heat_factor


## Decoherence Rate Queries

func get_T1_rate(position: Vector2i) -> float:
	"""Get amplitude damping rate (T1) at position

	T1 increases with temperature (hotter → faster energy loss)
	"""
	var temp = temperature_grid.get(position, base_temperature)
	return T1_base_rate * (temp / 300.0)


func get_T2_rate(position: Vector2i) -> float:
	"""Get phase damping rate (T2) at position

	T2 increases with temperature (hotter → faster dephasing)
	"""
	var temp = temperature_grid.get(position, base_temperature)
	return T2_base_rate * (temp / 300.0)


## Quantum Substrate Management (Emoji Math)
## NOTE: create_quantum_state, get_qubit, measure_qubit, clear_qubit are inherited from BiomeBase

func inject_planting(position: Vector2i, wheat_amount: float, labor_amount: float, plot_type: int) -> Resource:
	"""
	Inject wheat directly into farming biome (new universal planting system)

	FARMING BIOME GAMEPLAY:
	- Player plants: 0.22🌾 + 0.08👥
	- Farming converts to quantum superposition (wheat/labor split)
	- Growth through Bloch sphere evolution
	- Harvest = measure qubit, get wheat or labor based on probability

	Returns: Qubit representing the planting
	"""
	# Create a hybrid qubit (🌾, 👥) representing the planting
	# Start at balanced superposition (50/50 wheat/labor)
	var planting_qubit = BiomeUtilities.create_qubit("🌾", "👥", PI / 2.0)  # π/2 = balanced

	# Radius represents total resource amount
	planting_qubit.radius = (wheat_amount * 100.0) + (labor_amount * 50.0)

	print("🌾 Farming injection: %.2f🌾 + %.2f👥 → quantum superposition (%.1f resources)" %
		[wheat_amount, labor_amount, planting_qubit.radius])

	return planting_qubit


func harvest_quantum_planting(planting_qubit: Resource) -> Dictionary:
	"""
	Harvest quantum planting from farming biome
	Measure the qubit to collapse superposition

	Returns: {
		"success": bool,
		"wheat": float,
		"labor": float,
		"energy": float
	}
	"""
	if not planting_qubit or not planting_qubit is DualEmojiQubit:
		return {"success": false, "wheat": 0.0, "labor": 0.0, "energy": 0.0}

	var qubit = planting_qubit as DualEmojiQubit

	# Measurement: collapse based on theta position
	# sin²(θ/2) = probability of 👥 (labor)
	# cos²(θ/2) = probability of 🌾 (wheat)
	var theta = qubit.theta
	var labor_prob = sin(theta / 2.0) * sin(theta / 2.0)
	var wheat_prob = cos(theta / 2.0) * cos(theta / 2.0)

	# Radius distributed based on probability
	var labor_yield = qubit.radius * labor_prob / 100.0  # Convert radius back to resource
	var wheat_yield = qubit.radius * wheat_prob / 100.0

	print("🌾 Farming harvest: %.2f🌾 + %.2f👥 (θ=%.2f)" % [wheat_yield, labor_yield, theta])

	return {
		"success": true,
		"wheat": wheat_yield,
		"labor": labor_yield,
		"energy": qubit.radius  # Legacy key for backward compat
	}


func mark_bell_gate(positions: Array) -> void:
	"""
	Override: Mark Bell gate and apply BioticFlux entanglement energy boost

	In BioticFlux biome, entangled qubits receive a 10% energy boost per
	involved emoji, representing the cooperative energy generation from
	entanglement relationships.

	Example:
	- 2-qubit gate: each qubit gets +10% boost (1.10x multiplier)
	- 3-qubit gate: each qubit gets +10% boost (1.10x multiplier)

	Args:
		positions: Array of Vector2i positions to entangle
	"""
	# Call parent to record the Bell gate
	super.mark_bell_gate(positions)

	# Apply energy boost: 10% per emoji in the entanglement
	var boost_multiplier = 1.10
	var total_boost = 0.0

	# Model B: Entanglement bonuses are applied through quantum computer mechanisms
	# Direct plot.quantum_state access is no longer supported in Model B

	if total_boost > 0.001:
		print("  ⚡ Total BioticFlux entanglement boost: +%.3f energy (%.1f%%)" % [
			total_boost,
			(boost_multiplier - 1.0) * 100
		])


func _reset_custom() -> void:
	"""Override parent: Reset biome to initial state"""
	# Reset celestial
	if sun_qubit:
		sun_qubit.theta = 0.0
		sun_qubit.radius = 1.0

	# Icon system now managed by IconRegistry (deprecated icon variables removed)

	# Model B: Quantum state management handled by quantum_computer
	if quantum_computer:
		quantum_computer.elapsed_time = 0.0  # Reset time tracking for drivers
	temperature_grid.clear()
	base_temperature = 300.0

	print("🌍 BioticFlux Biome reset to initial state")


func _notification(what: int):
	"""Debug: Print biome info periodically"""
	if what == NOTIFICATION_PROCESS:
		if Engine.get_process_frames() % 300 == 0:  # Every 5 seconds at 60fps
			# Model C: Get populations from quantum computer
			var p_sun = 0.0
			var p_wheat = 0.0
			var p_organic = 0.0
			if quantum_computer:
				p_sun = quantum_computer.get_population("☀")
				p_wheat = quantum_computer.get_population("🌾")
				p_organic = quantum_computer.get_population("🍂")

			print("🌍 BioticFlux | Temp: %.0fK | ☀%.2f 🌾%.2f 🍂%.2f | Purity: %.3f" % [
				base_temperature,
				p_sun,
				p_wheat,
				p_organic,
				quantum_computer.get_purity() if quantum_computer else 0.0
			])
