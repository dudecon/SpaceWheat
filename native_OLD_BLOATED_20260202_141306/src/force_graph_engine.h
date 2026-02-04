#ifndef FORCE_GRAPH_ENGINE_H
#define FORCE_GRAPH_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

/**
 * ForceGraphEngine - Native force-directed graph layout
 *
 * Computes spring-physics-based positions for quantum bubbles using:
 * - Purity radial force (pure states → center, mixed → edge)
 * - Phase angular force (same phase → cluster)
 * - Correlation force (high MI → attract)
 * - Repulsion force (prevent overlap)
 *
 * Integrates with QuantumEvolutionEngine output (MI, Bloch vectors, purity).
 */
class ForceGraphEngine : public RefCounted {
    GDCLASS(ForceGraphEngine, RefCounted)

public:
    ForceGraphEngine();
    ~ForceGraphEngine();

    /**
     * Compute force-based position updates for all nodes.
     *
     * @param positions Current node positions (PackedVector2Array)
     * @param velocities Current node velocities (PackedVector2Array)
     * @param bloch_packet Bloch sphere data from quantum evolution
     *                     Format: [p0,p1,x,y,z,r,θ,φ] per qubit (stride=8)
     * @param mi_values Mutual information array (upper triangular)
     * @param biome_center Center position of biome (Vector2)
     * @param dt Timestep for integration
     * @param frozen_mask Which nodes are frozen (PackedByteArray, 1=frozen)
     *
     * @return Dictionary with:
     *   "positions": PackedVector2Array (updated positions)
     *   "velocities": PackedVector2Array (updated velocities)
     */
    Dictionary update_positions(
        const PackedVector2Array& positions,
        const PackedVector2Array& velocities,
        const PackedFloat64Array& bloch_packet,
        const PackedFloat64Array& mi_values,
        Vector2 biome_center,
        float dt,
        const PackedByteArray& frozen_mask
    );

    // Configuration methods
    void set_purity_radial_spring(float spring);
    void set_phase_angular_spring(float spring);
    void set_correlation_spring(float spring);
    void set_mi_spring(float spring);
    void set_repulsion_strength(float strength);
    void set_damping(float damping);
    void set_base_distance(float distance);
    void set_min_distance(float distance);

    float get_purity_radial_spring() const { return m_purity_radial_spring; }
    float get_phase_angular_spring() const { return m_phase_angular_spring; }
    float get_correlation_spring() const { return m_correlation_spring; }
    float get_mi_spring() const { return m_mi_spring; }
    float get_repulsion_strength() const { return m_repulsion_strength; }
    float get_damping() const { return m_damping; }
    float get_base_distance() const { return m_base_distance; }
    float get_min_distance() const { return m_min_distance; }

protected:
    static void _bind_methods();

private:
    // Physics constants (match QuantumForceSystem.gd defaults)
    float m_purity_radial_spring = 0.08f;
    float m_phase_angular_spring = 0.04f;
    float m_correlation_spring = 0.12f;
    float m_mi_spring = 0.18f;
    float m_repulsion_strength = 1500.0f;
    float m_damping = 0.89f;  // 11% energy loss per frame
    float m_base_distance = 120.0f;
    float m_min_distance = 15.0f;
    float m_correlation_scaling = 3.0f;
    float m_max_biome_radius = 250.0f;

    // Force calculation helpers
    Vector2 _calculate_purity_radial_force(
        int node_idx,
        Vector2 position,
        const PackedFloat64Array& bloch_packet,
        Vector2 biome_center
    );

    Vector2 _calculate_phase_angular_force(
        int node_idx,
        Vector2 position,
        const PackedFloat64Array& bloch_packet,
        Vector2 biome_center
    );

    Vector2 _calculate_correlation_forces(
        int node_idx,
        Vector2 position,
        const PackedVector2Array& all_positions,
        const PackedFloat64Array& mi_values,
        const PackedByteArray& frozen_mask
    );

    Vector2 _calculate_repulsion_forces(
        int node_idx,
        Vector2 position,
        const PackedVector2Array& all_positions,
        const PackedByteArray& frozen_mask
    );

    // MI indexing helper
    int _mi_index(int i, int j, int num_qubits) const;
};

}  // namespace godot

#endif  // FORCE_GRAPH_ENGINE_H
