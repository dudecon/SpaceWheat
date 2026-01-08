extends SceneTree

## Demo: Faction Composition System
## Run with: godot --headless --script test_factions.gd

const Faction = preload("res://Core/Factions/Faction.gd")
const CoreFactions = preload("res://Core/Factions/CoreFactions.gd")
const IconBuilder = preload("res://Core/Factions/IconBuilder.gd")

func _init():
	print("\n")
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║     SpaceWheat Faction → Icon Composition Demo               ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	
	# Show all factions
	print("\n┌─ Core Factions ─────────────────────────────────────────────┐")
	for faction in CoreFactions.get_all():
		print("│ %-20s [%s] %s" % [faction.name, faction.ring, " ".join(faction.signature)])
	print("└──────────────────────────────────────────────────────────────┘")
	
	# Show shared emojis
	print("\n┌─ Shared Emojis (Contested Dynamics) ───────────────────────┐")
	var factions = CoreFactions.get_all()
	for i in range(factions.size()):
		for j in range(i + 1, factions.size()):
			var shared = CoreFactions.get_shared_emojis(factions[i], factions[j])
			if shared.size() > 0:
				print("│ %s ∩ %s" % [factions[i].name, factions[j].name])
				print("│   → %s" % " ".join(shared))
	print("└──────────────────────────────────────────────────────────────┘")
	
	# Build Forest biome and show composed Icons
	print("\n┌─ Forest Biome Composition ─────────────────────────────────┐")
	print("│ Factions: Celestial + Verdant + Mycelial + Swift + Pack    │")
	print("└──────────────────────────────────────────────────────────────┘")
	
	var forest_icons = IconBuilder.build_forest_biome()
	print("\nForest has %d unique emojis:\n  %s" % [
		forest_icons.size(),
		" ".join(forest_icons.keys())
	])
	
	# Show some interesting contested Icons
	print("\n┌─ Contested Icon: 🍂 (Verdant + Mycelial + Wildfire) ─────────┐")
	_print_icon_compact(forest_icons.get("🍂"))
	
	print("\n┌─ Contested Icon: 🌿 (Verdant + Swift + Pollinator + Fire) ──┐")
	_print_icon_compact(forest_icons.get("🌿"))
	
	print("\n┌─ Contested Icon: 🐇 (Swift + Pack + Plague) ────────────────┐")
	_print_icon_compact(forest_icons.get("🐇"))
	
	print("\n┌─ Contested Icon: 🌙 (Celestial + Mycelial) ────────────────┐")
	_print_icon_compact(forest_icons.get("🌙"))
	
	# Show new emojis
	print("\n┌─ 🌲 Tree (stable Verdant endpoint) ────────────────────────┐")
	_print_icon_compact(forest_icons.get("🌲"))
	
	print("\n┌─ 💧 Water (Celestial - drives growth + mushrooms) ─────────┐")
	_print_icon_compact(forest_icons.get("💧"))
	
	# Show alignment effects on wheat
	print("\n┌─ 🌾 Wheat with GATED pollination ───────────────────────────┐")
	_print_icon_compact(forest_icons.get("🌾"))
	
	# Show alignment effects on mushroom
	print("\n┌─ 🍄 Mushroom (moon+water help, sun kills) ─────────────────┐")
	_print_icon_compact(forest_icons.get("🍄"))
	
	# NEW: Show the new mechanics
	print("\n┌─ 🐝 Pollinator (CRITICAL gating for grain) ────────────────┐")
	_print_icon_compact(forest_icons.get("🐝"))
	
	print("\n┌─ 🦠 Disease (density-dependent culling) ───────────────────┐")
	_print_icon_compact(forest_icons.get("🦠"))
	
	print("\n┌─ 🔥 Fire (destruction + renewal) ──────────────────────────┐")
	_print_icon_compact(forest_icons.get("🔥"))
	
	print("\n┌─ 💀 Death (gateway between Pack + Mycelial + Plague) ──────┐")
	_print_icon_compact(forest_icons.get("💀"))
	
	# Show a non-contested Icon for comparison
	print("\n┌─ Single-Faction Icon: 🐺 (Pack Lords only) ────────────────┐")
	_print_icon_compact(forest_icons.get("🐺"))
	
	# Kitchen biome
	print("\n┌─ Kitchen Biome Composition ────────────────────────────────┐")
	print("│ Factions: Hearth Keepers + Verdant Pulse                   │")
	print("└──────────────────────────────────────────────────────────────┘")
	
	var kitchen_icons = IconBuilder.build_kitchen_biome()
	print("\nKitchen has %d unique emojis:\n  %s" % [
		kitchen_icons.size(),
		" ".join(kitchen_icons.keys())
	])
	
	# Show the cross-faction coupling
	print("\n┌─ Cross-Faction: 💨 Flour (Hearth ← Verdant 🌾) ─────────────┐")
	_print_icon_compact(kitchen_icons.get("💨"))
	
	# Summary stats
	print("\n╔══════════════════════════════════════════════════════════════╗")
	print("║ Summary Statistics                                           ║")
	print("╠══════════════════════════════════════════════════════════════╣")
	print("║ Core Factions:     %d                                         ║" % factions.size())
	print("║ Total Emojis:      %d                                        ║" % CoreFactions.get_all_emojis().size())
	print("║ Forest Biome:      %d emojis (5 factions)                    ║" % forest_icons.size())
	print("║ Kitchen Biome:     %d emojis (2 factions)                    ║" % kitchen_icons.size())
	print("╚══════════════════════════════════════════════════════════════╝")
	
	print("\n✓ Demo complete\n")
	quit()


func _print_icon_compact(icon: Icon) -> void:
	if icon == null:
		print("│ (null)")
		return
	
	print("│ %s  self_energy=%.2f" % [icon.emoji, icon.self_energy])
	print("│ %s" % icon.description)
	
	if icon.self_energy_driver != "":
		print("│ ⚡ DRIVER: %s @ %.3f Hz" % [icon.self_energy_driver, icon.driver_frequency])
	
	if icon.hamiltonian_couplings.size() > 0:
		var h_str = []
		for t in icon.hamiltonian_couplings:
			h_str.append("%s:%.2f" % [t, icon.hamiltonian_couplings[t]])
		print("│ H couplings: %s" % ", ".join(h_str))
	
	if icon.lindblad_incoming.size() > 0:
		var l_str = []
		for s in icon.lindblad_incoming:
			l_str.append("←%s:%.3f" % [s, icon.lindblad_incoming[s]])
		print("│ L incoming: %s" % ", ".join(l_str))
	
	if icon.lindblad_outgoing.size() > 0:
		var l_str = []
		for t in icon.lindblad_outgoing:
			l_str.append("→%s:%.3f" % [t, icon.lindblad_outgoing[t]])
		print("│ L outgoing: %s" % ", ".join(l_str))
	
	# Show GATED lindblad (with inverse flag)
	if icon.has_meta("gated_lindblad"):
		var gated = icon.get_meta("gated_lindblad")
		var g_str = []
		for g in gated:
			var inv = g.get("inverse", false)
			var gate_expr = "P(%s)" % g.get("gate", "?")
			if inv:
				gate_expr = "(1-P(%s))" % g.get("gate", "?")
			g_str.append("←%s:%.2f×%s^%.1f%s" % [
				g.get("source", "?"),
				g.get("rate", 0),
				gate_expr,
				g.get("power", 1.0),
				" ⚠️INV" if inv else ""])
		print("│ 🔒 GATED: %s" % ", ".join(g_str))
	
	# Show measurement behavior
	if icon.has_meta("measurement_behavior"):
		var mb = icon.get_meta("measurement_behavior")
		if mb.get("inverts", false):
			print("│ 🔮 MEASUREMENT INVERTS → %s" % mb.get("invert_target", "?"))
	
	if icon.energy_couplings.size() > 0:
		var e_str = []
		for obs in icon.energy_couplings:
			var val = icon.energy_couplings[obs]
			var sign = "+" if val >= 0 else ""
			e_str.append("~%s:%s%.2f" % [obs, sign, val])
		print("│ Alignment: %s" % ", ".join(e_str))
	
	if icon.decay_rate > 0:
		print("│ Decay: %.3f → %s" % [icon.decay_rate, icon.decay_target])
	
	print("└──────────────────────────────────────────────────────────────┘")
