#include "quantum_sparse_native.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <vector>
#include <cmath>

using namespace godot;

void QuantumSparseMatrixNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("from_triplets", "triplets", "dim"),
                         &QuantumSparseMatrixNative::from_triplets);
    ClassDB::bind_method(D_METHOD("from_dense", "data", "dim", "threshold"),
                         &QuantumSparseMatrixNative::from_dense);

    ClassDB::bind_method(D_METHOD("get_dimension"), &QuantumSparseMatrixNative::get_dimension);
    ClassDB::bind_method(D_METHOD("get_nnz"), &QuantumSparseMatrixNative::get_nnz);
    ClassDB::bind_method(D_METHOD("get_sparsity"), &QuantumSparseMatrixNative::get_sparsity);

    ClassDB::bind_method(D_METHOD("mul_dense", "dense", "dim"),
                         &QuantumSparseMatrixNative::mul_dense);
    ClassDB::bind_method(D_METHOD("dense_mul", "dense", "dim"),
                         &QuantumSparseMatrixNative::dense_mul);
    ClassDB::bind_method(D_METHOD("dagger"), &QuantumSparseMatrixNative::dagger);
    ClassDB::bind_method(D_METHOD("commutator_with_dense", "dense", "dim"),
                         &QuantumSparseMatrixNative::commutator_with_dense);
    ClassDB::bind_method(D_METHOD("lindblad_dissipator", "rho", "dim"),
                         &QuantumSparseMatrixNative::lindblad_dissipator);
    ClassDB::bind_method(D_METHOD("add_sparse", "other_triplets", "other_dim"),
                         &QuantumSparseMatrixNative::add_sparse);
    ClassDB::bind_method(D_METHOD("scale", "re", "im"),
                         &QuantumSparseMatrixNative::scale);
}

QuantumSparseMatrixNative::QuantumSparseMatrixNative() : m_dim(0) {}
QuantumSparseMatrixNative::~QuantumSparseMatrixNative() {}

PackedFloat64Array QuantumSparseMatrixNative::pack_dense(const Eigen::MatrixXcd& mat, int dim) const {
    PackedFloat64Array packed;
    packed.resize(dim * dim * 2);
    double* ptr = packed.ptrw();

    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            ptr[idx] = mat(i, j).real();
            ptr[idx + 1] = mat(i, j).imag();
        }
    }
    return packed;
}

Eigen::MatrixXcd QuantumSparseMatrixNative::unpack_dense(const PackedFloat64Array& data, int dim) const {
    Eigen::MatrixXcd mat(dim, dim);
    const double* ptr = data.ptr();

    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            mat(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }
    return mat;
}

void QuantumSparseMatrixNative::from_triplets(const PackedFloat64Array& triplets, int dim) {
    m_dim = dim;

    // Triplet format: [row0, col0, re0, im0, row1, col1, re1, im1, ...]
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

    m_sparse.resize(dim, dim);
    m_sparse.setFromTriplets(eigen_triplets.begin(), eigen_triplets.end());
    m_sparse.makeCompressed();
}

void QuantumSparseMatrixNative::from_dense(const PackedFloat64Array& data, int dim, double threshold) {
    m_dim = dim;

    std::vector<Eigen::Triplet<std::complex<double>>> triplets;
    triplets.reserve(dim * dim / 10);  // Assume ~90% sparse initially

    const double* ptr = data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            double re = ptr[idx];
            double im = ptr[idx + 1];

            if (std::abs(re) > threshold || std::abs(im) > threshold) {
                triplets.emplace_back(i, j, std::complex<double>(re, im));
            }
        }
    }

    m_sparse.resize(dim, dim);
    m_sparse.setFromTriplets(triplets.begin(), triplets.end());
    m_sparse.makeCompressed();
}

int QuantumSparseMatrixNative::get_dimension() const {
    return m_dim;
}

int QuantumSparseMatrixNative::get_nnz() const {
    return m_sparse.nonZeros();
}

double QuantumSparseMatrixNative::get_sparsity() const {
    if (m_dim == 0) return 1.0;
    int total = m_dim * m_dim;
    return 1.0 - (static_cast<double>(m_sparse.nonZeros()) / total);
}

PackedFloat64Array QuantumSparseMatrixNative::mul_dense(const PackedFloat64Array& dense, int dim) const {
    // Sparse × Dense: A * B where A is sparse, B is dense
    // This is O(nnz × dim) instead of O(dim³)

    Eigen::MatrixXcd B = unpack_dense(dense, dim);

    // Eigen handles sparse × dense efficiently
    Eigen::MatrixXcd result = m_sparse * B;

    return pack_dense(result, dim);
}

PackedFloat64Array QuantumSparseMatrixNative::dense_mul(const PackedFloat64Array& dense, int dim) const {
    // Dense × Sparse: B * A where A is sparse, B is dense
    // Also O(nnz × dim)

    Eigen::MatrixXcd B = unpack_dense(dense, dim);

    // Eigen handles dense × sparse efficiently
    Eigen::MatrixXcd result = B * m_sparse;

    return pack_dense(result, dim);
}

PackedFloat64Array QuantumSparseMatrixNative::dagger() const {
    // Conjugate transpose of sparse matrix
    // Return as triplets for efficiency

    Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> result = m_sparse.adjoint();

    PackedFloat64Array triplets;
    triplets.resize(result.nonZeros() * 4);
    double* ptr = triplets.ptrw();

    int idx = 0;
    for (int k = 0; k < result.outerSize(); ++k) {
        for (Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>::InnerIterator it(result, k); it; ++it) {
            ptr[idx * 4] = it.row();
            ptr[idx * 4 + 1] = it.col();
            ptr[idx * 4 + 2] = it.value().real();
            ptr[idx * 4 + 3] = it.value().imag();
            idx++;
        }
    }

    return triplets;
}

PackedFloat64Array QuantumSparseMatrixNative::commutator_with_dense(const PackedFloat64Array& dense, int dim) const {
    // [A, ρ] = Aρ - ρA where A is sparse, ρ is dense
    // Two sparse-dense multiplications

    Eigen::MatrixXcd rho = unpack_dense(dense, dim);

    Eigen::MatrixXcd A_rho = m_sparse * rho;     // Sparse × Dense
    Eigen::MatrixXcd rho_A = rho * m_sparse;     // Dense × Sparse

    Eigen::MatrixXcd result = A_rho - rho_A;

    return pack_dense(result, dim);
}

PackedFloat64Array QuantumSparseMatrixNative::lindblad_dissipator(const PackedFloat64Array& rho_data, int dim) const {
    // Full Lindblad dissipator: L ρ L† - ½{L†L, ρ}
    //
    // This is the most expensive operation in quantum evolution.
    // Optimizations:
    // 1. Use sparse L for all multiplications
    // 2. Cache L†L (precompute once per L)
    // 3. Fuse operations where possible

    Eigen::MatrixXcd rho = unpack_dense(rho_data, dim);

    // L†
    Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> L_dag = m_sparse.adjoint();

    // Term 1: L ρ L†
    // First: L ρ (sparse × dense)
    Eigen::MatrixXcd L_rho = m_sparse * rho;
    // Then: (L ρ) L† (dense × sparse)
    Eigen::MatrixXcd L_rho_Ldag = L_rho * L_dag;

    // Term 2: L†L (sparse × sparse → sparse)
    Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> LdagL = L_dag * m_sparse;

    // {L†L, ρ} = L†L ρ + ρ L†L (anticommutator)
    // Both are sparse × dense
    Eigen::MatrixXcd LdagL_rho = LdagL * rho;  // Sparse × Dense
    Eigen::MatrixXcd rho_LdagL = rho * LdagL;  // Dense × Sparse

    // Full dissipator: L ρ L† - ½(L†L ρ + ρ L†L)
    Eigen::MatrixXcd result = L_rho_Ldag - 0.5 * (LdagL_rho + rho_LdagL);

    return pack_dense(result, dim);
}

PackedFloat64Array QuantumSparseMatrixNative::add_sparse(const PackedFloat64Array& other_triplets, int other_dim) const {
    // First, load other sparse matrix
    QuantumSparseMatrixNative other;
    other.from_triplets(other_triplets, other_dim);

    // Add sparse matrices
    Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> result = m_sparse + other.m_sparse;
    result.makeCompressed();

    // Pack as triplets
    PackedFloat64Array triplets;
    triplets.resize(result.nonZeros() * 4);
    double* ptr = triplets.ptrw();

    int idx = 0;
    for (int k = 0; k < result.outerSize(); ++k) {
        for (Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>::InnerIterator it(result, k); it; ++it) {
            ptr[idx * 4] = it.row();
            ptr[idx * 4 + 1] = it.col();
            ptr[idx * 4 + 2] = it.value().real();
            ptr[idx * 4 + 3] = it.value().imag();
            idx++;
        }
    }

    return triplets;
}

PackedFloat64Array QuantumSparseMatrixNative::scale(double re, double im) const {
    std::complex<double> scalar(re, im);

    Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> result = m_sparse * scalar;
    result.makeCompressed();

    // Pack as triplets
    PackedFloat64Array triplets;
    triplets.resize(result.nonZeros() * 4);
    double* ptr = triplets.ptrw();

    int idx = 0;
    for (int k = 0; k < result.outerSize(); ++k) {
        for (Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>::InnerIterator it(result, k); it; ++it) {
            ptr[idx * 4] = it.row();
            ptr[idx * 4 + 1] = it.col();
            ptr[idx * 4 + 2] = it.value().real();
            ptr[idx * 4 + 3] = it.value().imag();
            idx++;
        }
    }

    return triplets;
}
