extends Node

## Exploration Script: Analyze IconRegistry coupling landscape
## Goal: Understand the coupling graph to design vocabulary pairing mechanics

var icon_registry = null


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("  ICON COUPLING LANDSCAPE ANALYSIS")
	print("=".repeat(70))

	# Wait for IconRegistry
	await get_tree().process_frame
	icon_registry = get_node_or_null("/root/IconRegistry")

	if not icon_registry:
		print("[ERROR] IconRegistry not found")
		_finish()
		return

	print("IconRegistry has %d icons\n" % icon_registry.icons.size())

	# Analysis phases
	_analyze_merged_connections()
	_analyze_bee_full_connections()
	_simulate_pure_physics_rolls()

	_finish()


## Calculate total connection strength between two emojis
## Merges Hamiltonian + Lindblad (both directions)
func get_connection_strength(emoji_a: String, emoji_b: String) -> float:
	var icon_a = icon_registry.get_icon(emoji_a)
	var icon_b = icon_registry.get_icon(emoji_b)

	var strength = 0.0

	# Hamiltonian coupling (check both directions - should be symmetric but check anyway)
	if icon_a and icon_a.hamiltonian_couplings.has(emoji_b):
		strength += icon_a.hamiltonian_couplings[emoji_b]
	if icon_b and icon_b.hamiltonian_couplings.has(emoji_a):
		strength += icon_b.hamiltonian_couplings[emoji_a]

	# Lindblad flows (both directions)
	if icon_a:
		if icon_a.lindblad_outgoing.has(emoji_b):
			strength += icon_a.lindblad_outgoing[emoji_b]
		if icon_a.lindblad_incoming.has(emoji_b):
			strength += icon_a.lindblad_incoming[emoji_b]

	if icon_b:
		if icon_b.lindblad_outgoing.has(emoji_a):
			strength += icon_b.lindblad_outgoing[emoji_a]
		if icon_b.lindblad_incoming.has(emoji_a):
			strength += icon_b.lindblad_incoming[emoji_a]

	return strength


## Get all connections for an emoji (merged H + L, using absolute values)
func get_all_connections(emoji: String) -> Dictionary:
	var icon = icon_registry.get_icon(emoji)
	if not icon:
		return {}

	var connections = {}  # target -> {h: float, l_in: float, l_out: float, total: float}

	# Hamiltonian couplings (absolute value - anti-couplings still connect)
	for target in icon.hamiltonian_couplings:
		var val = icon.hamiltonian_couplings[target]
		if val is float or val is int:
			if not connections.has(target):
				connections[target] = {"h": 0.0, "l_in": 0.0, "l_out": 0.0, "h_raw": 0.0}
			connections[target]["h"] = abs(val)
			connections[target]["h_raw"] = val  # Keep raw for display

	# Lindblad outgoing (absolute value)
	for target in icon.lindblad_outgoing:
		var val = icon.lindblad_outgoing[target]
		if val is float or val is int:
			if not connections.has(target):
				connections[target] = {"h": 0.0, "l_in": 0.0, "l_out": 0.0, "h_raw": 0.0}
			connections[target]["l_out"] = abs(val)

	# Lindblad incoming (absolute value)
	for source in icon.lindblad_incoming:
		var val = icon.lindblad_incoming[source]
		if val is float or val is int:
			if not connections.has(source):
				connections[source] = {"h": 0.0, "l_in": 0.0, "l_out": 0.0, "h_raw": 0.0}
			connections[source]["l_in"] = abs(val)

	# Calculate totals (sum of absolute values)
	for target in connections:
		var c = connections[target]
		c["total"] = c["h"] + c["l_in"] + c["l_out"]

	return connections


func _analyze_merged_connections() -> void:
	print("-".repeat(60))
	print("  PHASE 1: Merged Connection Analysis (H + L)")
	print("-".repeat(60))

	var total_connections = 0
	var connection_strengths = []
	var h_only_count = 0
	var l_only_count = 0
	var both_count = 0

	for emoji in icon_registry.icons:
		var conns = get_all_connections(emoji)
		for target in conns:
			var c = conns[target]
			total_connections += 1
			connection_strengths.append(c["total"])

			var has_h = c["h"] > 0
			var has_l = c["l_in"] > 0 or c["l_out"] > 0

			if has_h and has_l:
				both_count += 1
			elif has_h:
				h_only_count += 1
			elif has_l:
				l_only_count += 1

	print("  Total connection edges: %d" % total_connections)
	print("  Hamiltonian only: %d" % h_only_count)
	print("  Lindblad only: %d" % l_only_count)
	print("  Both H + L: %d" % both_count)

	if connection_strengths.size() > 0:
		connection_strengths.sort()
		var min_c = connection_strengths[0]
		var max_c = connection_strengths[-1]
		var median_c = connection_strengths[connection_strengths.size() / 2]

		print("\n  Merged connection strengths:")
		print("    min=%.4f, max=%.4f, median=%.4f" % [min_c, max_c, median_c])


func _analyze_emoji_connections(emoji: String) -> void:
	var conns = get_all_connections(emoji)

	if conns.is_empty():
		print("  [No connections for %s]" % emoji)
		return

	# Sort by total connection strength
	var sorted_conns = []
	for target in conns:
		sorted_conns.append({"target": target, "data": conns[target]})
	sorted_conns.sort_custom(func(a, b): return a.data.total > b.data.total)

	print("\n  %s connections (North=%s, South=rolled):\n" % [emoji, emoji])
	print("  South | H(raw) | |H|    | L_in  | L_out | Weight")
	print("  ------|--------|--------|-------|-------|-------")

	var total_weight = 0.0
	for item in sorted_conns:
		total_weight += item.data.total

	for item in sorted_conns:
		var t = item.target
		var d = item.data
		var h_raw = d.get("h_raw", d.h)
		var prob = 100.0 * d.total / total_weight if total_weight > 0 else 0
		var sign = "+" if h_raw >= 0 else ""
		print("  %s    | %s%.2f | %.3f  | %.3f | %.3f | %.3f (%.1f%%)" % [
			t, sign, h_raw, d.h, d.l_in, d.l_out, d.total, prob
		])


func _analyze_bee_full_connections() -> void:
	print("\n" + "-".repeat(60))
	print("  PHASE 2: Connection Maps (|H| + L_in + L_out)")
	print("-".repeat(60))

	# Analyze several interesting emojis
	_analyze_emoji_connections("🐝")
	_analyze_emoji_connections("🔥")
	_analyze_emoji_connections("🍄")


func _simulate_pure_physics_rolls() -> void:
	print("\n" + "-".repeat(60))
	print("  PHASE 3: Pure Physics Pairing Rolls (no bonuses)")
	print("-".repeat(60))

	var conns = get_all_connections("🐝")
	if conns.is_empty():
		return

	# Calculate total weight
	var total_weight = 0.0
	for target in conns:
		total_weight += conns[target]["total"]

	print("  Total connection weight: %.3f" % total_weight)
	print("\n  Pairing probabilities (pure physics):")

	var sorted_conns = []
	for target in conns:
		sorted_conns.append({
			"target": target,
			"weight": conns[target]["total"],
			"prob": 100.0 * conns[target]["total"] / total_weight
		})
	sorted_conns.sort_custom(func(a, b): return a.weight > b.weight)

	for item in sorted_conns:
		var bar_len = int(item.prob / 2)  # Scale for display
		var bar = "█".repeat(bar_len)
		print("    🐝/%s: %.3f (%.1f%%) %s" % [item.target, item.weight, item.prob, bar])

	# Simulate rolls
	print("\n  Simulated 1000 pairing rolls:")
	var roll_counts = {}

	for _i in range(1000):
		var roll = randf() * total_weight
		var cumulative = 0.0
		for item in sorted_conns:
			cumulative += item.weight
			if roll <= cumulative:
				if not roll_counts.has(item.target):
					roll_counts[item.target] = 0
				roll_counts[item.target] += 1
				break

	var sorted_results = []
	for target in roll_counts:
		sorted_results.append({"target": target, "count": roll_counts[target]})
	sorted_results.sort_custom(func(a, b): return a.count > b.count)

	for r in sorted_results:
		var expected = 0.0
		for item in sorted_conns:
			if item.target == r.target:
				expected = item.prob * 10  # 1000 rolls
				break
		print("    🐝/%s: %d rolls (expected ~%.0f)" % [r.target, r.count, expected])


func _analyze_coupling_density() -> void:
	print("-".repeat(60))
	print("  PHASE 1: Coupling Density Analysis")
	print("-".repeat(60))

	var total_icons = icon_registry.icons.size()
	var icons_with_couplings = 0
	var total_couplings = 0
	var coupling_strengths = []
	var no_coupling_icons = []

	for emoji in icon_registry.icons:
		var icon = icon_registry.icons[emoji]
		var num_couplings = icon.hamiltonian_couplings.size()

		if num_couplings > 0:
			icons_with_couplings += 1
			total_couplings += num_couplings

			for target in icon.hamiltonian_couplings:
				coupling_strengths.append(icon.hamiltonian_couplings[target])
		else:
			no_coupling_icons.append(emoji)

	print("  Icons with H couplings: %d / %d (%.1f%%)" % [
		icons_with_couplings, total_icons,
		100.0 * icons_with_couplings / total_icons
	])
	print("  Total coupling edges: %d" % total_couplings)
	print("  Average couplings per icon: %.2f" % (float(total_couplings) / total_icons))

	if coupling_strengths.size() > 0:
		coupling_strengths.sort()
		var min_c = coupling_strengths[0]
		var max_c = coupling_strengths[-1]
		var median_c = coupling_strengths[coupling_strengths.size() / 2]
		var sum = 0.0
		for c in coupling_strengths:
			sum += c
		var avg_c = sum / coupling_strengths.size()

		print("  Coupling strengths: min=%.3f, max=%.3f, median=%.3f, avg=%.3f" % [
			min_c, max_c, median_c, avg_c
		])

	print("\n  Icons with NO couplings (%d):" % no_coupling_icons.size())
	if no_coupling_icons.size() <= 20:
		print("    %s" % " ".join(no_coupling_icons))
	else:
		print("    %s ... (+%d more)" % [" ".join(no_coupling_icons.slice(0, 20)), no_coupling_icons.size() - 20])


func _analyze_bee_couplings() -> void:
	print("\n" + "-".repeat(60))
	print("  PHASE 2: 🐝 (Bee) Coupling Analysis")
	print("-".repeat(60))

	var bee_icon = icon_registry.get_icon("🐝")
	if not bee_icon:
		print("  [ERROR] No 🐝 icon found!")
		return

	print("  🐝 Hamiltonian couplings:")
	var sorted_couplings = []
	for target in bee_icon.hamiltonian_couplings:
		sorted_couplings.append({
			"target": target,
			"strength": bee_icon.hamiltonian_couplings[target]
		})
	sorted_couplings.sort_custom(func(a, b): return a.strength > b.strength)

	for c in sorted_couplings:
		print("    🐝 ↔ %s: %.3f" % [c.target, c.strength])

	print("\n  🐝 Lindblad incoming:")
	for source in bee_icon.lindblad_incoming:
		print("    %s → 🐝: %.3f" % [source, bee_icon.lindblad_incoming[source]])

	print("\n  🐝 Lindblad outgoing:")
	for target in bee_icon.lindblad_outgoing:
		print("    🐝 → %s: %.3f" % [target, bee_icon.lindblad_outgoing[target]])


func _analyze_biome_overlap() -> void:
	print("\n" + "-".repeat(60))
	print("  PHASE 3: Coupling Overlap with BioticFlux")
	print("-".repeat(60))

	# BioticFlux emojis
	var biome_emojis = ["☀", "🌙", "🌾", "🍄", "🍂", "💀"]
	print("  BioticFlux emojis: %s" % " ".join(biome_emojis))

	# Find all icons that couple TO biome emojis
	var coupling_to_biome = {}  # emoji -> {target: strength}

	for emoji in icon_registry.icons:
		var icon = icon_registry.icons[emoji]
		var biome_couplings = {}

		for target in icon.hamiltonian_couplings:
			if target in biome_emojis:
				biome_couplings[target] = icon.hamiltonian_couplings[target]

		if biome_couplings.size() > 0:
			coupling_to_biome[emoji] = biome_couplings

	print("\n  Icons with couplings to BioticFlux (%d):" % coupling_to_biome.size())

	# Sort by total coupling strength
	var sorted_icons = []
	for emoji in coupling_to_biome:
		var total = 0.0
		for t in coupling_to_biome[emoji]:
			total += coupling_to_biome[emoji][t]
		sorted_icons.append({"emoji": emoji, "couplings": coupling_to_biome[emoji], "total": total})

	sorted_icons.sort_custom(func(a, b): return a.total > b.total)

	for item in sorted_icons.slice(0, 15):
		var targets = []
		for t in item.couplings:
			targets.append("%s:%.2f" % [t, item.couplings[t]])
		print("    %s → [%s] (total=%.2f)" % [item.emoji, ", ".join(targets), item.total])


func _simulate_pairing_rolls() -> void:
	print("\n" + "-".repeat(60))
	print("  PHASE 4: Simulated Pairing Rolls for 🐝")
	print("-".repeat(60))

	var bee_icon = icon_registry.get_icon("🐝")
	if not bee_icon:
		return

	# BioticFlux emojis for weighting
	var biome_emojis = ["☀", "🌙", "🌾", "🍄", "🍂", "💀"]
	var player_vocab = ["🌾", "🍄", "💰", "👥"]  # Simulated starter vocab

	print("  Player vocab: %s" % " ".join(player_vocab))
	print("  Biome emojis: %s" % " ".join(biome_emojis))

	# Calculate weights for each possible partner
	print("\n  Weighted pairing candidates:")
	var candidates = []

	for target in bee_icon.hamiltonian_couplings:
		var base_strength = bee_icon.hamiltonian_couplings[target]

		# Weighting factors
		var biome_factor = 2.0 if target in biome_emojis else 0.5
		var vocab_factor = 1.5 if target in player_vocab else 1.0

		var final_weight = base_strength * biome_factor * vocab_factor

		candidates.append({
			"target": target,
			"base": base_strength,
			"biome_factor": biome_factor,
			"vocab_factor": vocab_factor,
			"weight": final_weight
		})

	candidates.sort_custom(func(a, b): return a.weight > b.weight)

	var total_weight = 0.0
	for c in candidates:
		total_weight += c.weight

	for c in candidates:
		var prob = 100.0 * c.weight / total_weight if total_weight > 0 else 0
		var in_biome = "✓" if c.biome_factor > 1 else " "
		var in_vocab = "✓" if c.vocab_factor > 1 else " "
		print("    🐝/%s: base=%.2f × biome=%s%s × vocab=%s%s → weight=%.3f (%.1f%%)" % [
			c.target, c.base,
			"2.0" if c.biome_factor > 1 else "0.5", in_biome,
			"1.5" if c.vocab_factor > 1 else "1.0", in_vocab,
			c.weight, prob
		])

	# Simulate 100 rolls
	print("\n  Simulated 100 pairing rolls:")
	var roll_counts = {}

	for _i in range(100):
		var roll = randf() * total_weight
		var cumulative = 0.0
		for c in candidates:
			cumulative += c.weight
			if roll <= cumulative:
				if not roll_counts.has(c.target):
					roll_counts[c.target] = 0
				roll_counts[c.target] += 1
				break

	var sorted_results = []
	for target in roll_counts:
		sorted_results.append({"target": target, "count": roll_counts[target]})
	sorted_results.sort_custom(func(a, b): return a.count > b.count)

	for r in sorted_results:
		print("    🐝/%s: %d rolls" % [r.target, r.count])


func _finish() -> void:
	print("\n" + "=".repeat(70))
	print("Analysis complete.")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
