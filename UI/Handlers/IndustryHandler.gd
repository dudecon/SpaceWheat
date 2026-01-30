class_name IndustryHandler
extends RefCounted

## IndustryHandler - Static handler for industry operations
##
## Handles building, kitchen, mill, and harvest operations.
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}

const QuantumMill = preload("res://Core/GameMechanics/QuantumMill.gd")


## ============================================================================
## BUILDING OPERATIONS
## ============================================================================

static func batch_build(farm, build_type: String, positions: Array[Vector2i]) -> Dictionary:
	"""Build structures (mill, market) on multiple plots.

	Args:
		farm: Farm instance
		build_type: Type of building (mill, market)
		positions: Array of grid positions to build on

	Returns:
		Dictionary with:
		- success: bool
		- success_count: int
		- total_count: int
	"""
	if not farm:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	# Check if farm has batch method
	if farm.has_method("batch_build"):
		var result = farm.batch_build(positions, build_type)
		return {
			"success": result.get("success", false),
			"success_count": result.get("count", 0),
			"total_count": positions.size()
		}
	else:
		# Fallback: execute individually
		var success_count = 0
		for pos in positions:
			if farm.build(pos, build_type):
				success_count += 1
		return {
			"success": success_count > 0,
			"success_count": success_count,
			"total_count": positions.size()
		}


static func place_kitchen(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Place kitchen using triplet entanglement (requires exactly 3 plots).

	Args:
		farm: Farm instance
		positions: Array of exactly 3 grid positions

	Returns:
		Dictionary with:
		- success: bool
		- positions: Array[Vector2i] (the triplet)
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.size() != 3:
		return {
			"success": false,
			"error": "wrong_count",
			"message": "Kitchen requires exactly 3 plots (got %d)" % positions.size()
		}

	# Create triplet entanglement
	var pos_a = positions[0]
	var pos_b = positions[1]
	var pos_c = positions[2]

	var success = farm.grid.create_triplet_entanglement(pos_a, pos_b, pos_c)

	return {
		"success": success,
		"positions": positions if success else []
	}


## ============================================================================
## HARVEST OPERATIONS
## ============================================================================

static func harvest_flour(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Harvest flour from mill when P(flour) is high.

	Mill creates flour <-> wheat Hamiltonian coupling.
	Player harvests when P(flour) is high.

	Args:
		farm: Farm instance
		positions: Array of grid positions with mills

	Returns:
		Dictionary with:
		- success: bool
		- total_flour: int
		- harvested_count: int
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var total_flour = 0
	var harvested_count = 0

	for pos in positions:
		# Check if there's a mill at this position
		var mill = farm.grid.quantum_mills.get(pos)
		if not mill or not mill.is_active:
			continue

		# Get flour probability from biome (viz_cache-backed)
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			continue

		var flour_prob = biome.get_emoji_probability("💨")

		# Harvest based on probability (threshold: 30%)
		if flour_prob > 0.3:
			var yield_amount = int(flour_prob * 100)
			total_flour += yield_amount
			harvested_count += 1

			# Add to economy
			if farm.economy:
				farm.economy.add_resource("💨", yield_amount, "mill_harvest")

	return {
		"success": harvested_count > 0,
		"total_flour": total_flour,
		"harvested_count": harvested_count,
		"threshold_not_met": harvested_count == 0 and positions.size() > 0
	}


static func market_sell(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Sell resources via market's quantum X <-> money pairing.

	Market pairs a target emoji with money in superposition.
	Measurement collapses to determine credits.

	Args:
		farm: Farm instance
		positions: Array of grid positions with markets

	Returns:
		Dictionary with:
		- success: bool
		- total_credits: int
		- sold_count: int
		- outcomes: Array[String]
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var total_credits = 0
	var sold_count = 0
	var outcomes: Array = []

	for pos in positions:
		# Check if there's a market at this position
		var market = farm.grid.quantum_markets.get(pos)
		if not market or not market.is_active:
			continue

		# Perform quantum sale
		var result = market.measure_for_sale()
		if result.success:
			total_credits += result.credits
			sold_count += 1

			if result.got_money:
				outcomes.append("💰%d" % result.credits)
			else:
				outcomes.append("📦%d" % result.credits)

			# Add credits to economy
			if farm.economy:
				farm.economy.add_resource("💰", result.credits, "market_sale")

	return {
		"success": sold_count > 0,
		"total_credits": total_credits,
		"sold_count": sold_count,
		"outcomes": outcomes
	}


static func bake_bread(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Bake bread using kitchen triplet entanglement.

	Requires 3 plots with water, fire, flour.
	Uses GHZ triplet state - measurement collapses to bread or ingredients.

	Args:
		farm: Farm instance
		positions: Array of exactly 3 grid positions

	Returns:
		Dictionary with:
		- success: bool
		- bread_yield: int (if success)
		- bread_probability: float
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.size() != 3:
		return {
			"success": false,
			"error": "wrong_count",
			"message": "Baking requires 3 kitchen plots (water/fire/flour)"
		}

	# Validate required ingredients
	var has_water = false
	var has_fire = false
	var has_flour = false

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			return {
				"success": false,
				"error": "plot_not_planted",
				"message": "Plot %s not planted" % pos
			}

		match plot.north_emoji:
			"💧": has_water = true
			"🔥": has_fire = true
			"💨": has_flour = true
			_: pass  # Ignore other emojis

	if not (has_water and has_fire and has_flour):
		var water_str = "💧" if has_water else "?"
		var fire_str = "🔥" if has_fire else "?"
		var flour_str = "💨" if has_flour else "?"
		return {
			"success": false,
			"error": "missing_ingredients",
			"message": "Need water+fire+flour (got %s%s%s)" % [water_str, fire_str, flour_str]
		}

	# Get biome and check bread probability
	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome:
		return {
			"success": false,
			"error": "no_quantum_system",
			"message": "No quantum system in biome"
		}

	# Get P(bread) or use coherence as proxy
	var bread_prob = 0.5
	if biome.viz_cache and biome.viz_cache.get_qubit("🍞") >= 0:
		bread_prob = biome.get_emoji_probability("🍞")
	else:
		bread_prob = biome.get_purity()

	# Attempt baking (Born rule)
	if randf() < bread_prob:
		var bread_yield = int(bread_prob * 100)

		if farm.economy:
			farm.economy.add_resource("🍞", bread_yield, "kitchen_bake")

		return {
			"success": true,
			"baked": true,
			"bread_yield": bread_yield,
			"bread_probability": bread_prob
		}
	else:
		return {
			"success": false,
			"baked": false,
			"bread_yield": 0,
			"bread_probability": bread_prob,
			"message": "Collapsed to ingredients (try again)"
		}


## ============================================================================
## MILL TWO-STAGE OPERATIONS
## ============================================================================

static func mill_select_power(farm, power_key: String, positions: Array[Vector2i], mill_state: Dictionary) -> Dictionary:
	"""Handle power source selection (mill stage 1).

	Saves selected power and prepares for stage 2 (conversion selection).

	Args:
		farm: Farm instance
		power_key: "Q", "E", or "R" for power source
		positions: Array with at least one position
		mill_state: Current mill state (will be modified)

	Returns:
		Dictionary with:
		- success: bool
		- power_key: String (selected power)
		- stage: int (now 1)
		- conversion_availability: Dictionary
	"""
	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "Select a plot first"
		}

	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not ready"
		}

	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "No biome at selected position"
		}

	# Verify power is available
	var availability = QuantumMill.check_power_availability(biome)
	if not availability.get(power_key, false):
		var power_info = QuantumMill.POWER_SOURCES.get(power_key, {})
		var emoji = power_info.get("emoji", "?")
		return {
			"success": false,
			"error": "power_not_available",
			"message": "%s not available in biome" % emoji
		}

	# Get conversion availability for stage 2
	var conv_availability = QuantumMill.check_conversion_availability(biome)

	# Update mill state
	mill_state["selected_power"] = power_key
	mill_state["stage"] = 1

	var power_info = QuantumMill.POWER_SOURCES.get(power_key, {})

	return {
		"success": true,
		"power_key": power_key,
		"power_emoji": power_info.get("emoji", "?"),
		"power_label": power_info.get("label", "?"),
		"stage": 1,
		"conversion_availability": conv_availability
	}


static func mill_convert(farm, conversion_key: String, positions: Array[Vector2i], mill_state: Dictionary) -> Dictionary:
	"""Handle conversion selection (mill stage 2) and place the mill.

	Completes two-stage selection and creates the mill with coupling.

	Args:
		farm: Farm instance
		conversion_key: "Q", "E", or "R" for conversion type
		positions: Array with at least one position
		mill_state: Current mill state (must have stage=1)

	Returns:
		Dictionary with:
		- success: bool
		- mill_status: String (status message)
	"""
	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "Select a plot first"
		}

	if mill_state.get("stage", 0) != 1:
		return {
			"success": false,
			"error": "wrong_stage",
			"message": "Select power source first"
		}

	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not ready"
		}

	var pos = positions[0]
	var biome = farm.grid.get_biome_for_plot(pos)
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "No biome at selected position"
		}

	# Verify conversion is available
	var conv_availability = QuantumMill.check_conversion_availability(biome)
	if not conv_availability.get(conversion_key, false):
		var conv_info = QuantumMill.CONVERSIONS.get(conversion_key, {})
		var source = conv_info.get("source", "?")
		var product = conv_info.get("product", "?")
		return {
			"success": false,
			"error": "conversion_not_available",
			"message": "%s->%s not available (need both emojis in biome)" % [source, product]
		}

	# Create and configure mill
	var mill = QuantumMill.new()
	mill.grid_position = pos
	farm.grid.add_child(mill)

	var selected_power = mill_state.get("selected_power", "")
	var result = mill.configure(biome, selected_power, conversion_key)

	if result.success:
		farm.grid.quantum_mills[pos] = mill
		# Clear mill state
		mill_state.clear()
		return {
			"success": true,
			"mill_status": mill.get_status(),
			"position": pos
		}
	else:
		mill.queue_free()
		# Clear mill state
		mill_state.clear()
		return {
			"success": false,
			"error": result.get("error", "unknown"),
			"message": "Mill failed: %s" % result.get("error", "unknown")
		}


static func reset_mill_state(mill_state: Dictionary) -> void:
	"""Reset mill selection state."""
	mill_state.clear()
