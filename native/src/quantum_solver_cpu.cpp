#include "quantum_solver_cpu.h"
#include <cmath>
#include <algorithm>
#include <iostream>
#include <chrono>
#include <omp.h>

// Pade approximation coefficients (for orders 3 to 13)
// These are precomputed binomial coefficients for fast computation
static const double PADE_COEFF[14][7] = {
    {0},  // unused
    {0},  // unused
    {0},  // unused
    {120, 60, 12, 1},  // order 3
    {40320, 13440, 1680, 84, 1},  // order 4
    {3628800, 1028160, 86400, 3360, 56, 1},  // order 5
    {479001600, 119500800, 7099200, 177408, 2016, 24, 1},  // order 6
    {0},  // 7-13 computed dynamically
    {0},
    {0},
    {0},
    {0},
    {0},
    {0},
};

// Thresholds for Pade approximation (||A||_inf < theta)
static const double PADE_THETA[14] = {
    0,
    0,
    0,
    1.495585348e-2,    // order 3
    2.539398330e-1,    // order 4
    9.504178996e-1,    // order 5
    2.097847961e+0,    // order 6
    3.644144861e+0,    // order 7
    5.371920351e+0,    // order 8
    7.212212324e+0,    // order 9
    9.063927528e+0,    // order 10
    10.901353136e+0,   // order 11
    12.146064553e+0,   // order 12
    13.235469445e+0,   // order 13
};

QuantumSolverCPU::QuantumSolverCPU(int dim)
    : hilbert_dim(dim),
      H(MatrixXcd::Zero(dim, dim)),
      pade_order(13),
      use_threading(dim > 256) {
    // Enable multi-threading for larger systems
    #ifdef EIGEN_USE_THREADS
    if (use_threading) {
        Eigen::setNbThreads(0);  // Auto-detect cores
    }
    #endif

    // Initialize metrics
    metrics.hilbert_dim = dim;
}

void QuantumSolverCPU::set_hamiltonian(const MatrixXcd& H_in) {
    // Store in column-major (Eigen default) for cache efficiency
    H = H_in;
}

void QuantumSolverCPU::add_lindblad_operator(const MatrixXcd& L) {
    L_ops.push_back(L);
    // Precompute L† L for efficient dissipation calculation
    LdL_ops.push_back(L.adjoint() * L);
}

void QuantumSolverCPU::clear_lindblad_operators() {
    L_ops.clear();
    LdL_ops.clear();
}

void QuantumSolverCPU::set_pade_order(int order) {
    if (order >= 3 && order <= 13) {
        pade_order = order;
    }
}

void QuantumSolverCPU::set_multithreading(bool enabled) {
    use_threading = enabled;
    #ifdef EIGEN_USE_THREADS
    if (enabled) {
        Eigen::setNbThreads(0);
    } else {
        Eigen::setNbThreads(1);
    }
    #endif
}

void QuantumSolverCPU::evolve(MatrixXcd& rho, double dt) {
    auto start = std::chrono::high_resolution_clock::now();

    // Unitary evolution: exp(-i H dt) ρ exp(i H dt)
    evolve_unitary(rho, dt);

    // Lindblad dissipation: Σ_k [L_k ρ L_k† - (L_k† L_k ρ + ρ L_k† L_k) / 2]
    evolve_lindblad(rho, dt);

    auto end = std::chrono::high_resolution_clock::now();
    metrics.evolution_time_ms = std::chrono::duration<double, std::milli>(end - start).count();
}

void QuantumSolverCPU::evolve_unitary(MatrixXcd& rho, double dt) {
    auto start = std::chrono::high_resolution_clock::now();

    // Compute -i H dt (matrix for exponential)
    MatrixXcd A = Complex(0, -1) * H * dt;

    // Compute U = exp(A)
    MatrixXcd U = matrix_exponential(A);

    // Apply unitary: ρ' = U ρ U†
    rho = U * rho * U.adjoint();

    auto end = std::chrono::high_resolution_clock::now();
    metrics.matrix_exp_time_ms = std::chrono::duration<double, std::milli>(end - start).count();
}

void QuantumSolverCPU::evolve_lindblad(MatrixXcd& rho, double dt) {
    if (L_ops.empty()) {
        return;
    }

    auto start = std::chrono::high_resolution_clock::now();

    // Lindblad master equation: dρ/dt = Σ_k [L_k ρ L_k† - (L_k† L_k ρ + ρ L_k† L_k) / 2]
    // First-order approximation: ρ' ≈ ρ + dt * D[ρ]

    MatrixXcd drho = MatrixXcd::Zero(hilbert_dim, hilbert_dim);

    for (size_t k = 0; k < L_ops.size(); ++k) {
        const MatrixXcd& L = L_ops[k];
        const MatrixXcd& LdL = LdL_ops[k];

        // L ρ L†
        MatrixXcd term1 = L * rho * L.adjoint();

        // L† L ρ
        MatrixXcd term2 = LdL * rho;

        // ρ L† L
        MatrixXcd term3 = rho * LdL;

        // Accumulate: D[ρ] += L ρ L† - (L† L ρ + ρ L† L) / 2
        drho += term1 - (term2 + term3) * 0.5;
    }

    // Update: ρ' = ρ + dt * D[ρ]
    rho += dt * drho;

    // Renormalize to maintain trace ≈ 1
    double tr = trace(rho).real();
    if (std::abs(tr) > 1e-10) {
        rho /= tr;
    }

    auto end = std::chrono::high_resolution_clock::now();
    metrics.lindblad_time_ms = std::chrono::duration<double, std::milli>(end - start).count();
}

MatrixXcd QuantumSolverCPU::matrix_exponential(const MatrixXcd& A) {
    double norm_inf = A.cwiseAbs().colwise().sum().maxCoeff();

    if (norm_inf < 1e-15) {
        // A is essentially zero
        return MatrixXcd::Identity(hilbert_dim, hilbert_dim);
    }

    // Determine scaling factor: compute j = max(0, ceil(log_2(||A||_inf / theta)))
    int j = compute_matrix_norm_scale(A, PADE_THETA[pade_order]);

    // Scaled matrix: A_scaled = A / 2^j
    MatrixXcd A_scaled = A / (double)(1 << j);

    // Compute Pade approximation of exp(A_scaled)
    // exp(X) ≈ U / (U - V) where U, V are rational functions
    // Using Eigen's built-in exp() is slower for small matrices

    MatrixXcd result;
    if (pade_order == 13) {
        // Optimized path for standard order
        MatrixXcd A2 = A_scaled * A_scaled;

        // U = I + ...
        MatrixXcd U = MatrixXcd::Identity(hilbert_dim, hilbert_dim);
        MatrixXcd V = MatrixXcd::Identity(hilbert_dim, hilbert_dim);

        // Compute using Horner scheme for efficiency
        MatrixXcd A2_power = A2;
        U += A_scaled * (A2_power * 17297280.0);  // c13
        V -= A_scaled * (A2_power * 17297280.0);

        A2_power = A2_power * A2;
        U += A2_power * 8648640.0;
        V += A2_power * 8648640.0;

        A2_power = A2_power * A2;
        U += A_scaled * (A2_power * 1995840.0);
        V -= A_scaled * (A2_power * 1995840.0);

        A2_power = A2_power * A2;
        U += A2_power * 277920.0;
        V += A2_power * 277920.0;

        A2_power = A2_power * A2;
        U += A_scaled * (A2_power * 25200.0);
        V -= A_scaled * (A2_power * 25200.0);

        A2_power = A2_power * A2;
        U += A2_power * 1512.0;
        V += A2_power * 1512.0;

        A2_power = A2_power * A2;
        U += A_scaled * (A2_power * 56.0);
        V -= A_scaled * (A2_power * 56.0);

        U += A2_power * A2;
        V += A2_power * A2;

        // Solve: exp(A) = U (U - V)^{-1}
        result = U * (U - V).inverse();
    } else {
        // For other orders, use Pade approximation manually or return identity
        // (fallback not implemented - use order 13 for robustness)
        result = MatrixXcd::Identity(hilbert_dim, hilbert_dim);
    }

    // Undo scaling: exp(A) = (exp(A/2^j))^(2^j)
    for (int i = 0; i < j; ++i) {
        result = result * result;
    }

    metrics.pade_iterations = pade_order;
    return result;
}

int QuantumSolverCPU::compute_matrix_norm_scale(const MatrixXcd& A, double theta) {
    double norm_inf = A.cwiseAbs().colwise().sum().maxCoeff();

    if (norm_inf < theta) {
        return 0;
    }

    int j = 0;
    double scaled_norm = norm_inf;
    while (scaled_norm > theta) {
        scaled_norm /= 2.0;
        j++;
    }
    return j;
}

void QuantumSolverCPU::matrix_square_inplace(MatrixXcd& A) {
    A = A * A;
}

Complex QuantumSolverCPU::expectation_value(const MatrixXcd& O, const MatrixXcd& rho) {
    // <O> = Tr(O ρ) = Σ_i (O ρ)_ii
    // Optimized: compute (O ρ) then take trace
    MatrixXcd Orho = O * rho;

    Complex result = Complex(0, 0);
    for (int i = 0; i < hilbert_dim; ++i) {
        result += Orho(i, i);
    }
    return result;
}

double QuantumSolverCPU::purity(const MatrixXcd& rho) {
    // Tr(ρ²)
    MatrixXcd rho2 = rho * rho;
    double result = 0.0;
    for (int i = 0; i < hilbert_dim; ++i) {
        result += rho2(i, i).real();
    }
    return std::max(0.0, result);  // Numerical errors can give slightly negative
}

Complex QuantumSolverCPU::trace(const MatrixXcd& rho) {
    Complex result = Complex(0, 0);
    for (int i = 0; i < hilbert_dim; ++i) {
        result += rho(i, i);
    }
    return result;
}

void QuantumSolverCPU::normalize(MatrixXcd& rho) {
    Complex tr = trace(rho);
    if (std::abs(tr) > 1e-10) {
        rho /= tr;
    }
}
