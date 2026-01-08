extends SceneTree

## Unit Tests for RegisterMap (Model C Analog Upgrade)
##
## Tests the emoji ↔ coordinate translation layer.

const RegisterMap = preload("res://Core/QuantumSubstrate/RegisterMap.gd")


func _init():
	print("\n=== RegisterMap Unit Tests ===\n")

	var passed = 0
	var failed = 0

	# Test 1: Basic axis registration
	print("Test 1: Register single axis")
	var rm1 = RegisterMap.new()
	rm1.register_axis(0, "🔥", "❄️")

	if rm1.has("🔥") and rm1.has("❄️"):
		if rm1.qubit("🔥") == 0 and rm1.qubit("❄️") == 0:
			if rm1.pole("🔥") == 0 and rm1.pole("❄️") == 1:
				print("  ✓ PASS: Axis registered correctly")
				passed += 1
			else:
				print("  ✗ FAIL: Poles incorrect")
				failed += 1
		else:
			print("  ✗ FAIL: Qubits incorrect")
			failed += 1
	else:
		print("  ✗ FAIL: Emojis not registered")
		failed += 1

	# Test 2: Three-axis registration (Kitchen)
	print("\nTest 2: Register three axes (Kitchen)")
	var rm2 = RegisterMap.new()
	rm2.register_axis(0, "🔥", "❄️")  # Temperature
	rm2.register_axis(1, "💧", "🏜️")  # Moisture
	rm2.register_axis(2, "💨", "🌾")  # Substance

	var all_present = (
		rm2.has("🔥") and rm2.has("❄️") and
		rm2.has("💧") and rm2.has("🏜️") and
		rm2.has("💨") and rm2.has("🌾")
	)

	if all_present and rm2.num_qubits == 3:
		print("  ✓ PASS: All 6 emojis registered, 3 qubits")
		passed += 1
	else:
		print("  ✗ FAIL: Missing emojis or wrong num_qubits")
		failed += 1

	# Test 3: Dimension calculation
	print("\nTest 3: Dimension calculation")
	if rm2.dim() == 8:  # 2^3 = 8
		print("  ✓ PASS: dim() = 8 for 3 qubits")
		passed += 1
	else:
		print("  ✗ FAIL: dim() = %d, expected 8" % rm2.dim())
		failed += 1

	# Test 4: Qubit indices
	print("\nTest 4: Qubit indices")
	if (rm2.qubit("🔥") == 0 and rm2.qubit("💧") == 1 and
		rm2.qubit("💨") == 2):
		print("  ✓ PASS: Qubit indices correct")
		passed += 1
	else:
		print("  ✗ FAIL: Qubit indices wrong")
		failed += 1

	# Test 5: Pole values
	print("\nTest 5: Pole values")
	if (rm2.pole("🔥") == 0 and rm2.pole("❄️") == 1 and
		rm2.pole("💧") == 0 and rm2.pole("🏜️") == 1 and
		rm2.pole("💨") == 0 and rm2.pole("🌾") == 1):
		print("  ✓ PASS: All poles correct (north=0, south=1)")
		passed += 1
	else:
		print("  ✗ FAIL: Pole values incorrect")
		failed += 1

	# Test 6: basis_to_emojis (|000⟩ = bread state)
	print("\nTest 6: basis_to_emojis(0) → |000⟩ = [🔥, 💧, 💨]")
	var emojis_0 = rm2.basis_to_emojis(0)
	if (emojis_0.size() == 3 and
		emojis_0[0] == "🔥" and emojis_0[1] == "💧" and emojis_0[2] == "💨"):
		print("  ✓ PASS: |000⟩ → [🔥, 💧, 💨] (bread state)")
		passed += 1
	else:
		print("  ✗ FAIL: Got %s" % str(emojis_0))
		failed += 1

	# Test 7: basis_to_emojis (|111⟩ = ground state)
	print("\nTest 7: basis_to_emojis(7) → |111⟩ = [❄️, 🏜️, 🌾]")
	var emojis_7 = rm2.basis_to_emojis(7)
	if (emojis_7.size() == 3 and
		emojis_7[0] == "❄️" and emojis_7[1] == "🏜️" and emojis_7[2] == "🌾"):
		print("  ✓ PASS: |111⟩ → [❄️, 🏜️, 🌾] (ground state)")
		passed += 1
	else:
		print("  ✗ FAIL: Got %s" % str(emojis_7))
		failed += 1

	# Test 8: emojis_to_basis (reverse conversion)
	print("\nTest 8: emojis_to_basis([🔥, 💧, 💨]) → 0")
	var index_0 = rm2.emojis_to_basis(["🔥", "💧", "💨"])
	if index_0 == 0:
		print("  ✓ PASS: [🔥, 💧, 💨] → 0")
		passed += 1
	else:
		print("  ✗ FAIL: Got %d, expected 0" % index_0)
		failed += 1

	# Test 9: emojis_to_basis (ground state)
	print("\nTest 9: emojis_to_basis([❄️, 🏜️, 🌾]) → 7")
	var index_7 = rm2.emojis_to_basis(["❄️", "🏜️", "🌾"])
	if index_7 == 7:
		print("  ✓ PASS: [❄️, 🏜️, 🌾] → 7")
		passed += 1
	else:
		print("  ✗ FAIL: Got %d, expected 7" % index_7)
		failed += 1

	# Test 10: Mixed state |101⟩ = [❄️, 💧, 🌾]
	print("\nTest 10: Mixed state |101⟩")
	var emojis_5 = rm2.basis_to_emojis(5)  # Binary 101 = 5
	var index_5 = rm2.emojis_to_basis(emojis_5)
	# 5 = 0b101: qubit0=1 (south/❄️), qubit1=0 (north/💧), qubit2=1 (south/🌾)
	if (emojis_5[0] == "❄️" and emojis_5[1] == "💧" and emojis_5[2] == "🌾" and
		index_5 == 5):
		print("  ✓ PASS: |101⟩ ↔ 5 bidirectional")
		passed += 1
	else:
		print("  ✗ FAIL: Conversion failed - got %s → %d" % [str(emojis_5), index_5])
		failed += 1

	# Test 11: Unknown emoji
	print("\nTest 11: Unknown emoji query")
	if not rm2.has("🍞") and rm2.qubit("🍞") == -1 and rm2.pole("🍞") == -1:
		print("  ✓ PASS: Unknown emoji returns -1")
		passed += 1
	else:
		print("  ✗ FAIL: Unknown emoji not handled")
		failed += 1

	# Test 12: Edge case - invalid basis index
	print("\nTest 12: Invalid basis index")
	var invalid_emojis = rm2.basis_to_emojis(10)  # Out of range for 3 qubits
	if invalid_emojis.is_empty():
		print("  ✓ PASS: Invalid index returns empty array")
		passed += 1
	else:
		print("  ✗ FAIL: Invalid index should return empty")
		failed += 1

	# Test 13: All basis states roundtrip
	print("\nTest 13: All basis states roundtrip (0-7)")
	var roundtrip_ok = true
	for i in range(8):
		var emojis = rm2.basis_to_emojis(i)
		var back = rm2.emojis_to_basis(emojis)
		if back != i:
			roundtrip_ok = false
			print("  ✗ Roundtrip failed for %d → %s → %d" % [i, str(emojis), back])
			break

	if roundtrip_ok:
		print("  ✓ PASS: All 8 basis states roundtrip correctly")
		passed += 1
	else:
		failed += 1

	# Summary
	print("\n" + "=".repeat(50))
	print("Summary: %d passed, %d failed" % [passed, failed])
	if failed == 0:
		print("✅ All RegisterMap tests passed!")
	else:
		print("❌ Some tests failed")
	print("=".repeat(50) + "\n")

	# Exit after tests
	quit()
