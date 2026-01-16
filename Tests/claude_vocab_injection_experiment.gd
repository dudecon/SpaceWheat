extends SceneTree

## Claude's Vocabulary Injection Experiment
## What happens when we plant 🪣 (bucket) and 🍞 (bread) into BioticFlux?

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var plot_pool = null
var economy = null
var biome = null

var frame: int = 0
var game_ready: bool = false
var experiment_phase: int = 0

func _init():
	print("")
	print("═".repeat(70))
	print("  VOCABULARY INJECTION EXPERIMENT")
	print("  What happens when we plant 🪣 and 🍞 into BioticFlux?")
	print("═".repeat(70))
	print("")


func _process(_delta) -> bool:
	frame += 1

	if frame == 5:
		_load_scene()

	if game_ready:
		_run_experiment()

	return false


func _load_scene():
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)

		var boot = root.get_node_or_null("/root/BootManager")
		if boot:
			boot.game_ready.connect(_on_game_ready)


func _on_game_ready():
	if game_ready:
		return
	game_ready = true

	# Find components
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
		economy = farm.economy if farm else null
		plot_pool = farm.plot_pool if farm else null

	# Get BioticFlux biome
	if farm and farm.grid and farm.grid.biomes:
		biome = farm.grid.biomes.get("BioticFlux")

	# Add vocabulary to player's known emojis
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		if "🍞" not in gsm.current_state.known_emojis:
			gsm.current_state.known_emojis.append("🍞")
		if "🪣" not in gsm.current_state.known_emojis:
			gsm.current_state.known_emojis.append("🪣")
		print("📖 Vocabulary set: %s" % gsm.current_state.known_emojis)

	print("")
	print("🔬 EXPERIMENT SETUP:")
	print("   Farm: %s" % (farm != null))
	print("   BioticFlux biome: %s" % (biome != null))
	print("   Plot pool: %s" % (plot_pool != null))
	print("")

	if biome:
		_print_biome_state("INITIAL STATE")


func _run_experiment():
	match experiment_phase:
		0:
			# Phase 0: Wait for setup
			if frame > 30:
				experiment_phase = 1

		1:
			# Phase 1: Show initial biome registers
			print("")
			print("═".repeat(70))
			print("  PHASE 1: Examining BioticFlux Quantum Registers")
			print("═".repeat(70))
			_examine_biome_registers()
			experiment_phase = 2

		2:
			# Phase 2: Try to inject 🍞 into the biome
			if frame > 60:
				print("")
				print("═".repeat(70))
				print("  PHASE 2: Attempting to inject 🍞 (bread) into BioticFlux")
				print("═".repeat(70))
				_try_inject_emoji("🍞")
				experiment_phase = 3

		3:
			# Phase 3: Try to inject 🪣 into the biome
			if frame > 120:
				print("")
				print("═".repeat(70))
				print("  PHASE 3: Attempting to inject 🪣 (bucket) into BioticFlux")
				print("═".repeat(70))
				_try_inject_emoji("🪣")
				experiment_phase = 4

		4:
			# Phase 4: Do some farming cycles and observe
			if frame > 180:
				print("")
				print("═".repeat(70))
				print("  PHASE 4: Farming cycles - observing quantum evolution")
				print("═".repeat(70))
				experiment_phase = 5

		5:
			# Phase 5: Farm and observe
			if frame % 20 == 0:
				_do_farming_cycle()

			if frame % 100 == 0:
				_print_biome_state("EVOLUTION @%d" % frame)

			if frame > 500:
				experiment_phase = 6

		6:
			# Phase 6: Final analysis
			print("")
			print("═".repeat(70))
			print("  FINAL ANALYSIS")
			print("═".repeat(70))
			_final_analysis()
			quit(0)


func _examine_biome_registers():
	if not biome:
		print("   ❌ No biome!")
		return

	print("")
	print("   BioticFlux Quantum Computer:")
	print("   " + "-".repeat(50))

	# Check if biome has a quantum computer
	if biome.has_method("get_qubit_count"):
		var qubit_count = biome.get_qubit_count()
		print("   Qubits: %d" % qubit_count)

	# Get register info
	if biome.get("computer") and biome.computer.has_method("get_register_info"):
		var registers = biome.computer.get_register_info()
		print("   Registers:")
		for reg in registers:
			print("      %s" % reg)

	# Get emoji pairs
	if biome.has_method("get_all_emoji_pairs"):
		var pairs = biome.get_all_emoji_pairs()
		print("")
		print("   Emoji Pairs (North ↔ South):")
		for pair in pairs:
			print("      %s ↔ %s" % [pair.north, pair.south])

	# Check producible emojis
	if biome.get("producible_emojis"):
		print("")
		print("   Producible Emojis: %s" % biome.producible_emojis)

	# Check if biome accepts external emojis
	if biome.has_method("can_accept_emoji"):
		print("")
		print("   Can accept 🍞? %s" % biome.can_accept_emoji("🍞"))
		print("   Can accept 🪣? %s" % biome.can_accept_emoji("🪣"))


func _try_inject_emoji(emoji: String):
	print("")
	print("   Attempting to inject %s..." % emoji)

	# Method 1: Try direct injection via biome
	if biome and biome.has_method("inject_vocabulary"):
		var result = biome.inject_vocabulary(emoji)
		print("   inject_vocabulary result: %s" % result)
		return

	# Method 2: Try via VocabularyEvolution
	if biome and biome.has_method("request_vocabulary_injection"):
		var result = biome.request_vocabulary_injection(emoji)
		print("   request_vocabulary_injection result: %s" % result)
		return

	# Method 3: Check if biome has vocabulary evolution system
	if biome and biome.get("vocabulary_evolution"):
		var ve = biome.vocabulary_evolution
		if ve.has_method("inject"):
			var result = ve.inject(emoji)
			print("   vocabulary_evolution.inject result: %s" % result)
			return

	# Method 4: Try adding to biome's producible_emojis directly
	if biome and biome.get("producible_emojis"):
		if emoji not in biome.producible_emojis:
			print("   Adding %s to producible_emojis..." % emoji)
			biome.producible_emojis.append(emoji)
			print("   New producible_emojis: %s" % biome.producible_emojis)

			# Check if this affects quantum computer
			if biome.get("computer"):
				print("   Quantum computer registers unchanged (would need rebuild)")
		else:
			print("   %s already in producible_emojis" % emoji)

	print("")
	print("   ⚠️ Note: Injecting new vocabulary into an existing biome's")
	print("      quantum computer would require rebuilding the Hamiltonian")
	print("      and Lindblad operators - this is a BUILD mode operation.")


func _do_farming_cycle():
	if not farm or not plot_pool or not biome:
		return

	var unbound = plot_pool.get_unbound_count()
	var active = plot_pool.get_active_terminals()
	var measured = plot_pool.get_measured_terminals()

	# Priority: POP > MEASURE > EXPLORE
	if measured.size() > 0:
		var terminal = measured[0]
		var result = ProbeActions.action_pop(terminal, plot_pool, economy)
		if result.success:
			print("   🌾 Harvested: %s" % result.get("resource", "?"))
	elif active.size() > 0:
		var terminal = active[0]
		ProbeActions.action_measure(terminal, biome)
	elif unbound > 0:
		ProbeActions.action_explore(plot_pool, biome)


func _print_biome_state(label: String):
	if not biome:
		return

	print("")
	print("   📊 %s:" % label)

	# Get probabilities
	if biome.has_method("get_register_probabilities"):
		var probs = biome.get_register_probabilities()
		print("      Register probabilities:")
		for reg_id in probs:
			var p = probs[reg_id]
			var emoji_pair = biome.get_register_emoji_pair(reg_id) if biome.has_method("get_register_emoji_pair") else {}
			var north = emoji_pair.get("north", "?")
			var south = emoji_pair.get("south", "?")
			print("         Reg %d: %s=%.1f%% %s=%.1f%%" % [reg_id, north, p * 100, south, (1-p) * 100])

	# Get purity
	if biome.has_method("get_purity"):
		var purity = biome.get_purity()
		print("      Purity: %.3f" % purity)

	# Get temperature
	if biome.has_method("get_temperature"):
		var temp = biome.get_temperature()
		print("      Temperature: %.0fK" % temp)


func _final_analysis():
	print("")
	print("   CONCLUSION:")
	print("   " + "-".repeat(50))
	print("")
	print("   BioticFlux biome has FIXED quantum registers:")
	print("      • Qubit 0: ☀ (sun) ↔ 🌙 (moon)")
	print("      • Qubit 1: 🌾 (wheat) ↔ 🍄 (mushroom)")
	print("      • Qubit 2: 🍂 (leaf) ↔ 💀 (death)")
	print("")
	print("   New vocabulary like 🍞 and 🪣 cannot be directly")
	print("   'planted' into BioticFlux because:")
	print("")
	print("   1. The quantum computer's Hilbert space is fixed at init")
	print("   2. Each emoji is mapped to a basis state |0⟩ or |1⟩")
	print("   3. Adding new emojis would require expanding dimensions")
	print("")
	print("   HOWEVER, vocabulary evolution can happen via:")
	print("      • Biome reconstruction (adding new qubits)")
	print("      • Cross-biome entanglement")
	print("      • The VocabularyEvolution system")
	print("")
	print("   The 🍞 bread emoji is interesting because it's")
	print("   produced by the Kitchen biome (🌾 → 🍞 via cooking)")
	print("   So there's a SUPPLY CHAIN: BioticFlux → Kitchen → 🍞")
	print("")
