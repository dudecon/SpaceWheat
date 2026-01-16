#ifndef QUANTUM_SPARSE_NATIVE_H
#define QUANTUM_SPARSE_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <Eigen/Sparse>
#include <Eigen/Dense>
#include <complex>

namespace godot {

/**
 * QuantumSparseMatrixNative - Sparse matrix for Hamiltonians and Lindblad operators
 *
 * Quantum operators (H, L) are typically 90-99% zeros. Using sparse representation:
 * - Memory: O(nnz) instead of O(n²)
 * - Sparse×Dense mul: O(nnz × n) instead of O(n³)
 *
 * For a 32×32 matrix with 50 non-zeros (typical Lindblad):
 * - Dense: 32³ = 32,768 operations
 * - Sparse: 50 × 32 = 1,600 operations
 * - Speedup: ~20x
 */
class QuantumSparseMatrixNative : public RefCounted {
    GDCLASS(QuantumSparseMatrixNative, RefCounted)

private:
    Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> m_sparse;
    int m_dim;

    // Helper to pack dense result
    PackedFloat64Array pack_dense(const Eigen::MatrixXcd& mat, int dim) const;

    // Helper to unpack dense matrix from GDScript
    Eigen::MatrixXcd unpack_dense(const PackedFloat64Array& data, int dim) const;

protected:
    static void _bind_methods();

public:
    QuantumSparseMatrixNative();
    ~QuantumSparseMatrixNative();

    // Load from GDScript - triplet format (row, col, real, imag for each entry)
    // values: [r0, c0, re0, im0, r1, c1, re1, im1, ...]
    void from_triplets(const PackedFloat64Array& triplets, int dim);

    // Load from dense matrix (auto-sparsify with threshold)
    void from_dense(const PackedFloat64Array& data, int dim, double threshold);

    // Get statistics
    int get_dimension() const;
    int get_nnz() const;  // Number of non-zeros
    double get_sparsity() const;  // Fraction of zeros

    // Core operations for quantum evolution

    /**
     * Sparse × Dense multiplication: A * B where A is this sparse matrix
     * This is the key operation for quantum evolution:
     * - L ρ (Lindblad times density matrix)
     * - H ρ (Hamiltonian times density matrix)
     *
     * Returns dense result as packed array.
     */
    PackedFloat64Array mul_dense(const PackedFloat64Array& dense, int dim) const;

    /**
     * Dense × Sparse multiplication: B * A where A is this sparse matrix
     * Needed for:
     * - ρ H (density matrix times Hamiltonian)
     * - ρ L† (density matrix times Lindblad dagger)
     */
    PackedFloat64Array dense_mul(const PackedFloat64Array& dense, int dim) const;

    /**
     * Sparse conjugate transpose (dagger)
     * Returns new sparse matrix packed as triplets.
     */
    PackedFloat64Array dagger() const;

    /**
     * Commutator with dense matrix: [A, ρ] = Aρ - ρA
     * Common in Hamiltonian evolution: -i[H, ρ]
     */
    PackedFloat64Array commutator_with_dense(const PackedFloat64Array& dense, int dim) const;

    /**
     * Lindblad term: L ρ L† - ½{L†L, ρ}
     * Full Lindblad dissipator for a single jump operator.
     * This is the most expensive operation, optimized here.
     *
     * Args:
     *   rho: density matrix (dense, packed)
     *   dim: dimension
     *
     * Returns:
     *   Result contribution to dρ/dt (dense, packed)
     */
    PackedFloat64Array lindblad_dissipator(const PackedFloat64Array& rho, int dim) const;

    /**
     * Sparse + Sparse (for building composite operators)
     */
    PackedFloat64Array add_sparse(const PackedFloat64Array& other_triplets, int other_dim) const;

    /**
     * Scale by complex number
     */
    PackedFloat64Array scale(double re, double im) const;
};

}

#endif
