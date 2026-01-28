#ifndef QUANTUM_EVOLUTION_ENGINE_H
#define QUANTUM_EVOLUTION_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <Eigen/Dense>
#include <Eigen/Sparse>
#include <vector>
#include <complex>

namespace godot {

/**
 * QuantumEvolutionEngine - Batched native quantum evolution
 *
 * Solves the performance problem of GDScript ↔ C++ bridge overhead by:
 * 1. Registering all operators ONCE at setup time
 * 2. Precomputing L†, L†L for each Lindblad operator
 * 3. Doing complete evolution step in single native call
 *
 * Expected speedup: 10-20× for typical biomes (Forest: 130ms → 7ms)
 */
class QuantumEvolutionEngine : public RefCounted {
    GDCLASS(QuantumEvolutionEngine, RefCounted)

public:
    QuantumEvolutionEngine();
    ~QuantumEvolutionEngine();

    // Setup methods (called once during biome initialization)
    void set_dimension(int dim);
    void set_hamiltonian(const PackedFloat64Array& H_packed);
    void add_lindblad_triplets(const PackedFloat64Array& triplets);
    void clear_operators();
    void finalize();  // Precompute all cached values

    // Query methods
    int get_dimension() const;
    int get_lindblad_count() const;
    bool is_finalized() const;

    // Evolution (single call per frame!)
    PackedFloat64Array evolve_step(const PackedFloat64Array& rho_data, float dt);

    // Batch evolution with subcycling
    PackedFloat64Array evolve(const PackedFloat64Array& rho_data, float dt, float max_dt);

    // Mutual information computation (piggybacks on evolution)
    // Returns: [mi_01, mi_02, ..., mi_0n, mi_12, mi_13, ..., mi_(n-1)n] for all pairs
    // Format: num_qubits * (num_qubits - 1) / 2 values in upper triangular order
    PackedFloat64Array compute_all_mutual_information(const PackedFloat64Array& rho_data, int num_qubits);

    // Combined evolution + MI computation (single call for both)
    // Returns Dictionary with "rho" (evolved state) and "mi" (mutual information array)
    Dictionary evolve_with_mi(const PackedFloat64Array& rho_data, float dt, float max_dt, int num_qubits);

protected:
    static void _bind_methods();

private:
    int m_dim;
    bool m_finalized;
    int m_num_qubits;  // Cached for MI computation

    // Dense Hamiltonian (optional)
    Eigen::MatrixXcd m_hamiltonian;
    bool m_has_hamiltonian;

    // Sparse Lindblad operators
    std::vector<Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>> m_lindblads;

    // Cached values for efficiency
    std::vector<Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>> m_lindblad_dags;  // L†
    std::vector<Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>> m_LdagLs;        // L†L

    // Helper methods
    Eigen::MatrixXcd unpack_dense(const PackedFloat64Array& data) const;
    PackedFloat64Array pack_dense(const Eigen::MatrixXcd& mat) const;

    // MI computation helpers
    Eigen::MatrixXcd partial_trace_single(const Eigen::MatrixXcd& rho, int qubit, int num_qubits) const;
    Eigen::MatrixXcd partial_trace_complement(const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const;
    double von_neumann_entropy(const Eigen::MatrixXcd& reduced_rho) const;
    double mutual_information(const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const;
};

}  // namespace godot

#endif  // QUANTUM_EVOLUTION_ENGINE_H
