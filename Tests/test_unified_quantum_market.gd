extends SceneTree

func _init():
	print("\n=== TEST: Market Unified Quantum (3 qubits) ===")

	var Market = load("res://Core/Environment/MarketBiome.gd")
	var biome = Market.new()
	biome._ready()

	print("✓ Market loaded")
	print("  quantum_computer: ", biome.quantum_computer != null)
	print("  bath (deprecated): ", biome.bath)

	if not biome.quantum_computer:
		print("❌ FAILED: No quantum_computer!")
		quit(1)

	var num_qubits = biome.quantum_computer.register_map.num_qubits
	var dim = biome.quantum_computer.register_map.dim()
	print("  Qubits: ", num_qubits)
	print("  Dimension: ", dim)

	# Check initial state
	var s0 = biome.get_marginal_sentiment()
	var l0 = biome.get_marginal_liquidity()
	var st0 = biome.get_marginal_stability()

	print("\n📊 Initial market state:")
	print("  Sentiment P(🐂) = %.3f" % s0)
	print("  Liquidity P(💰) = %.3f" % l0)
	print("  Stability P(🏛️) = %.3f" % st0)

	# Evolve
	print("\n⏱️ Evolving for 2 seconds...")
	for i in range(20):
		biome.advance_simulation(0.1)

	var s1 = biome.get_marginal_sentiment()
	var l1 = biome.get_marginal_liquidity()
	var st1 = biome.get_marginal_stability()

	print("📊 After evolution:")
	print("  Sentiment P(🐂) = %.3f (Δ=%.3f)" % [s1, s1 - s0])
	print("  Liquidity P(💰) = %.3f (Δ=%.3f)" % [l1, l1 - l0])
	print("  Stability P(🏛️) = %.3f (Δ=%.3f)" % [st1, st1 - st0])

	# Test pricing
	var price = biome.get_commodity_price("🌾")
	print("\n💰 Emergent pricing:")
	print("  Wheat price: %.2f" % price)

	var status = biome.get_market_status()
	print("  Crash probability: %.1f%%" % (status.crash_probability * 100))
	print("  Sentiment: ", status.sentiment_label)

	print("\n✅ Market TEST PASSED")
	quit()
