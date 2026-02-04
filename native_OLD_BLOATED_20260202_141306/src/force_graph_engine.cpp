#include "force_graph_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

ForceGraphEngine::ForceGraphEngine() {
}

ForceGraphEngine::~ForceGraphEngine() {
}

void ForceGraphEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("update_positions", "positions", "velocities", "bloch_packet", "mi_values", "biome_center", "dt", "frozen_mask"),
                         &ForceGraphEngine::update_positions);

    ClassDB::bind_method(D_METHOD("set_purity_radial_spring", "spring"), &ForceGraphEngine::set_purity_radial_spring);
    ClassDB::bind_method(D_METHOD("set_phase_angular_spring", "spring"), &ForceGraphEngine::set_phase_angular_spring);
    ClassDB::bind_method(D_METHOD("set_correlation_spring", "spring"), &ForceGraphEngine::set_correlation_spring);
    ClassDB::bind_method(D_METHOD("set_mi_spring", "spring"), &ForceGraphEngine::set_mi_spring);
    ClassDB::bind_method(D_METHOD("set_repulsion_strength", "strength"), &ForceGraphEngine::set_repulsion_strength);
    ClassDB::bind_method(D_METHOD("set_damping", "damping"), &ForceGraphEngine::set_damping);
    ClassDB::bind_method(D_METHOD("set_base_distance", "distance"), &ForceGraphEngine::set_base_distance);
    ClassDB::bind_method(D_METHOD("set_min_distance", "distance"), &ForceGraphEngine::set_min_distance);

    ClassDB::bind_method(D_METHOD("get_purity_radial_spring"), &ForceGraphEngine::get_purity_radial_spring);
    ClassDB::bind_method(D_METHOD("get_phase_angular_spring"), &ForceGraphEngine::get_phase_angular_spring);
    ClassDB::bind_method(D_METHOD("get_correlation_spring"), &ForceGraphEngine::get_correlation_spring);
    ClassDB::bind_method(D_METHOD("get_mi_spring"), &ForceGraphEngine::get_mi_spring);
    ClassDB::bind_method(D_METHOD("get_repulsion_strength"), &ForceGraphEngine::get_repulsion_strength);
    ClassDB::bind_method(D_METHOD("get_damping"), &ForceGraphEngine::get_damping);
    ClassDB::bind_method(D_METHOD("get_base_distance"), &ForceGraphEngine::get_base_distance);
    ClassDB::bind_method(D_METHOD("get_min_distance"), &ForceGraphEngine::get_min_distance);
}

void ForceGraphEngine::set_purity_radial_spring(float spring) { m_purity_radial_spring = spring; }
void ForceGraphEngine::set_phase_angular_spring(float spring) { m_phase_angular_spring = spring; }
void ForceGraphEngine::set_correlation_spring(float spring) { m_correlation_spring = spring; }
void ForceGraphEngine::set_mi_spring(float spring) { m_mi_spring = spring; }
void ForceGraphEngine::set_repulsion_strength(float strength) { m_repulsion_strength = strength; }
void ForceGraphEngine::set_damping(float damping) { m_damping = damping; }
void ForceGraphEngine::set_base_distance(float distance) { m_base_distance = distance; }
void ForceGraphEngine::set_min_distance(float distance) { m_min_distance = distance; }

Dictionary ForceGraphEngine::update_positions(
    const PackedVector2Array& positions,
    const PackedVector2Array& velocities,
    const PackedFloat64Array& bloch_packet,
    const PackedFloat64Array& mi_values,
    Vector2 biome_center,
    float dt,
    const PackedByteArray& frozen_mask
) {
    int num_nodes = positions.size();

    // Copy input arrays for modification
    PackedVector2Array new_positions = positions;
    PackedVector2Array new_velocities = velocities;

    // Ensure velocity array matches position array size
    if (new_velocities.size() != num_nodes) {
        new_velocities.resize(num_nodes);
    }

    // Calculate forces for each node
    for (int i = 0; i < num_nodes; i++) {
        // Skip frozen nodes
        if (frozen_mask.size() > i && frozen_mask[i] != 0) {
            continue;
        }

        Vector2 total_force = Vector2(0, 0);

        // 1. Purity radial force (pulls to radius based on purity)
        if (bloch_packet.size() >= (i + 1) * 8) {
            total_force += _calculate_purity_radial_force(i, new_positions[i], bloch_packet, biome_center);
        }

        // 2. Phase angular force (creates clustering by phase)
        if (bloch_packet.size() >= (i + 1) * 8) {
            total_force += _calculate_phase_angular_force(i, new_positions[i], bloch_packet, biome_center);
        }

        // 3. Correlation forces (MI-based springs)
        if (!mi_values.is_empty()) {
            total_force += _calculate_correlation_forces(i, new_positions[i], new_positions, mi_values, frozen_mask);
        }

        // 4. Repulsion forces (prevent overlap)
        total_force += _calculate_repulsion_forces(i, new_positions[i], new_positions, frozen_mask);

        // Apply forces via velocity Verlet integration
        new_velocities[i] += total_force * dt;
        new_velocities[i] *= m_damping;
        new_positions[i] += new_velocities[i] * dt;
    }

    // Return updated positions and velocities
    Dictionary result;
    result["positions"] = new_positions;
    result["velocities"] = new_velocities;
    return result;
}

Vector2 ForceGraphEngine::_calculate_purity_radial_force(
    int node_idx,
    Vector2 position,
    const PackedFloat64Array& bloch_packet,
    Vector2 biome_center
) {
    // Bloch packet: [p0, p1, x, y, z, r, theta, phi] per qubit (stride=8)
    int offset = node_idx * 8;
    if (offset + 7 >= bloch_packet.size()) {
        return Vector2(0, 0);
    }

    // Get purity from p0^2 + p1^2 (populations)
    double p0 = bloch_packet[offset];
    double p1 = bloch_packet[offset + 1];
    double purity = std::abs(p0 - p1);  // Purity ≈ |p0 - p1| for single qubit

    // Target radius: pure states (purity=1) → center, mixed (purity=0) → edge
    double target_radius = m_max_biome_radius * (1.0 - purity);

    // Current radius from biome center
    Vector2 delta = position - biome_center;
    double current_radius = delta.length();

    if (current_radius < 1e-6) {
        // At center, push outward if target > 0
        if (target_radius > 1.0) {
            return Vector2(1, 0) * m_purity_radial_spring * target_radius;
        }
        return Vector2(0, 0);
    }

    // Spring force: F = k * (target - current)
    double radial_error = target_radius - current_radius;
    Vector2 radial_direction = delta / current_radius;
    return radial_direction * (m_purity_radial_spring * radial_error);
}

Vector2 ForceGraphEngine::_calculate_phase_angular_force(
    int node_idx,
    Vector2 position,
    const PackedFloat64Array& bloch_packet,
    Vector2 biome_center
) {
    // Bloch packet: [p0, p1, x, y, z, r, theta, phi] per qubit
    int offset = node_idx * 8;
    if (offset + 7 >= bloch_packet.size()) {
        return Vector2(0, 0);
    }

    // Get theta (polar angle on Bloch sphere)
    double theta = bloch_packet[offset + 6];

    // Convert to angular position around biome center
    Vector2 delta = position - biome_center;
    double current_radius = delta.length();

    if (current_radius < 1e-6) {
        return Vector2(0, 0);
    }

    // Current angle
    double current_angle = std::atan2(delta.y, delta.x);

    // Target angle based on phase
    double target_angle = theta;

    // Angular error (wrap to [-π, π])
    double angular_error = target_angle - current_angle;
    while (angular_error > M_PI) angular_error -= 2.0 * M_PI;
    while (angular_error < -M_PI) angular_error += 2.0 * M_PI;

    // Tangent force (perpendicular to radial)
    Vector2 tangent = Vector2(-delta.y, delta.x) / current_radius;
    return tangent * (m_phase_angular_spring * angular_error * current_radius);
}

Vector2 ForceGraphEngine::_calculate_correlation_forces(
    int node_idx,
    Vector2 position,
    const PackedVector2Array& all_positions,
    const PackedFloat64Array& mi_values,
    const PackedByteArray& frozen_mask
) {
    Vector2 total_force = Vector2(0, 0);
    int num_nodes = all_positions.size();

    for (int j = 0; j < num_nodes; j++) {
        if (j == node_idx) continue;

        // Skip frozen nodes
        if (frozen_mask.size() > j && frozen_mask[j] != 0) {
            continue;
        }

        // Get MI value
        int mi_idx = _mi_index(node_idx, j, num_nodes);
        if (mi_idx < 0 || mi_idx >= mi_values.size()) {
            continue;
        }

        double mi = mi_values[mi_idx];
        if (mi < 1e-6) continue;  // Skip if no correlation

        // Distance between nodes
        Vector2 delta = all_positions[j] - position;
        double dist = delta.length();

        if (dist < 1e-6) continue;

        // Target distance decreases with MI: d_target = BASE / (1 + SCALING * mi)
        double target_distance = m_base_distance / (1.0 + m_correlation_scaling * mi);
        target_distance = std::max(target_distance, (double)m_min_distance);

        // Spring force
        double error = dist - target_distance;
        Vector2 direction = delta / dist;
        total_force += direction * (m_mi_spring * error);
    }

    return total_force;
}

Vector2 ForceGraphEngine::_calculate_repulsion_forces(
    int node_idx,
    Vector2 position,
    const PackedVector2Array& all_positions,
    const PackedByteArray& frozen_mask
) {
    Vector2 total_force = Vector2(0, 0);
    int num_nodes = all_positions.size();

    for (int j = 0; j < num_nodes; j++) {
        if (j == node_idx) continue;

        // Skip frozen nodes
        if (frozen_mask.size() > j && frozen_mask[j] != 0) {
            continue;
        }

        Vector2 delta = position - all_positions[j];
        double dist = delta.length();

        if (dist < 1e-6) {
            // Very close nodes - push apart strongly
            total_force += Vector2((node_idx % 2 == 0) ? 1 : -1, (node_idx / 2 % 2 == 0) ? 1 : -1).normalized() * m_repulsion_strength;
            continue;
        }

        // Inverse square repulsion: F = STRENGTH / dist^2
        double repulsion_mag = m_repulsion_strength / (dist * dist);
        Vector2 direction = delta / dist;
        total_force += direction * repulsion_mag;
    }

    return total_force;
}

int ForceGraphEngine::_mi_index(int i, int j, int num_qubits) const {
    // MI array is upper triangular: [mi_01, mi_02, mi_03, ..., mi_12, mi_13, ...]
    if (i == j) return -1;

    int row = std::min(i, j);
    int col = std::max(i, j);

    // Index = sum(num_qubits - 1 - k for k in 0..row-1) + (col - row - 1)
    //       = row * num_qubits - row*(row+1)/2 + (col - row - 1)
    return row * num_qubits - (row * (row + 1)) / 2 + (col - row - 1);
}
