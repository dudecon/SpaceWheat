extends Node

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")

func _ready() -> void:
	var sep = "════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("DIAGNOSTIC: CELESTIAL PATH CONTINUITY")
	print("Checking for discontinuities in sun theta/phi trajectory")
	print(sep)

	var biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	print("\nTime | θ (deg) | φ (deg) | Δθ | Δφ | Notes")
	print(sep)

	var dt = 0.016666
	var total_time = 0.0
	var next_sample = 0.0
	var prev_theta = 0.0
	var prev_phi = 0.0
	var discontinuities = 0

	while total_time < 40.0:
		total_time += dt
		biome.time_tracker.update(dt)
		biome._apply_celestial_oscillation(dt)

		if total_time >= next_sample:
			var theta_deg = biome.sun_qubit.theta * 180.0 / PI
			var phi_deg = fmod(biome.sun_qubit.phi * 180.0 / PI, 360.0)
			if phi_deg < 0:
				phi_deg += 360.0

			var dtheta = theta_deg - prev_theta
			var dphi = phi_deg - prev_phi

			# Handle phi wraparound
			if dphi > 180:
				dphi -= 360
			elif dphi < -180:
				dphi += 360

			var notes = ""
			if abs(dtheta) > 5.0:  # Big jump in theta
				notes = "⚠️ LARGE θ JUMP"
				discontinuities += 1
			if abs(dphi) > 50.0 and abs(dphi) < 310.0:  # Not expected wraparound
				notes += " ⚠️ LARGE φ JUMP"
				discontinuities += 1

			# Flag near-pole positions
			if theta_deg < 5.0:
				notes += " [NEAR NORTH POLE]"
			elif theta_deg > 175.0:
				notes += " [NEAR SOUTH POLE]"

			print("%.1fs | %6.1f° | %6.1f° | %+5.1f° | %+6.1f° | %s" % [
				total_time,
				theta_deg,
				phi_deg,
				dtheta,
				dphi,
				notes
			])

			prev_theta = theta_deg
			prev_phi = phi_deg
			next_sample += 2.0

	print(sep)
	print("\nDiscontinuities detected: %d" % discontinuities)
	if discontinuities == 0:
		print("✓ Path is smooth and continuous")
	else:
		print("✗ Path has jumps - check pole handling")
	print(sep + "\n")

	get_tree().quit()
