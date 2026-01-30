class_name BuildingManager
extends RefCounted

## BuildingManager - Mill, market, kitchen placement and management
##
## Extracted from FarmGrid.gd as part of decomposition.
## Handles building placement and quantum dynamics injection.

const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")
const QuantumMill = preload("res://Core/GameMechanics/QuantumMill.gd")
const QuantumMarket = preload("res://Core/GameMechanics/QuantumMarket.gd")

# Building storage
var quantum_mills: Dictionary = {}  # Vector2i -> QuantumMill
var quantum_markets: Dictionary = {}  # Vector2i -> QuantumMarket

# Component dependencies (injected via set_dependencies)
var _plot_manager = null  # GridPlotManager
var _biome_routing = null  # BiomeRoutingManager
var _entanglement = null  # EntanglementManager
var _parent_node = null  # Node to add buildings as children
var _verbose = null


func set_dependencies(plot_manager, biome_routing, entanglement) -> void:
	"""Inject component dependencies."""
	_plot_manager = plot_manager
	_biome_routing = biome_routing
	_entanglement = entanglement


func set_parent_node(parent: Node) -> void:
	"""Set parent node for adding building children."""
	_parent_node = parent


func set_verbose(verbose_ref) -> void:
	"""Set verbose logger reference."""
	_verbose = verbose_ref


func place_mill(position: Vector2i) -> bool:
	"""Place quantum mill building - injects flour dynamics into parent biome

	Creates a QuantumMill that activates flour (💨) ↔ wheat (🌾) Hamiltonian
	coupling in the parent biome's quantum computer. Flour populations oscillate
	with wheat populations - harvest when P(💨) is high.
	"""
	var plot = _plot_manager.get_plot(position)
	if plot == null or plot.is_planted:
		return false

	# Mark as occupied (buildings are instantly "mature")
	plot.plot_type = FarmPlot.PlotType.MILL
	plot.conspiracy_node_id = "sauce"  # Entangle with transformation node
	plot.is_planted = true

	# Create QuantumMill
	var mill = QuantumMill.new()
	mill.grid_position = position
	if _parent_node:
		_parent_node.add_child(mill)

	# Activate mill with parent biome (injects flour dynamics)
	var biome = _biome_routing.get_biome_for_plot(position)
	if biome:
		var success = mill.activate(biome)
		if success:
			if _verbose:
				_verbose.info("farm", "🏭", "Mill activated: 💨↔🌾 dynamics enabled at %s" % plot.plot_id)
		else:
			if _verbose:
				_verbose.warn("farm", "⚠️", "Mill placed but flour dynamics not activated at %s" % plot.plot_id)
	else:
		if _verbose:
			_verbose.warn("farm", "⚠️", "Mill placed but no biome found at %s" % plot.plot_id)

	# Track mill
	quantum_mills[position] = mill

	if _verbose:
		_verbose.info("farm", "🏭", "Placed quantum mill at %s" % plot.plot_id)
	return true


func place_market(position: Vector2i, target_emoji: String = "🌾") -> bool:
	"""Place market building - creates X ↔ 💰 quantum pairing for sales

	Creates a QuantumMarket that pairs a target emoji with 💰 (money) in
	superposition. Player measures to "sell" - the collapse determines credits.
	Higher P(💰) = more likely to get money.

	Args:
	    position: Grid position for market
	    target_emoji: Emoji to pair with 💰 (default: 🌾 wheat)
	"""
	var plot = _plot_manager.get_plot(position)
	if plot == null or plot.is_planted:
		return false

	# Mark as occupied (buildings are instantly "mature")
	plot.plot_type = FarmPlot.PlotType.MARKET
	plot.conspiracy_node_id = "market"  # Entangle with market node
	plot.is_planted = true

	# Create QuantumMarket
	var market = QuantumMarket.new()
	market.grid_position = position
	if _parent_node:
		_parent_node.add_child(market)

	# Activate market with parent biome (injects 💰 dynamics)
	var biome = _biome_routing.get_biome_for_plot(position)
	if biome:
		var success = market.activate(biome, target_emoji)
		if success:
			if _verbose:
				_verbose.info("farm", "🏪", "Market activated: %s ↔ 💰 pairing enabled at %s" % [target_emoji, plot.plot_id])
		else:
			if _verbose:
				_verbose.warn("farm", "⚠️", "Market placed but trading not activated at %s" % plot.plot_id)
	else:
		if _verbose:
			_verbose.warn("farm", "⚠️", "Market placed but no biome found at %s" % plot.plot_id)

	# Track market
	quantum_markets[position] = market

	if _verbose:
		_verbose.info("farm", "💰", "Placed market at %s → %s ↔ 💰 pairing (value fluctuation)" % [plot.plot_id, target_emoji])
	return true


func place_kitchen(position: Vector2i) -> bool:
	"""Place kitchen building - prepares for 3-qubit Bell state baking

	Kitchen will:
	1. Monitor economy for fire (🔥), water (💧), and flour (💨)
	2. Create 3-qubit entangled Bell state: |ψ⟩ = α|🔥💧💨⟩ + β|🍞⟩
	3. Evolve under Hamiltonian (oven heat drives toward bread)
	4. Measure to collapse to bread outcome

	The Kitchen is connected to QuantumKitchen_Biome which manages the quantum state.
	Also injects 🍞 (bread) axis into the biome for harvesting.
	"""
	var plot = _plot_manager.get_plot(position)
	if plot == null or plot.is_planted:
		return false

	# Mark as occupied (buildings are instantly "mature")
	plot.plot_type = FarmPlot.PlotType.KITCHEN
	plot.is_planted = true

	# Inject bread axis into biome's quantum system
	var biome = _biome_routing.get_biome_for_plot(position)
	if biome and biome.quantum_computer:
		if not _has_emoji(biome, "🍞"):
			if biome.has_method("expand_quantum_system"):
				# Expand quantum system to include bread (coupled to flour)
				var result = biome.expand_quantum_system("🍞", "💨")
				if result.success or result.get("already_exists", false):
					if _verbose:
						_verbose.info("farm", "🍳", "Kitchen injected 🍞 axis into quantum system")
				else:
					if _verbose:
						_verbose.warn("farm", "⚠️", "Kitchen could not inject bread axis: %s" % result.get("message", "unknown"))
						_verbose.warn("farm", "⚠️", "Try pressing TAB to enter BUILD mode first")
			else:
				if _verbose:
					_verbose.warn("farm", "⚠️", "Kitchen biome doesn't support quantum expansion")
		else:
			if _verbose:
				_verbose.info("farm", "🍳", "Kitchen: 🍞 axis already exists in biome")

	if _verbose:
		_verbose.info("farm", "🍳", "Placed kitchen at %s - ready for Bell state baking!" % position)
	return true


func place_kitchen_triplet(positions: Array[Vector2i]) -> bool:
	"""Place kitchen with triplet entanglement (advanced multi-plot kitchen)

	Validates required ingredients (💧, 🔥, 💨) and creates GHZ triplet state.
	Injects 🍞 (bread) as entangled outcome.

	Args:
	    positions: Array of exactly 3 plot positions with 💧, 🔥, 💨

	Returns:
	    true if triplet kitchen created successfully
	"""
	if positions.size() != 3:
		if _verbose:
			_verbose.warn("farm", "❌", "Kitchen triplet requires exactly 3 positions")
		return false

	# Validate required ingredients (any order)
	var required = {"💧": false, "🔥": false, "💨": false}
	for pos in positions:
		var plot = _plot_manager.get_plot(pos)
		if not plot or not plot.is_planted:
			if _verbose:
				_verbose.warn("farm", "❌", "Plot %s must be planted for kitchen triplet" % pos)
			return false
		if plot.north_emoji in required:
			required[plot.north_emoji] = true

	# Check all ingredients present
	for emoji in required:
		if not required[emoji]:
			if _verbose:
				_verbose.warn("farm", "❌", "Kitchen missing ingredient: %s" % emoji)
			return false

	# All ingredients present - create triplet entanglement
	var success = false
	if _entanglement:
		success = _entanglement.create_triplet_entanglement(positions[0], positions[1], positions[2])

	if success:
		# Inject bread superposition into biome
		var biome = _biome_routing.get_biome_for_plot(positions[0])
		if biome and biome.has_method("expand_quantum_system"):
			if not _has_emoji(biome, "🍞"):
				var result = biome.expand_quantum_system("🍞", "💨")
				if result.success or result.get("already_exists", false):
					if _verbose:
						_verbose.info("farm", "🍳", "Kitchen triplet: 🍞 axis injected")

		# Mark center plot as kitchen
		var center_plot = _plot_manager.get_plot(positions[1])
		if center_plot:
			center_plot.plot_type = FarmPlot.PlotType.KITCHEN

		if _verbose:
			_verbose.info("farm", "🍳", "Kitchen triplet created: %s ↔ %s ↔ %s → 🍞" % positions)

	return success


func get_mill(position: Vector2i) -> QuantumMill:
	"""Get mill at position if exists."""
	return quantum_mills.get(position, null)


func get_market(position: Vector2i) -> QuantumMarket:
	"""Get market at position if exists."""
	return quantum_markets.get(position, null)


func _has_emoji(biome, emoji: String) -> bool:
	"""Check emoji presence via viz_cache metadata (fallback to register_map)."""
	if not biome or emoji == "":
		return false
	if biome.viz_cache:
		return biome.viz_cache.get_qubit(emoji) >= 0
	if biome.quantum_computer and biome.quantum_computer.register_map:
		return biome.quantum_computer.register_map.has(emoji)
	return false
