#ifndef MULTI_BIOME_LOOKAHEAD_ENGINE_H
#define MULTI_BIOME_LOOKAHEAD_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include "quantum_evolution_engine.h"
#include <vector>

namespace godot {

/**
 * MultiBiomeLookaheadEngine - Batched evolution for all biomes with lookahead
 *
 * Solves the performance problem of multiple bridge crossings by:
 * 1. Registering all biome QuantumEvolutionEngines ONCE at setup
 * 2. Single evolve_all_lookahead() call processes ALL biomes × N steps
 * 3. Returns all intermediate states for async rendering
 *
 * Performance gain: 4ms bridge cost amortized over (biomes × steps) evolutions
 * Example: 6 biomes × 5 steps = 30 evolutions for cost of 1 bridge crossing
 */
class MultiBiomeLookaheadEngine : public RefCounted {
    GDCLASS(MultiBiomeLookaheadEngine, RefCounted)

public:
    MultiBiomeLookaheadEngine();
    ~MultiBiomeLookaheadEngine();

    // ========================================================================
    // SETUP METHODS (called once during initialization)
    // ========================================================================

    /**
     * Register a biome's QuantumEvolutionEngine.
     * Call this for each biome after their operators are set up.
     *
     * @param dim Hilbert space dimension (2^num_qubits)
     * @param H_packed Hamiltonian (packed complex matrix)
     * @param lindblad_triplets Array of PackedFloat64Array (triplets for each L_k)
     * @param num_qubits Number of qubits in this biome (for MI computation)
     * @return biome_id for referencing in evolve calls
     */
    int register_biome(int dim, const PackedFloat64Array& H_packed,
                       const Array& lindblad_triplets, int num_qubits);

    /**
     * Clear all registered biomes (for reinitialization).
     */
    void clear_biomes();

    /**
     * Get number of registered biomes.
     */
    int get_biome_count() const;

    // ========================================================================
    // BATCHED EVOLUTION (single call for ALL biomes, ALL steps)
    // ========================================================================

    /**
     * Evolve all registered biomes forward by 'steps' timesteps.
     *
     * This is the main optimization: single GDScript↔C++ bridge crossing
     * for ALL biomes × ALL lookahead steps.
     *
     * @param biome_rhos Array of PackedFloat64Array - current density matrix per biome
     *                   Order must match registration order (biome_id = array index)
     * @param steps Number of lookahead steps (e.g., 5 for 0.5s at 10Hz)
     * @param dt Time step per step (e.g., 0.1s for 10Hz physics)
     * @param max_dt Maximum substep for numerical stability (e.g., 0.02)
     *
     * @return Dictionary with:
     *   "results": Array<Array<PackedFloat64Array>>
     *              results[biome_id][step] = rho at t + step*dt
     *   "mi": Array<PackedFloat64Array>
     *         mi[biome_id] = mutual information array for last step
     *   "bloch": Array<PackedFloat64Array>
     *         bloch[biome_id] = packed [x,y,z,r,theta,phi] per qubit for last step
     */
    Dictionary evolve_all_lookahead(const Array& biome_rhos, int steps,
                                    float dt, float max_dt);

    // ========================================================================
    // SINGLE-BIOME EVOLUTION (for on-demand refill after user action)
    // ========================================================================

    /**
     * Evolve a single biome (when user action invalidates lookahead).
     *
     * @param biome_id Which biome to evolve
     * @param rho_packed Current density matrix
     * @param steps Number of lookahead steps
     * @param dt Time step per step
     * @param max_dt Maximum substep
     *
     * @return Dictionary with "results", "mi", and "bloch" for this biome only
     */
    Dictionary evolve_single_biome(int biome_id, const PackedFloat64Array& rho_packed,
                                   int steps, float dt, float max_dt);

protected:
    static void _bind_methods();

private:
    // Registered biome engines (created during register_biome)
    std::vector<Ref<QuantumEvolutionEngine>> m_engines;
    std::vector<int> m_num_qubits;  // num_qubits per biome for MI

    // Helper: evolve one biome for multiple steps
    struct BiomeStepResult {
        std::vector<PackedFloat64Array> steps;
        PackedFloat64Array mi;
        PackedFloat64Array bloch;
    };

    BiomeStepResult
    _evolve_biome_steps(int biome_id, const PackedFloat64Array& rho_packed,
                        int steps, float dt, float max_dt);
};

}  // namespace godot

#endif  // MULTI_BIOME_LOOKAHEAD_ENGINE_H
