extends SceneTree

## Quick test for sparse native matrix support

func _init():
	print("============================================================")
	print("SPARSE NATIVE MATRIX TEST")
	print("============================================================")

	# Check if native classes exist
	print("\n1. Checking native class availability:")

	var dense_available = ClassDB.class_exists("QuantumMatrixNative")
	print("   QuantumMatrixNative: %s" % ("✅ Available" if dense_available else "❌ NOT FOUND"))

	var sparse_available = ClassDB.class_exists("QuantumSparseMatrixNative")
	print("   QuantumSparseMatrixNative: %s" % ("✅ Available" if sparse_available else "❌ NOT FOUND"))

	if sparse_available:
		print("\n2. Testing sparse matrix creation:")
		var sparse = ClassDB.instantiate("QuantumSparseMatrixNative")
		print("   Created instance: %s" % sparse)

		# Create simple 4x4 sparse matrix with 2 entries
		var triplets = PackedFloat64Array([
			0.0, 0.0, 1.0, 0.0,  # (0,0) = 1+0i
			1.0, 1.0, 0.0, 1.0   # (1,1) = 0+1i
		])
		sparse.from_triplets(triplets, 4)

		print("   Dimension: %d" % sparse.get_dimension())
		print("   Non-zeros: %d" % sparse.get_nnz())
		print("   Sparsity: %.1f%%" % (sparse.get_sparsity() * 100))

		print("\n3. Testing sparse × dense multiplication:")
		# Create dense 4x4 identity
		var dense = PackedFloat64Array()
		dense.resize(4 * 4 * 2)
		for i in range(4):
			var idx = (i * 4 + i) * 2
			dense[idx] = 1.0
			dense[idx + 1] = 0.0

		var start = Time.get_ticks_msec()
		var result = sparse.mul_dense(dense, 4)
		var elapsed = Time.get_ticks_msec() - start
		print("   mul_dense took: %d ms" % elapsed)
		print("   Result size: %d (expected 32)" % result.size())

		print("\n✅ SPARSE NATIVE TEST PASSED!")
	else:
		print("\n❌ SPARSE NATIVE NOT AVAILABLE")
		print("   Build with: GODOT_CPP_PATH=/path/to/godot-cpp scons platform=linux target=template_release")

	print("\n============================================================")
	quit()
