#ifndef QUANTUM_MATRIX_NATIVE_H
#define QUANTUM_MATRIX_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <Eigen/Dense>
#include <complex>

namespace godot {

class QuantumMatrixNative : public RefCounted {
    GDCLASS(QuantumMatrixNative, RefCounted)

private:
    Eigen::MatrixXcd m_matrix;
    int m_dim;

    // Helper to pack matrix to array
    PackedFloat64Array pack_matrix(const Eigen::MatrixXcd& mat, int dim) const;

protected:
    static void _bind_methods();

public:
    QuantumMatrixNative();
    ~QuantumMatrixNative();

    // Load/store from GDScript
    void from_packed(const PackedFloat64Array& data, int dim);
    PackedFloat64Array to_packed() const;
    int get_dimension() const;

    // Core matrix operations
    PackedFloat64Array mul(const PackedFloat64Array& other, int dim) const;
    PackedFloat64Array expm() const;
    PackedFloat64Array inverse() const;
    Dictionary eigensystem() const;

    // Additional operations
    PackedFloat64Array add(const PackedFloat64Array& other, int dim) const;
    PackedFloat64Array sub(const PackedFloat64Array& other, int dim) const;
    PackedFloat64Array scale(double re, double im) const;
    PackedFloat64Array dagger() const;
    PackedFloat64Array commutator(const PackedFloat64Array& other, int dim) const;

    // Utilities
    double trace_real() const;
    double trace_imag() const;
    bool is_hermitian(double tolerance) const;

    // Sparse matrix support (CSR format)
    void from_packed_csr(const Dictionary& csr_data);
    Dictionary to_packed_csr(double threshold) const;
    double get_sparsity_ratio(double threshold) const;
    int count_nonzeros(double threshold) const;
};

}

#endif
