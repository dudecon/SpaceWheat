#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test quantum-native measurement operator generation
## Verifies continuous weight calculation and operator generation

const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("⚛️ QUANTUM-NATIVE MEASUREMENT OPERATOR TEST")
	print("=".repeat(80))

	# Test 1: Weight calculation with binary bits
	print("\n📊 Test 1: Binary Bits → Operator Weights")
	test_binary_weights()

	# Test 2: Weight calculation with float bits (future-proof!)
	print("\n🌊 Test 2: Float Bits → Operator Weights (continuous)")
	test_float_weights()

	# Test 3: Real factions
	print("\n🏭 Test 3: Real Faction Operators")
	test_real_factions()

	# Test 4: Operator generation
	print("\n⚙️ Test 4: Operator Generation")
	test_operator_generation()

	print("\n" + "=".repeat(80))
	print("✅ ALL MEASUREMENT OPERATOR TESTS COMPLETE")
	print("=".repeat(80) + "\n")

	quit(0)


func test_binary_weights():
	"""Test with traditional binary bits (0 or 1)"""

	# Material(0), Direct(0), Monochrome(0), Scattered(0), Emergent(0)
	# Should favor AMPLITUDE quests
	var material_direct_mono = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var weights = FactionStateMatcher.calculate_operator_weights(material_direct_mono)

	print("  Material × Direct × Monochrome:")
	print("    Amplitude: %.2f (should be high)" % weights.amplitude)
	print("    Coherence: %.2f" % weights.coherence)
	print("    Ratio: %.2f" % weights.ratio)
	print("    Multi: %.2f" % weights.multi)

	if weights.amplitude > 0.8:
		print("    ✅ Correctly biased toward amplitude quests")

	# Mystical(1), Direct(0), Monochrome(0)
	# Should favor COHERENCE quests
	var mystical_direct = [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	weights = FactionStateMatcher.calculate_operator_weights(mystical_direct)

	print("\n  Mystical × Direct:")
	print("    Amplitude: %.2f" % weights.amplitude)
	print("    Coherence: %.2f (should be high)" % weights.coherence)
	print("    Ratio: %.2f" % weights.ratio)

	if weights.coherence > 0.4:
		print("    ✅ Correctly biased toward coherence quests")

	# Subtle(1) - ANY material type
	# Should favor RATIO quests
	var subtle = [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]
	weights = FactionStateMatcher.calculate_operator_weights(subtle)

	print("\n  Subtle (bit[7]=1):")
	print("    Amplitude: %.2f" % weights.amplitude)
	print("    Coherence: %.2f" % weights.coherence)
	print("    Ratio: %.2f (should be high)" % weights.ratio)

	if weights.ratio > 0.8:
		print("    ✅ Correctly biased toward ratio quests")


func test_float_weights():
	"""Test with float bits (future continuous distributions)"""

	# Mix: 50% Material, 50% Mystical, 75% Direct, 25% Subtle
	var mixed_floats = [0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.0, 0.0, 0.0, 0.5]
	var weights = FactionStateMatcher.calculate_operator_weights(mixed_floats)

	print("  Mixed Float Bits (Material=0.5, Subtle=0.25):")
	print("    Amplitude: %.2f" % weights.amplitude)
	print("    Coherence: %.2f" % weights.coherence)
	print("    Ratio: %.2f" % weights.ratio)
	print("    Selectivity: %.2f" % weights.selectivity)

	print("  ✅ Float bits accepted (ready for continuous distributions!)")


func test_real_factions():
	"""Test with real faction data"""

	# Millwright's Union - should favor amplitude (material, direct)
	var millwright = FactionDatabase.MILLWRIGHTS_UNION
	var weights = FactionStateMatcher.calculate_operator_weights(millwright.bits)

	print("  %s %s" % [millwright.emoji, millwright.name])
	print("    Bits: %s" % str(millwright.bits))
	print("    Amplitude: %.2f" % weights.amplitude)
	print("    Coherence: %.2f" % weights.coherence)
	print("    Ratio: %.2f" % weights.ratio)
	print("    Selectivity: %.2f (focused = %d)" % [weights.selectivity, millwright.bits[11]])

	# House of Thorns - should favor ratio (subtle)
	var thorns = FactionDatabase.HOUSE_OF_THORNS
	weights = FactionStateMatcher.calculate_operator_weights(thorns.bits)

	print("\n  %s %s" % [thorns.emoji, thorns.name])
	print("    Bits: %s" % str(thorns.bits))
	print("    Amplitude: %.2f" % weights.amplitude)
	print("    Coherence: %.2f" % weights.coherence)
	print("    Ratio: %.2f (subtle bit[7]=%d)" % [weights.ratio, thorns.bits[7]])

	# Entropy Shepherds - ultimate cosmic entity
	var entropy_shepherds = FactionDatabase.ENTROPY_SHEPHERDS
	weights = FactionStateMatcher.calculate_operator_weights(entropy_shepherds.bits)

	print("\n  %s %s" % [entropy_shepherds.emoji, entropy_shepherds.name])
	print("    Bits: %s (all 1s)" % str(entropy_shepherds.bits))
	print("    Amplitude: %.2f" % weights.amplitude)
	print("    Coherence: %.2f" % weights.coherence)
	print("    Ratio: %.2f" % weights.ratio)
	print("    Multi: %.2f" % weights.multi)


func test_operator_generation():
	"""Test actual operator generation"""

	# Create bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂"])

	# Test amplitude operator with different selectivity
	print("  Amplitude Operators:")

	var op_scattered = FactionStateMatcher._generate_amplitude_operator(bath, 0.0)
	print("    Selectivity=0.0 (scattered):")
	print("      Dominant weight: %.3f (should be low)" % op_scattered.dominant_weight)

	var op_focused = FactionStateMatcher._generate_amplitude_operator(bath, 1.0)
	print("    Selectivity=1.0 (focused):")
	print("      Dominant weight: %.3f (should be high)" % op_focused.dominant_weight)
	print("      Dominant emoji: %s" % bath._density_matrix.emoji_list[op_focused.dominant_index])

	if op_focused.dominant_weight > op_scattered.dominant_weight:
		print("    ✅ Higher selectivity → more peaked distribution")

	# Test ratio operator
	print("\n  Ratio Operator:")
	var op_ratio = FactionStateMatcher._generate_ratio_operator(bath, 0.8)
	var emoji_A = bath._density_matrix.emoji_list[op_ratio.emoji_A_index]
	var emoji_B = bath._density_matrix.emoji_list[op_ratio.emoji_B_index]
	print("    Top 2 emojis for ratio:")
	print("      %s (index %d)" % [emoji_A, op_ratio.emoji_A_index])
	print("      %s (index %d)" % [emoji_B, op_ratio.emoji_B_index])
	print("      Current ratio: %.2f" % op_ratio.current_ratio)
	print("    ✅ Ratio operator generated")

	# Test coherence operator
	print("\n  Coherence Operator:")
	var op_coherence = FactionStateMatcher._generate_coherence_operator(bath, 0.5)
	print("    Total coherence: %.3f" % op_coherence.total_coherence)
	if op_coherence.pairs.size() > 0:
		var pair = op_coherence.dominant_pair
		var emoji_i = bath._density_matrix.emoji_list[pair[0]]
		var emoji_j = bath._density_matrix.emoji_list[pair[1]]
		print("    Dominant pair: %s ↔ %s" % [emoji_i, emoji_j])
		print("    ✅ Coherence operator generated")
