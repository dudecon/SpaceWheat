#ifndef LIQUID_NEURAL_NET_H
#define LIQUID_NEURAL_NET_H

#include <vector>
#include <cmath>
#include <random>
#include <algorithm>
#include <Eigen/Dense>

using Eigen::MatrixXd;
using Eigen::VectorXd;

class LiquidNeuralNet {
public:
    // Network dimensions
    int input_size;
    int hidden_size;
    int output_size;

    // Weights (stored as dense matrices for fast operations)
    MatrixXd W_in;      // input_size × hidden_size
    MatrixXd W_rec;     // hidden_size × hidden_size
    MatrixXd W_out;     // hidden_size × output_size
    VectorXd b_hidden;  // hidden_size
    VectorXd b_out;     // output_size

    // State
    VectorXd hidden_state;  // Current hidden activation

    // Liquid dynamics parameters
    double tau;    // Time constant (default 0.1)
    double leak;   // Leaky integration factor (default 0.3)

    // Learning parameters
    double learning_rate;  // Training step size
    double l2_reg;         // L2 regularization

    // Constructors
    LiquidNeuralNet(int in_size, int hidden, int out_size);
    ~LiquidNeuralNet() = default;

    // Forward pass: compute output given input phases
    // Returns output_size values (phase modulation signals)
    std::vector<double> forward(const std::vector<double>& input_phase);

    // Reset hidden state to small random values
    void reset_state();

    // Setter methods
    void set_learning_rate(double lr);
    void set_leak(double new_leak);
    void set_tau(double new_tau);

    // Get hidden state (for debugging/analysis)
    std::vector<double> get_hidden_state() const;

    // Training: simple gradient step on output error
    // target_trajectory: array of target output vectors
    // Returns total loss
    double train_batch(const std::vector<std::vector<double>>& target_trajectory);

private:
    // Xavier initialization helper
    void initialize_weights();

    // Activation function (tanh)
    static inline double activation(double x) {
        return std::tanh(x);
    }

    // Derivative of tanh
    static inline double activation_derivative(double x) {
        double t = std::tanh(x);
        return 1.0 - t * t;
    }

    // Random number generator
    std::mt19937 rng;
};

#endif // LIQUID_NEURAL_NET_H
