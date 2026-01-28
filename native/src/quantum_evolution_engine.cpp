#include "quantum_evolution_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

using namespace godot;

void QuantumEvolutionEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_dimension", "dim"),
                         &QuantumEvolutionEngine::set_dimension);
    ClassDB::bind_method(D_METHOD("set_hamiltonian", "H_packed"),
                         &QuantumEvolutionEngine::set_hamiltonian);
    ClassDB::bind_method(D_METHOD("add_lindblad_triplets", "triplets"),
                         &QuantumEvolutionEngine::add_lindblad_triplets);
    ClassDB::bind_method(D_METHOD("clear_operators"),
                         &QuantumEvolutionEngine::clear_operators);
    ClassDB::bind_method(D_METHOD("finalize"),
                         &QuantumEvolutionEngine::finalize);

    ClassDB::bind_method(D_METHOD("get_dimension"),
                         &QuantumEvolutionEngine::get_dimension);
    ClassDB::bind_method(D_METHOD("get_lindblad_count"),
                         &QuantumEvolutionEngine::get_lindblad_count);
    ClassDB::bind_method(D_METHOD("is_finalized"),
                         &QuantumEvolutionEngine::is_finalized);

    ClassDB::bind_method(D_METHOD("evolve_step", "rho_data", "dt"),
                         &QuantumEvolutionEngine::evolve_step);
    ClassDB::bind_method(D_METHOD("evolve", "rho_data", "dt", "max_dt"),
                         &QuantumEvolutionEngine::evolve);

    // MI computation methods
    ClassDB::bind_method(D_METHOD("compute_all_mutual_information", "rho_data", "num_qubits"),
                         &QuantumEvolutionEngine::compute_all_mutual_information);
    ClassDB::bind_method(D_METHOD("evolve_with_mi", "rho_data", "dt", "max_dt", "num_qubits"),
                         &QuantumEvolutionEngine::evolve_with_mi);
}

QuantumEvolutionEngine::QuantumEvolutionEngine()
    : m_dim(0), m_finalized(false), m_has_hamiltonian(false) {}

QuantumEvolutionEngine::~QuantumEvolutionEngine() {}

void QuantumEvolutionEngine::set_dimension(int dim) {
    m_dim = dim;
    m_finalized = false;
}

void QuantumEvolutionEngine::set_hamiltonian(const PackedFloat64Array& H_packed) {
    if (m_dim == 0) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: set_dimension first!");
        return;
    }

    m_hamiltonian = unpack_dense(H_packed);
    m_has_hamiltonian = true;
    m_finalized = false;
}

void QuantumEvolutionEngine::add_lindblad_triplets(const PackedFloat64Array& triplets) {
    if (m_dim == 0) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: set_dimension first!");
        return;
    }

    // Parse triplets: [row0, col0, re0, im0, row1, col1, re1, im1, ...]
    int num_entries = triplets.size() / 4;
    std::vector<Eigen::Triplet<std::complex<double>>> eigen_triplets;
    eigen_triplets.reserve(num_entries);

    const double* ptr = triplets.ptr();
    for (int i = 0; i < num_entries; i++) {
        int row = static_cast<int>(ptr[i * 4]);
        int col = static_cast<int>(ptr[i * 4 + 1]);
        double re = ptr[i * 4 + 2];
        double im = ptr[i * 4 + 3];

        if (std::abs(re) > 1e-15 || std::abs(im) > 1e-15) {
            eigen_triplets.emplace_back(row, col, std::complex<double>(re, im));
        }
    }

    Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> L(m_dim, m_dim);
    L.setFromTriplets(eigen_triplets.begin(), eigen_triplets.end());
    L.makeCompressed();

    m_lindblads.push_back(L);
    m_finalized = false;
}

void QuantumEvolutionEngine::clear_operators() {
    m_lindblads.clear();
    m_lindblad_dags.clear();
    m_LdagLs.clear();
    m_hamiltonian.resize(0, 0);
    m_has_hamiltonian = false;
    m_finalized = false;
}

void QuantumEvolutionEngine::finalize() {
    // Precompute L†, L†L for each Lindblad operator
    m_lindblad_dags.clear();
    m_LdagLs.clear();

    m_lindblad_dags.reserve(m_lindblads.size());
    m_LdagLs.reserve(m_lindblads.size());

    for (const auto& L : m_lindblads) {
        // L† (adjoint)
        Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> L_dag = L.adjoint();
        m_lindblad_dags.push_back(L_dag);

        // L†L
        Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> LdagL = L_dag * L;
        LdagL.makeCompressed();
        m_LdagLs.push_back(LdagL);
    }

    m_finalized = true;
}

int QuantumEvolutionEngine::get_dimension() const {
    return m_dim;
}

int QuantumEvolutionEngine::get_lindblad_count() const {
    return static_cast<int>(m_lindblads.size());
}

bool QuantumEvolutionEngine::is_finalized() const {
    return m_finalized;
}

PackedFloat64Array QuantumEvolutionEngine::evolve_step(const PackedFloat64Array& rho_data, float dt) {
    if (!m_finalized) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: call finalize() first!");
        return rho_data;  // Return unchanged
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    Eigen::MatrixXcd drho = Eigen::MatrixXcd::Zero(m_dim, m_dim);

    // =========================================================================
    // Term 1: Hamiltonian evolution -i[H, ρ]
    // =========================================================================
    if (m_has_hamiltonian) {
        // [H, ρ] = Hρ - ρH
        Eigen::MatrixXcd commutator = m_hamiltonian * rho - rho * m_hamiltonian;
        drho += std::complex<double>(0.0, -1.0) * commutator;
    }

    // =========================================================================
    // Term 2: Lindblad dissipation Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})
    // =========================================================================
    for (size_t k = 0; k < m_lindblads.size(); k++) {
        const auto& L = m_lindblads[k];
        const auto& L_dag = m_lindblad_dags[k];
        const auto& LdagL = m_LdagLs[k];

        // L ρ L† (sparse × dense × sparse)
        Eigen::MatrixXcd L_rho = L * rho;           // Sparse × Dense
        Eigen::MatrixXcd L_rho_Ldag = L_rho * L_dag; // Dense × Sparse

        // {L†L, ρ} = L†L ρ + ρ L†L (anticommutator with sparse L†L)
        Eigen::MatrixXcd LdagL_rho = LdagL * rho;   // Sparse × Dense
        Eigen::MatrixXcd rho_LdagL = rho * LdagL;   // Dense × Sparse

        // Dissipator: L ρ L† - 0.5 * (L†L ρ + ρ L†L)
        drho += L_rho_Ldag - 0.5 * (LdagL_rho + rho_LdagL);
    }

    // =========================================================================
    // Euler integration: ρ(t+dt) = ρ(t) + dt * dρ/dt
    // =========================================================================
    rho += static_cast<double>(dt) * drho;

    return pack_dense(rho);
}

PackedFloat64Array QuantumEvolutionEngine::evolve(const PackedFloat64Array& rho_data, float dt, float max_dt) {
    if (!m_finalized) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: call finalize() first!");
        return rho_data;
    }

    // Subcycling for numerical stability
    if (dt <= max_dt) {
        return evolve_step(rho_data, dt);
    }

    // Multiple steps needed
    int num_steps = static_cast<int>(std::ceil(dt / max_dt));
    float sub_dt = dt / num_steps;

    // Unpack once, evolve multiple times, pack once
    Eigen::MatrixXcd rho = unpack_dense(rho_data);

    for (int step = 0; step < num_steps; step++) {
        Eigen::MatrixXcd drho = Eigen::MatrixXcd::Zero(m_dim, m_dim);

        // Term 1: Hamiltonian
        if (m_has_hamiltonian) {
            Eigen::MatrixXcd commutator = m_hamiltonian * rho - rho * m_hamiltonian;
            drho += std::complex<double>(0.0, -1.0) * commutator;
        }

        // Term 2: Lindblad
        for (size_t k = 0; k < m_lindblads.size(); k++) {
            const auto& L = m_lindblads[k];
            const auto& L_dag = m_lindblad_dags[k];
            const auto& LdagL = m_LdagLs[k];

            Eigen::MatrixXcd L_rho_Ldag = (L * rho) * L_dag;
            Eigen::MatrixXcd anticomm = LdagL * rho + rho * LdagL;
            drho += L_rho_Ldag - 0.5 * anticomm;
        }

        // Euler step
        rho += static_cast<double>(sub_dt) * drho;
    }

    return pack_dense(rho);
}

Eigen::MatrixXcd QuantumEvolutionEngine::unpack_dense(const PackedFloat64Array& data) const {
    Eigen::MatrixXcd mat(m_dim, m_dim);
    const double* ptr = data.ptr();

    for (int i = 0; i < m_dim; i++) {
        for (int j = 0; j < m_dim; j++) {
            int idx = (i * m_dim + j) * 2;
            mat(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }
    return mat;
}

PackedFloat64Array QuantumEvolutionEngine::pack_dense(const Eigen::MatrixXcd& mat) const {
    PackedFloat64Array packed;
    packed.resize(m_dim * m_dim * 2);
    double* ptr = packed.ptrw();

    for (int i = 0; i < m_dim; i++) {
        for (int j = 0; j < m_dim; j++) {
            int idx = (i * m_dim + j) * 2;
            ptr[idx] = mat(i, j).real();
            ptr[idx + 1] = mat(i, j).imag();
        }
    }
    return packed;
}

// ============================================================================
// MUTUAL INFORMATION COMPUTATION
// ============================================================================

Eigen::MatrixXcd QuantumEvolutionEngine::partial_trace_single(
    const Eigen::MatrixXcd& rho, int qubit, int num_qubits) const {
    // Trace out all qubits except 'qubit', returning 2×2 reduced density matrix
    // Uses the formula: ρ_A = Tr_B(ρ) where B is the complement of qubit A

    int dim = 1 << num_qubits;
    Eigen::MatrixXcd reduced = Eigen::MatrixXcd::Zero(2, 2);

    // For each element (a, b) of the 2×2 reduced matrix (a, b ∈ {0, 1})
    for (int a = 0; a < 2; a++) {
        for (int b = 0; b < 2; b++) {
            std::complex<double> sum(0.0, 0.0);

            // Sum over all basis states where qubit has value a (row) and b (col)
            // and all other qubits have the same value (trace condition)
            for (int other_bits = 0; other_bits < (1 << (num_qubits - 1)); other_bits++) {
                // Construct full basis state index with qubit at position 'qubit'
                // Insert 'a' at position qubit for row, 'b' for column
                int row_idx = 0, col_idx = 0;
                int bit_pos = 0;
                for (int q = 0; q < num_qubits; q++) {
                    if (q == qubit) {
                        row_idx |= (a << q);
                        col_idx |= (b << q);
                    } else {
                        int other_bit = (other_bits >> bit_pos) & 1;
                        row_idx |= (other_bit << q);
                        col_idx |= (other_bit << q);  // Same value for trace
                        bit_pos++;
                    }
                }
                sum += rho(row_idx, col_idx);
            }
            reduced(a, b) = sum;
        }
    }
    return reduced;
}

Eigen::MatrixXcd QuantumEvolutionEngine::partial_trace_complement(
    const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const {
    // Trace out all qubits except qubit_a and qubit_b, returning 4×4 reduced matrix
    // Basis order: |00⟩, |01⟩, |10⟩, |11⟩ where first digit is qubit_a, second is qubit_b

    int dim = 1 << num_qubits;
    Eigen::MatrixXcd reduced = Eigen::MatrixXcd::Zero(4, 4);

    // Ensure qubit_a < qubit_b for consistent ordering
    int q_lo = std::min(qubit_a, qubit_b);
    int q_hi = std::max(qubit_a, qubit_b);
    bool swapped = (qubit_a > qubit_b);

    // For each element of the 4×4 reduced matrix
    for (int row_ab = 0; row_ab < 4; row_ab++) {
        for (int col_ab = 0; col_ab < 4; col_ab++) {
            // Extract qubit values from 2-bit indices
            int a_row = swapped ? (row_ab & 1) : ((row_ab >> 1) & 1);
            int b_row = swapped ? ((row_ab >> 1) & 1) : (row_ab & 1);
            int a_col = swapped ? (col_ab & 1) : ((col_ab >> 1) & 1);
            int b_col = swapped ? ((col_ab >> 1) & 1) : (col_ab & 1);

            std::complex<double> sum(0.0, 0.0);

            // Sum over all other qubits (trace condition: same value in row and col)
            int other_qubits = num_qubits - 2;
            for (int other_bits = 0; other_bits < (1 << other_qubits); other_bits++) {
                int row_idx = 0, col_idx = 0;
                int bit_pos = 0;

                for (int q = 0; q < num_qubits; q++) {
                    if (q == qubit_a) {
                        row_idx |= (a_row << q);
                        col_idx |= (a_col << q);
                    } else if (q == qubit_b) {
                        row_idx |= (b_row << q);
                        col_idx |= (b_col << q);
                    } else {
                        int other_bit = (other_bits >> bit_pos) & 1;
                        row_idx |= (other_bit << q);
                        col_idx |= (other_bit << q);  // Same for trace
                        bit_pos++;
                    }
                }
                sum += rho(row_idx, col_idx);
            }
            reduced(row_ab, col_ab) = sum;
        }
    }
    return reduced;
}

double QuantumEvolutionEngine::von_neumann_entropy(const Eigen::MatrixXcd& reduced_rho) const {
    // S(ρ) = -Tr(ρ log ρ) = -Σ λ_i log λ_i (in bits)
    // Use eigenvalue decomposition

    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(reduced_rho);
    Eigen::VectorXd eigenvalues = solver.eigenvalues().real();

    double entropy = 0.0;
    const double eps = 1e-15;
    const double log2_e = 1.0 / std::log(2.0);  // Convert nats to bits

    for (int i = 0; i < eigenvalues.size(); i++) {
        double lambda = eigenvalues(i);
        if (lambda > eps) {
            entropy -= lambda * std::log(lambda) * log2_e;
        }
    }

    return std::max(entropy, 0.0);  // Ensure non-negative due to numerical errors
}

double QuantumEvolutionEngine::mutual_information(
    const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const {
    // I(A:B) = S(A) + S(B) - S(AB)

    Eigen::MatrixXcd rho_a = partial_trace_single(rho, qubit_a, num_qubits);
    Eigen::MatrixXcd rho_b = partial_trace_single(rho, qubit_b, num_qubits);
    Eigen::MatrixXcd rho_ab = partial_trace_complement(rho, qubit_a, qubit_b, num_qubits);

    double S_a = von_neumann_entropy(rho_a);
    double S_b = von_neumann_entropy(rho_b);
    double S_ab = von_neumann_entropy(rho_ab);

    // Subadditivity guarantees I(A:B) >= 0
    return std::max(S_a + S_b - S_ab, 0.0);
}

PackedFloat64Array QuantumEvolutionEngine::compute_all_mutual_information(
    const PackedFloat64Array& rho_data, int num_qubits) {
    // Compute MI for all qubit pairs in upper triangular order
    // Returns: [mi_01, mi_02, ..., mi_0(n-1), mi_12, mi_13, ..., mi_(n-2)(n-1)]
    // Total: n*(n-1)/2 values

    int num_pairs = num_qubits * (num_qubits - 1) / 2;
    PackedFloat64Array mi_values;
    mi_values.resize(num_pairs);

    if (num_qubits < 2) {
        return mi_values;  // No pairs for 0 or 1 qubit
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    double* ptr = mi_values.ptrw();

    int idx = 0;
    for (int i = 0; i < num_qubits; i++) {
        for (int j = i + 1; j < num_qubits; j++) {
            ptr[idx] = mutual_information(rho, i, j, num_qubits);
            idx++;
        }
    }

    return mi_values;
}

Dictionary QuantumEvolutionEngine::evolve_with_mi(
    const PackedFloat64Array& rho_data, float dt, float max_dt, int num_qubits) {
    // Combined evolution + MI computation in single call
    // Avoids multiple GDScript ↔ C++ round trips

    Dictionary result;

    // Evolve the state
    PackedFloat64Array evolved_rho = evolve(rho_data, dt, max_dt);
    result["rho"] = evolved_rho;

    // Compute MI on the evolved state
    PackedFloat64Array mi_values = compute_all_mutual_information(evolved_rho, num_qubits);
    result["mi"] = mi_values;

    return result;
}
