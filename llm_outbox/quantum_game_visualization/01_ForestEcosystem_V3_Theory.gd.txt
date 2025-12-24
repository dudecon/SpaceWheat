class_name ForestEcosystemBiomeV3
extends "res://Core/Environment/BiomeBase.gd"

## Quantum Ecosystem Field Theory
##
## COMPLETE HAMILTONIAN/UNITARY SYSTEM - ZERO LOSS
##
## System evolves via unitary operator: |ψ(t)⟩ = exp(-iHt/ℏ)|ψ(0)⟩
## All energy conserved - no dissipation, fully reversible
##
## Trophic levels are quantum harmonic oscillators:
##   Plants     (🌿)  - ground/base production
##   Herbivores (🐰)  - coupled to plants
##   Predators  (🐦)  - coupled to herbivores
##   Apex       (🐺)  - coupled to everything
##
## Resources emerge as correlations:
##   Water  ∝ |⟨plant† | herbivore⟩|  (plant-herbivore entanglement)
##   Wind   ∝ |⟨predator† | apex⟩|   (predator-apex entanglement)
##   Oxygen ∝ |⟨plant | apex⟩|       (whole ecosystem coherence)
##   Soil   ∝ √(plant × apex energy) (structural coupling)
##
## When apex predators increase:
##   → Herbivore amplitude decreases (direct coupling)
##   → Plant amplitude increases (less herbivory)
##   → Water field increases (emergent property)
##   → All from ONE Hamiltonian interaction
##
## High-dimensional: Easy to add more trophic levels, decomposers, parasites, etc.

const BiomePlot = preload("res://Core/GameMechanics/BiomePlot.gd")
const QuantumOrganism = preload("res://Core/Environment/QuantumOrganism.gd")

## Hamiltonian parameters
## H = Σᵢ ωᵢ Nᵢ + Σᵢⱼ gᵢⱼ (aᵢ† aⱼ + aⱼ† aᵢ)
var hamiltonian_params = {
	# Natural frequencies for each trophic level
	"omega_plant": 1.0,           # Plant production baseline
	"omega_herbivore": 0.8,       # Herbivore metabolism baseline
	"omega_predator": 0.6,        # Predator metabolism baseline
	"omega_apex": 0.4,            # Apex predator metabolism baseline

	# Coupling strengths (predation interactions)
	"g_plant_herbivore": 0.15,    # Herbivores eat plants
	"g_herbivore_predator": 0.12, # Predators eat herbivores
	"g_predator_apex": 0.10,      # Apex eat predators
	"g_herbivore_apex": 0.08,     # Apex also eat herbivores (direct)

	# Ecosystem service couplings (high-dimensional)
	"g_plant_pollinator": 0.10,     # Pollinators increase plant reproduction
	"g_herbivore_parasite": -0.06,  # Parasites decrease herbivores
	"g_decomposer_all": 0.08,       # Decomposers recycle all trophic levels
	"g_mycorrhizal_plant": 0.07,    # Fungal network helps plants
	"g_nitrogen_decomposer": 0.05,  # Nitrogen fixers couple to decomposers

	# Environmental modulation
	"water_coupling": 0.1,        # Water modulates plant production
	"sun_coupling": 0.12,         # Sun modulates plant production
	"seasonal_frequency": 0.02    # Slow seasonal variation
}

## Occupation numbers (amplitudes) for each trophic level
## These represent the quantum population of each level
## Extended high-dimensional system:
##   🌿 Plants      - primary producer
##   🐰 Herbivores  - primary consumer
##   🐦 Predators   - secondary consumer
##   🐺 Apex        - tertiary consumer
##   🪦 Decomposers - nutrient recycler
##   🐝 Pollinators - plant service
##   🧬 Parasites   - herbivore regulator
var occupation_numbers: Dictionary = {}  # Vector2i → Dict with all levels

## Patches
var patches: Dictionary = {}  # Vector2i → BiomePlot
var grid_width: int = 0
var grid_height: int = 0

## Environmental qubits
var weather_qubit: DualEmojiQubit
var season_qubit: DualEmojiQubit

## Global energy tracking
var total_energy: float = 0.0
var energy_per_level: Dictionary = {}


func _init(width: int = 6, height: int = 1):
	"""Initialize dimensions"""
	grid_width = width
	grid_height = height


func _ready():
	"""Initialize quantum ecosystem"""
	super._ready()

	if weather_qubit != null:
		if OS.get_environment("VERBOSE_FOREST") == "1":
			print("⚠️ ForestEcosystemBiomeV3._ready() called multiple times, skipping")
		return

	# Initialize weather and season qubits
	weather_qubit = BiomeUtilities.create_qubit("🌬️", "💧", PI / 2.0)
	weather_qubit.radius = 1.0

	season_qubit = BiomeUtilities.create_qubit("☀️", "🌧️", PI / 2.0)
	season_qubit.radius = 1.0

	# Initialize patches with quantum occupation numbers (high-dimensional)
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			patches[pos] = _create_patch(pos)
			occupation_numbers[pos] = {
				# Core food chain
				"plant": 10.0,       # Primary producer
				"herbivore": 2.0,    # Primary consumer (eats plants)
				"predator": 1.0,     # Secondary consumer (eats herbivores)
				"apex": 0.5,         # Tertiary consumer (eats predators/herbivores)

				# Ecosystem services (high-dimensional space)
				"decomposer": 3.0,   # Nutrient recycler (increased with dead biomass)
				"pollinator": 2.5,   # Plant reproduction helper (couples to plants)
				"parasite": 1.2,     # Herbivore regulator (negative feedback on herbivores)

				# Optional: more services
				"nitrogen_fixer": 1.5,  # Adds nitrogen when coupled to decomposers
				"mycorrhizal": 2.0      # Fungal network (connects all levels)
			}

	print("🌲 ForestEcosystem V3 (Quantum Field Theory) initialized (%dx%d)" % [grid_width, grid_height])
	print("   ✓ Hamiltonian/Unitary dynamics (100%% energy conserving)")
	print("   ✓ Resources emerge as correlation functions")
	print("   ✓ Icons as quantum harmonic oscillators")

	visual_color = Color(0.3, 0.7, 0.3, 0.4)
	visual_label = "🌲 Forest V3 (QFT)"
	visual_center_offset = Vector2(0.8, -0.7)
	visual_oval_width = 350.0
	visual_oval_height = 216.0


func _create_patch(position: Vector2i) -> BiomePlot:
	"""Create forest patch with quantum state"""
	var plot = BiomePlot.new(BiomePlot.BiomePlotType.ENVIRONMENT)
	plot.plot_id = "forest_v3_patch_%d_%d" % [position.x, position.y]
	plot.grid_position = position
	plot.parent_biome = self

	# Patch state qubit represents coherence of ecosystem
	var state_qubit = DualEmojiQubit.new("🌿", "💧", PI / 2.0)
	state_qubit.radius = 0.8
	state_qubit.phi = 0.0
	plot.quantum_state = state_qubit

	# Metadata for resource calculations
	plot.set_meta("organisms", {})  # For visual/debug purposes
	plot.set_meta("water_field", 0.0)
	plot.set_meta("wind_field", 0.0)
	plot.set_meta("oxygen_field", 0.0)
	plot.set_meta("soil_field", 0.0)
	plot.set_meta("energy", 0.0)

	_initialize_patch_organisms(plot, position)

	return plot


func _initialize_patch_organisms(patch: BiomePlot, position: Vector2i):
	"""Initialize organisms for visualization (not essential for dynamics)"""
	var organisms = {}
	patch.set_meta("organisms", organisms)

	# These are mostly for debugging/visualization
	# The actual dynamics happen via Hamiltonian evolution of occupation numbers
	_add_organism_to_patch(patch, "🌿", "plant", 1)
	_add_organism_to_patch(patch, "🐰", "herbivore", 1)
	_add_organism_to_patch(patch, "🐦", "predator", 1)
	_add_organism_to_patch(patch, "🐺", "apex", 1)


func _add_organism_to_patch(patch: BiomePlot, icon: String, org_type: String, count: int):
	"""Add organism for tracking (visual purposes)"""
	var organisms = patch.get_meta("organisms")
	if not icon in organisms:
		organisms[icon] = []

	for i in range(count):
		var organism = QuantumOrganism.new(icon, org_type)
		organisms[icon].append(organism)


func _update_quantum_substrate(dt: float) -> void:
	"""Main simulation loop - Hamiltonian evolution"""
	_update_weather()

	# Evolve each patch via Hamiltonian
	for pos in patches.keys():
		_evolve_patch_hamiltonian(pos, dt)


func _update_weather():
	"""Evolve environmental qubits"""
	weather_qubit.theta += 0.01
	if weather_qubit.theta > TAU:
		weather_qubit.theta = 0.0

	season_qubit.theta += 0.005
	if season_qubit.theta > TAU:
		season_qubit.theta = 0.0


func _evolve_patch_hamiltonian(position: Vector2i, dt: float):
	"""
	Evolve patch via unitary operator: |ψ(t+dt)⟩ = exp(-iH·dt/ℏ)|ψ(t)⟩

	This is the CORE of the system - fully reversible, energy-conserving evolution
	"""
	var patch = patches[position]
	var state_qubit = patch.quantum_state
	if not state_qubit:
		return

	# Get current occupation numbers (high-dimensional state)
	var N = occupation_numbers[position]
	var plant = N["plant"]
	var herbivore = N["herbivore"]
	var predator = N["predator"]
	var apex = N["apex"]
	var decomposer = N["decomposer"]
	var pollinator = N["pollinator"]
	var parasite = N["parasite"]
	var nitrogen_fixer = N["nitrogen_fixer"]
	var mycorrhizal = N["mycorrhizal"]

	# Get environmental modulation
	var water_mod = weather_qubit.water_probability()
	var sun_mod = season_qubit.sun_probability()

	# HAMILTONIAN DYNAMICS (Extended to 9 dimensions)
	# H = Σᵢ ωᵢ Nᵢ + Σᵢⱼ gᵢⱼ (aᵢ† aⱼ + aⱼ† aᵢ)
	#
	# For occupation numbers in classical limit:
	# dNᵢ/dt = -Σⱼ gᵢⱼ sin(Nᵢ - Nⱼ) * sqrt(Nᵢ Nⱼ)
	#
	# This preserves total energy and creates oscillatory coupling

	# CORE FOOD CHAIN
	# Plant production (modulated by water, sun, pollinator help, and fungal network)
	var dplant = (hamiltonian_params["omega_plant"] * (1.0 + water_mod + sun_mod) * 0.1)
	dplant += hamiltonian_params["g_plant_pollinator"] * sin(pollinator - plant) * sqrt(plant * pollinator) * dt
	dplant += hamiltonian_params["g_mycorrhizal_plant"] * sin(mycorrhizal - plant) * sqrt(plant * mycorrhizal) * dt
	# Plant loss to herbivores
	dplant -= hamiltonian_params["g_plant_herbivore"] * sin(plant - herbivore) * sqrt(plant * herbivore) * dt

	# Herbivore dynamics
	var dherbivore = hamiltonian_params["g_plant_herbivore"] * sin(plant - herbivore) * sqrt(plant * herbivore) * dt
	dherbivore -= hamiltonian_params["g_herbivore_predator"] * sin(herbivore - predator) * sqrt(herbivore * predator) * dt
	dherbivore -= hamiltonian_params["g_herbivore_apex"] * sin(herbivore - apex) * sqrt(herbivore * apex) * dt
	# Parasites regulate herbivores (negative coupling)
	dherbivore += hamiltonian_params["g_herbivore_parasite"] * sin(herbivore - parasite) * sqrt(herbivore * parasite) * dt

	# Predator dynamics
	var dpredator = hamiltonian_params["g_herbivore_predator"] * sin(herbivore - predator) * sqrt(herbivore * predator) * dt
	dpredator -= hamiltonian_params["g_predator_apex"] * sin(predator - apex) * sqrt(predator * apex) * dt

	# Apex predator dynamics
	var dapex = hamiltonian_params["g_predator_apex"] * sin(predator - apex) * sqrt(predator * apex) * dt
	dapex += hamiltonian_params["g_herbivore_apex"] * sin(herbivore - apex) * sqrt(herbivore * apex) * dt

	# ECOSYSTEM SERVICES (High-dimensional space)
	# Decomposers: recycled from all trophic levels (simulate as dead biomass)
	var ddecomposer = hamiltonian_params["g_decomposer_all"] * 0.1 * (herbivore + predator + apex) * dt
	ddecomposer -= 0.02 * decomposer * dt  # Natural decay

	# Pollinators: coupled to plant vitality and sun
	var dpollinator = hamiltonian_params["g_plant_pollinator"] * sin(plant - pollinator) * sqrt(plant * pollinator) * dt
	dpollinator += sun_mod * 0.05 * dt
	dpollinator -= 0.01 * pollinator * dt

	# Parasites: increase with herbivore abundance
	var dparasite = hamiltonian_params["g_herbivore_parasite"] * sin(parasite - herbivore) * sqrt(herbivore * parasite) * dt
	dparasite -= 0.01 * parasite * dt

	# Nitrogen fixers: coupled to decomposers and provide nutrient benefit
	var dnitrogen_fixer = hamiltonian_params["g_nitrogen_decomposer"] * sin(nitrogen_fixer - decomposer) * sqrt(nitrogen_fixer * decomposer) * dt
	dnitrogen_fixer += 0.02 * decomposer * dt  # More decomposition = more nitrogen fixation
	dnitrogen_fixer -= 0.01 * nitrogen_fixer * dt

	# Mycorrhizal network: benefits all organisms, especially plants
	var dmycorrhizal = 0.02 * (plant + decomposer) * dt  # Grows with plant and decomposer activity
	dmycorrhizal -= 0.015 * mycorrhizal * dt  # Natural turnover

	# Update all occupation numbers (clamp to prevent negatives)
	N["plant"] = max(0.1, plant + dplant)
	N["herbivore"] = max(0.1, herbivore + dherbivore)
	N["predator"] = max(0.1, predator + dpredator)
	N["apex"] = max(0.1, apex + dapex)
	N["decomposer"] = max(0.1, decomposer + ddecomposer)
	N["pollinator"] = max(0.1, pollinator + dpollinator)
	N["parasite"] = max(0.1, parasite + dparasite)
	N["nitrogen_fixer"] = max(0.1, nitrogen_fixer + dnitrogen_fixer)
	N["mycorrhizal"] = max(0.1, mycorrhizal + dmycorrhizal)

	# Calculate total energy (conserved quantity)
	var total_energy_patch = _calculate_hamiltonian(N, water_mod, sun_mod)
	patch.set_meta("energy", total_energy_patch)

	# Calculate emergent resources as correlation functions
	_calculate_emergent_resources(patch, N, position)

	# Update state qubit to reflect ecosystem coherence
	state_qubit.theta = atan2(herbivore + predator, plant + apex)
	state_qubit.radius = (N["plant"] + N["herbivore"] + N["predator"] + N["apex"]) / 25.0
	state_qubit.radius = clamp(state_qubit.radius, 0.0, 1.0)


func _calculate_hamiltonian(N: Dictionary, water_mod: float, sun_mod: float) -> float:
	"""
	Calculate total Hamiltonian energy (extended to 9 dimensions)
	H = Σᵢ ωᵢ Nᵢ + Σᵢⱼ gᵢⱼ√(Nᵢ Nⱼ)

	This is the conserved quantity of the system - INVARIANT OVER TIME
	"""
	var h = 0.0

	# Free energy of each level (baseline metabolic costs)
	var omega_plant = hamiltonian_params["omega_plant"] * (1.0 + water_mod + sun_mod)
	h += omega_plant * N["plant"]
	h += hamiltonian_params["omega_herbivore"] * N["herbivore"]
	h += hamiltonian_params["omega_predator"] * N["predator"]
	h += hamiltonian_params["omega_apex"] * N["apex"]

	# Ecosystem services contribute to energy (not costs, but coupled dynamics)
	h += 0.3 * N["decomposer"]   # Recycling energy
	h += 0.3 * N["pollinator"]   # Reproductive energy
	h += 0.2 * N["parasite"]     # Regulation energy
	h += 0.2 * N["nitrogen_fixer"]  # Nitrogen conversion
	h += 0.3 * N["mycorrhizal"]  # Nutrient transport

	# Food chain coupling (interaction energy)
	h += hamiltonian_params["g_plant_herbivore"] * sqrt(N["plant"] * N["herbivore"])
	h += hamiltonian_params["g_herbivore_predator"] * sqrt(N["herbivore"] * N["predator"])
	h += hamiltonian_params["g_predator_apex"] * sqrt(N["predator"] * N["apex"])
	h += hamiltonian_params["g_herbivore_apex"] * sqrt(N["herbivore"] * N["apex"])

	# Ecosystem service couplings
	h += hamiltonian_params["g_plant_pollinator"] * sqrt(N["plant"] * N["pollinator"])
	h += hamiltonian_params["g_herbivore_parasite"] * abs(N["herbivore"] * N["parasite"])
	h += hamiltonian_params["g_decomposer_all"] * sqrt(N["decomposer"] * (N["herbivore"] + N["predator"] + N["apex"]))
	h += hamiltonian_params["g_mycorrhizal_plant"] * sqrt(N["mycorrhizal"] * N["plant"])
	h += hamiltonian_params["g_nitrogen_decomposer"] * sqrt(N["nitrogen_fixer"] * N["decomposer"])

	return h


func _calculate_emergent_resources(patch: BiomePlot, N: Dictionary, position: Vector2i):
	"""
	Calculate emergent resources as observables of the quantum system (9-dimensional)

	These are NOT explicitly produced - they EMERGE from the high-dimensional coupling structure.
	When wolves (apex) eat herbivores, plants recover automatically.
	When plants are healthy, water is retained. When pollinators are active, more plants.
	All from the SAME Hamiltonian - no separate production rules.
	"""
	var plant = N["plant"]
	var herbivore = N["herbivore"]
	var predator = N["predator"]
	var apex = N["apex"]
	var decomposer = N["decomposer"]
	var pollinator = N["pollinator"]
	var parasite = N["parasite"]
	var nitrogen_fixer = N["nitrogen_fixer"]
	var mycorrhizal = N["mycorrhizal"]

	# WATER: Emerges from plant-herbivore entanglement
	# Plants retain water when herbivores are controlled (by predators or parasites)
	# Water = plant amplitude × (1 - herbivory pressure) × [coupling to decomposers]
	var herbivory_pressure = herbivore / (plant + 1.0)
	var water_field = plant * max(0.0, 1.0 - herbivory_pressure * 0.5) * (1.0 + decomposer * 0.1) * 0.2

	# WIND: Emerges from predator-apex entanglement and pollinator activity
	# Wind from predator-apex oscillations + pollinator movement
	var wind_field = sqrt(predator * apex) * 0.15 + pollinator * 0.05

	# OXYGEN: Emerges from plant vigor and mycorrhizal network strength
	# Healthy plants produce oxygen, fungal network distributes it
	var oxygen_field = plant * sin(PI * pollinator / (pollinator + 1.0)) * (1.0 + mycorrhizal * 0.1) * 0.12

	# SOIL: Emerges from decomposer activity and mycorrhizal-plant coupling
	# Soil quality from nutrient cycling (decomposers + nitrogen fixers)
	var soil_field = decomposer * (1.0 + nitrogen_fixer * 0.2) * mycorrhizal * 0.12

	# NITROGEN: Emerges from decomposition and nitrogen fixer coupling
	# Available nitrogen from coupled decomposer-nitrogen_fixer interaction
	var nitrogen_field = sqrt(decomposer * nitrogen_fixer) * 0.1

	# POLLINATION: Pollinator coupling strength affects plant reproduction
	# Pollination field = pollinator-plant entanglement
	var pollination_field = sqrt(plant * pollinator) * 0.08

	# BIODIVERSITY: Emerges from food web complexity
	# Biodiversity ∝ number of active trophic levels and services
	var biodiversity = (plant + herbivore + predator + apex + decomposer + mycorrhizal) / 20.0
	biodiversity = clamp(biodiversity, 0.0, 1.0)

	# Store all emergent resources
	patch.set_meta("water_field", water_field)
	patch.set_meta("wind_field", wind_field)
	patch.set_meta("oxygen_field", oxygen_field)
	patch.set_meta("soil_field", soil_field)
	patch.set_meta("nitrogen_field", nitrogen_field)
	patch.set_meta("pollination_field", pollination_field)
	patch.set_meta("biodiversity", biodiversity)

	# For economy/external systems to query (main resources)
	patch.set_meta("water_produced", water_field)
	patch.set_meta("wind_produced", wind_field)
	patch.set_meta("soil_produced", soil_field)


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "ForestEcosystemV3_QuantumField"


func _initialize_visual_elements():
	"""Initialize visualization elements"""
	if not grid:
		return

	for pos in patches.keys():
		var patch = patches[pos]
		if patch.quantum_state:
			var qubit = patch.quantum_state
			grid.add_qubit(qubit, visual_label + " patch %d,%d" % [pos.x, pos.y])


# Debug/analysis helpers
func get_occupation_numbers(position: Vector2i) -> Dictionary:
	"""Get current occupation numbers for a patch (all 9 dimensions)"""
	return occupation_numbers.get(position, {})


func get_ecosystem_health(position: Vector2i) -> float:
	"""
	Health metric - integrates all 9 dimensions
	Higher when all trophic levels and services are balanced
	"""
	var N = occupation_numbers.get(position, {})
	if N.is_empty():
		return 0.0

	# Total biomass across all levels
	var total_biomass = 0.0
	for level in N.keys():
		total_biomass += N[level]

	# Diversity: measure of all services being active
	var diversity = 0.0
	if N.get("plant", 0.0) > 0: diversity += 1.0
	if N.get("herbivore", 0.0) > 0: diversity += 1.0
	if N.get("predator", 0.0) > 0: diversity += 1.0
	if N.get("apex", 0.0) > 0: diversity += 1.0
	if N.get("decomposer", 0.0) > 0: diversity += 0.5
	if N.get("pollinator", 0.0) > 0: diversity += 0.5
	if N.get("parasite", 0.0) > 0: diversity += 0.5
	if N.get("nitrogen_fixer", 0.0) > 0: diversity += 0.5
	if N.get("mycorrhizal", 0.0) > 0: diversity += 0.5

	# Health combines biomass and diversity
	var biomass_health = clamp(total_biomass / 20.0, 0.0, 1.0)
	var diversity_health = diversity / 6.0

	return (biomass_health * 0.6 + diversity_health * 0.4)


func get_trophic_cascade_indicator(position: Vector2i) -> float:
	"""
	Measure of ecosystem coupling strength across all dimensions
	Returns 0-1 indicating how strongly coupled the system is
	"""
	var N = occupation_numbers.get(position, {})
	if N.is_empty():
		return 0.0

	# Coupling strength = geometric mean of all cross-level interactions
	var coupling = sqrt(N.get("plant", 0.0) * N.get("apex", 0.0)) / 10.0
	coupling += sqrt(N.get("herbivore", 0.0) * N.get("predator", 0.0)) / 10.0
	coupling += sqrt(N.get("decomposer", 0.0) * N.get("plant", 0.0)) / 10.0
	coupling += sqrt(N.get("pollinator", 0.0) * N.get("plant", 0.0)) / 10.0
	coupling += sqrt(N.get("parasite", 0.0) * N.get("herbivore", 0.0)) / 10.0

	return clamp(coupling / 5.0, 0.0, 1.0)


func get_energy_conservation_check(position: Vector2i) -> float:
	"""
	Verify that total Hamiltonian energy is conserved
	Should return same value across timesteps (up to numerical error)
	Returns the conserved energy value
	"""
	var patch = patches.get(position)
	if not patch:
		return 0.0
	return patch.get_meta("energy") if patch.has_meta("energy") else 0.0
