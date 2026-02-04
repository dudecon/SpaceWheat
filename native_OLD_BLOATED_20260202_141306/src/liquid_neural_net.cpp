#include "liquid_neural_net.h"
#include <iostream>

LiquidNeuralNet::LiquidNeuralNet(int in_size, int hidden, int out_size)
    : input_size(in_size),
      hidden_size(hidden),
      output_size(out_size),
      W_in(in_size, hidden),
      W_rec(hidden, hidden),
      W_out(hidden, out_size),
      b_hidden(hidden),
      b_out(out_size),
      hidden_state(hidden),
      tau(0.1),
      leak(0.3),
      learning_rate(0.001),
      l2_reg(0.0001),
      rng(std::random_device{}()) {
    initialize_weights();
    reset_state();
}

void LiquidNeuralNet::initialize_weights() {
    std::uniform_real_distribution<double> dist(-1.0, 1.0);

    // Xavier initialization
    double scale_in = std::sqrt(1.0 / std::max(1, input_size));
    for (int i = 0; i < input_size; ++i) {
        for (int h = 0; h < hidden_size; ++h) {
            W_in(i, h) = scale_in * dist(rng);
        }
    }

    double scale_rec = std::sqrt(1.0 / std::max(1, hidden_size)) * 0.1;  // Scaled down for stability
    for (int h = 0; h < hidden_size; ++h) {
        for (int j = 0; j < hidden_size; ++j) {
            W_rec(h, j) = scale_rec * dist(rng);
        }
    }

    double scale_out = std::sqrt(1.0 / std::max(1, hidden_size));
    for (int h = 0; h < hidden_size; ++h) {
        for (int o = 0; o < output_size; ++o) {
            W_out(h, o) = scale_out * dist(rng);
        }
    }

    // Biases to zero
    b_hidden.setZero();
    b_out.setZero();
}

void LiquidNeuralNet::reset_state() {
    std::uniform_real_distribution<double> dist(-0.1, 0.1);
    for (int i = 0; i < hidden_size; ++i) {
        hidden_state(i) = dist(rng);
    }
}

std::vector<double> LiquidNeuralNet::forward(const std::vector<double>& input_phase) {
    if ((int)input_phase.size() != input_size) {
        std::cerr << "LNN forward: input size mismatch (" << input_phase.size()
                  << " vs " << input_size << ")" << std::endl;
        return std::vector<double>(output_size, 0.0);
    }

    // Convert input to Eigen vector
    VectorXd x_in = VectorXd::Map(const_cast<double*>(input_phase.data()), input_size);

    // x_in = W_in @ input
    x_in = W_in.transpose() * x_in + b_hidden;

    // x_rec = W_rec @ h_prev
    VectorXd x_rec = W_rec.transpose() * hidden_state;

    // Update hidden state: h_new = (1 - leak) * h_old + leak * tanh(x_in + x_rec)
    VectorXd activation_in = x_in + x_rec;
    for (int h = 0; h < hidden_size; ++h) {
        double act = activation(activation_in(h));
        hidden_state(h) = (1.0 - leak) * hidden_state(h) + leak * act;
    }

    // Compute output: y = W_out @ h_new + b_out
    VectorXd output_vec = W_out.transpose() * hidden_state + b_out;

    // Convert to std::vector
    std::vector<double> output(output_size);
    for (int o = 0; o < output_size; ++o) {
        output[o] = output_vec(o);
    }

    return output;
}

double LiquidNeuralNet::train_batch(const std::vector<std::vector<double>>& target_trajectory) {
    if (target_trajectory.empty()) {
        return 0.0;
    }

    double total_loss = 0.0;

    // Initialize gradients
    MatrixXd grad_W_in = MatrixXd::Zero(input_size, hidden_size);
    MatrixXd grad_W_rec = MatrixXd::Zero(hidden_size, hidden_size);
    MatrixXd grad_W_out = MatrixXd::Zero(hidden_size, output_size);
    VectorXd grad_b_hidden = VectorXd::Zero(hidden_size);
    VectorXd grad_b_out = VectorXd::Zero(output_size);

    // Reset state for trajectory
    reset_state();

    // Forward pass through trajectory
    std::vector<VectorXd> hidden_states;
    std::vector<VectorXd> outputs;
    hidden_states.push_back(hidden_state);

    for (const auto& target : target_trajectory) {
        // Forward through one step (simplified - just compute output error)
        VectorXd output_vec = W_out.transpose() * hidden_state + b_out;
        outputs.push_back(output_vec);

        // Compute error
        VectorXd error = output_vec - VectorXd::Map(const_cast<double*>(target.data()), output_size);
        for (int o = 0; o < output_size; ++o) {
            total_loss += error(o) * error(o);
        }

        // Gradient for output layer: grad_W_out += error @ h^T
        grad_W_out += hidden_state * error.transpose();
        grad_b_out += error;

        // Simple hidden state update (would need full BPTT for proper training)
        VectorXd x_in = VectorXd::Zero(hidden_size);
        VectorXd x_rec = W_rec.transpose() * hidden_state;
        for (int h = 0; h < hidden_size; ++h) {
            double act = activation(x_in(h) + x_rec(h));
            hidden_state(h) = (1.0 - leak) * hidden_state(h) + leak * act;
        }
        hidden_states.push_back(hidden_state);
    }

    // Apply gradients with learning rate and L2 regularization
    for (int i = 0; i < input_size; ++i) {
        for (int h = 0; h < hidden_size; ++h) {
            W_in(i, h) -= learning_rate * (grad_W_in(i, h) + l2_reg * W_in(i, h));
        }
    }

    for (int h = 0; h < hidden_size; ++h) {
        for (int o = 0; o < output_size; ++o) {
            W_out(h, o) -= learning_rate * (grad_W_out(h, o) + l2_reg * W_out(h, o));
        }
    }

    for (int o = 0; o < output_size; ++o) {
        b_out(o) -= learning_rate * grad_b_out(o);
    }

    return total_loss;
}

void LiquidNeuralNet::set_learning_rate(double lr) {
    learning_rate = std::max(0.0001, std::min(0.1, lr));
}

void LiquidNeuralNet::set_leak(double new_leak) {
    leak = std::max(0.0, std::min(1.0, new_leak));
}

void LiquidNeuralNet::set_tau(double new_tau) {
    tau = std::max(0.01, std::min(1.0, new_tau));
}

std::vector<double> LiquidNeuralNet::get_hidden_state() const {
    std::vector<double> state(hidden_size);
    for (int i = 0; i < hidden_size; ++i) {
        state[i] = hidden_state(i);
    }
    return state;
}
