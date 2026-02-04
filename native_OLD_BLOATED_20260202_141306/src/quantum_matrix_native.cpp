#include "quantum_matrix_native.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <Eigen/Eigenvalues>
#include <unsupported/Eigen/MatrixFunctions>
#include <complex>
#include <cmath>

using namespace godot;

void QuantumMatrixNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("from_packed", "data", "dim"), &QuantumMatrixNative::from_packed);
    ClassDB::bind_method(D_METHOD("to_packed"), &QuantumMatrixNative::to_packed);
    ClassDB::bind_method(D_METHOD("get_dimension"), &QuantumMatrixNative::get_dimension);

    ClassDB::bind_method(D_METHOD("mul", "other", "dim"), &QuantumMatrixNative::mul);
    ClassDB::bind_method(D_METHOD("expm"), &QuantumMatrixNative::expm);
    ClassDB::bind_method(D_METHOD("inverse"), &QuantumMatrixNative::inverse);
    ClassDB::bind_method(D_METHOD("eigensystem"), &QuantumMatrixNative::eigensystem);

    ClassDB::bind_method(D_METHOD("add", "other", "dim"), &QuantumMatrixNative::add);
    ClassDB::bind_method(D_METHOD("sub", "other", "dim"), &QuantumMatrixNative::sub);
    ClassDB::bind_method(D_METHOD("scale", "re", "im"), &QuantumMatrixNative::scale);
    ClassDB::bind_method(D_METHOD("dagger"), &QuantumMatrixNative::dagger);
    ClassDB::bind_method(D_METHOD("commutator", "other", "dim"), &QuantumMatrixNative::commutator);

    ClassDB::bind_method(D_METHOD("trace_real"), &QuantumMatrixNative::trace_real);
    ClassDB::bind_method(D_METHOD("trace_imag"), &QuantumMatrixNative::trace_imag);
    ClassDB::bind_method(D_METHOD("is_hermitian", "tolerance"), &QuantumMatrixNative::is_hermitian);

    // Sparse matrix support
    ClassDB::bind_method(D_METHOD("from_packed_csr", "csr_data"), &QuantumMatrixNative::from_packed_csr);
    ClassDB::bind_method(D_METHOD("to_packed_csr", "threshold"), &QuantumMatrixNative::to_packed_csr);
    ClassDB::bind_method(D_METHOD("get_sparsity_ratio", "threshold"), &QuantumMatrixNative::get_sparsity_ratio);
    ClassDB::bind_method(D_METHOD("count_nonzeros", "threshold"), &QuantumMatrixNative::count_nonzeros);
}

QuantumMatrixNative::QuantumMatrixNative() : m_dim(0) {}
QuantumMatrixNative::~QuantumMatrixNative() {}

PackedFloat64Array QuantumMatrixNative::pack_matrix(const Eigen::MatrixXcd& mat, int dim) const {
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

void QuantumMatrixNative::from_packed(const PackedFloat64Array& data, int dim) {
    m_dim = dim;
    m_matrix.resize(dim, dim);

    const double* ptr = data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            m_matrix(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }
}

PackedFloat64Array QuantumMatrixNative::to_packed() const {
    return pack_matrix(m_matrix, m_dim);
}

int QuantumMatrixNative::get_dimension() const {
    return m_dim;
}

PackedFloat64Array QuantumMatrixNative::mul(const PackedFloat64Array& other_data, int dim) const {
    // Unpack other matrix
    Eigen::MatrixXcd other(dim, dim);
    const double* ptr = other_data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            other(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }

    // Eigen matrix multiplication (SIMD optimized)
    Eigen::MatrixXcd result = m_matrix * other;

    return pack_matrix(result, dim);
}

PackedFloat64Array QuantumMatrixNative::expm() const {
    // Matrix exponential using Eigen's unsupported module
    // Uses Pade approximation with scaling-squaring internally
    Eigen::MatrixXcd result = m_matrix.exp();
    return pack_matrix(result, m_dim);
}

PackedFloat64Array QuantumMatrixNative::inverse() const {
    // LU decomposition based inverse
    Eigen::MatrixXcd result = m_matrix.inverse();
    return pack_matrix(result, m_dim);
}

Dictionary QuantumMatrixNative::eigensystem() const {
    // Use SelfAdjointEigenSolver for Hermitian matrices (faster and more stable)
    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(m_matrix);

    // Eigenvalues (real for Hermitian)
    Array eigenvalues;
    for (int i = 0; i < m_dim; i++) {
        eigenvalues.push_back(solver.eigenvalues()(i));
    }

    // Eigenvectors as packed array
    PackedFloat64Array packed_vecs = pack_matrix(solver.eigenvectors(), m_dim);

    Dictionary result;
    result["eigenvalues"] = eigenvalues;
    result["eigenvectors"] = packed_vecs;
    return result;
}

PackedFloat64Array QuantumMatrixNative::add(const PackedFloat64Array& other_data, int dim) const {
    Eigen::MatrixXcd other(dim, dim);
    const double* ptr = other_data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            other(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }

    Eigen::MatrixXcd result = m_matrix + other;
    return pack_matrix(result, dim);
}

PackedFloat64Array QuantumMatrixNative::sub(const PackedFloat64Array& other_data, int dim) const {
    Eigen::MatrixXcd other(dim, dim);
    const double* ptr = other_data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            other(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }

    Eigen::MatrixXcd result = m_matrix - other;
    return pack_matrix(result, dim);
}

PackedFloat64Array QuantumMatrixNative::scale(double re, double im) const {
    std::complex<double> scalar(re, im);
    Eigen::MatrixXcd result = m_matrix * scalar;
    return pack_matrix(result, m_dim);
}

PackedFloat64Array QuantumMatrixNative::dagger() const {
    Eigen::MatrixXcd result = m_matrix.adjoint();
    return pack_matrix(result, m_dim);
}

PackedFloat64Array QuantumMatrixNative::commutator(const PackedFloat64Array& other_data, int dim) const {
    Eigen::MatrixXcd other(dim, dim);
    const double* ptr = other_data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            other(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }

    // [A, B] = AB - BA
    Eigen::MatrixXcd result = m_matrix * other - other * m_matrix;
    return pack_matrix(result, dim);
}

double QuantumMatrixNative::trace_real() const {
    return m_matrix.trace().real();
}

double QuantumMatrixNative::trace_imag() const {
    return m_matrix.trace().imag();
}

bool QuantumMatrixNative::is_hermitian(double tolerance) const {
    return (m_matrix - m_matrix.adjoint()).norm() < tolerance;
}

// Sparse matrix support (CSR format)

void QuantumMatrixNative::from_packed_csr(const Dictionary& csr_data) {
    // Extract CSR components from Dictionary
    int dim = csr_data["dim"];
    int nnz = csr_data["nnz"];
    PackedInt32Array row_ptr = csr_data["row_ptr"];
    PackedInt32Array col_idx = csr_data["col_idx"];
    PackedFloat64Array values_real = csr_data["values_real"];
    PackedFloat64Array values_imag = csr_data["values_imag"];

    // Initialize matrix with zeros
    m_dim = dim;
    m_matrix = Eigen::MatrixXcd::Zero(dim, dim);

    // Fill from CSR data
    const int32_t* row_ptr_data = row_ptr.ptr();
    const int32_t* col_idx_data = col_idx.ptr();
    const double* real_data = values_real.ptr();
    const double* imag_data = values_imag.ptr();

    for (int i = 0; i < dim; i++) {
        int row_start = row_ptr_data[i];
        int row_end = row_ptr_data[i + 1];
        for (int k = row_start; k < row_end; k++) {
            int j = col_idx_data[k];
            m_matrix(i, j) = std::complex<double>(real_data[k], imag_data[k]);
        }
    }
}

Dictionary QuantumMatrixNative::to_packed_csr(double threshold) const {
    // Count non-zeros first
    int nnz = 0;
    for (int i = 0; i < m_dim; i++) {
        for (int j = 0; j < m_dim; j++) {
            if (std::abs(m_matrix(i, j)) > threshold) {
                nnz++;
            }
        }
    }

    // Allocate arrays
    PackedInt32Array row_ptr;
    PackedInt32Array col_idx;
    PackedFloat64Array values_real;
    PackedFloat64Array values_imag;

    row_ptr.resize(m_dim + 1);
    col_idx.resize(nnz);
    values_real.resize(nnz);
    values_imag.resize(nnz);

    int32_t* row_ptr_data = row_ptr.ptrw();
    int32_t* col_idx_data = col_idx.ptrw();
    double* real_data = values_real.ptrw();
    double* imag_data = values_imag.ptrw();

    // Fill CSR arrays
    int current_nnz = 0;
    for (int i = 0; i < m_dim; i++) {
        row_ptr_data[i] = current_nnz;
        for (int j = 0; j < m_dim; j++) {
            if (std::abs(m_matrix(i, j)) > threshold) {
                col_idx_data[current_nnz] = j;
                real_data[current_nnz] = m_matrix(i, j).real();
                imag_data[current_nnz] = m_matrix(i, j).imag();
                current_nnz++;
            }
        }
    }
    row_ptr_data[m_dim] = current_nnz;

    // Build result dictionary
    Dictionary result;
    result["format"] = "csr";
    result["dim"] = m_dim;
    result["nnz"] = nnz;
    result["row_ptr"] = row_ptr;
    result["col_idx"] = col_idx;
    result["values_real"] = values_real;
    result["values_imag"] = values_imag;
    return result;
}

double QuantumMatrixNative::get_sparsity_ratio(double threshold) const {
    int nnz = count_nonzeros(threshold);
    int total = m_dim * m_dim;
    return total > 0 ? (double)nnz / (double)total : 0.0;
}

int QuantumMatrixNative::count_nonzeros(double threshold) const {
    int count = 0;
    for (int i = 0; i < m_dim; i++) {
        for (int j = 0; j < m_dim; j++) {
            if (std::abs(m_matrix(i, j)) > threshold) {
                count++;
            }
        }
    }
    return count;
}
