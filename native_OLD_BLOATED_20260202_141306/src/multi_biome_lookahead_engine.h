#ifndef MULTI_BIOME_LOOKAHEAD_ENGINE_H
#define MULTI_BIOME_LOOKAHEAD_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include "quantum_evolution_engine.h"
#include "liquid_neural_net.h"
#include "force_graph_engine.h"
#include <vector>
#include <memory>
#include <chrono>

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

    /**
     * Enable phase-shadow LNN for a biome.
     * Creates a LiquidNeuralNet that modulates density matrix phases.
     *
     * @param biome_id Which biome to enable LNN for
     * @param hidden_size Number of hidden neurons (typically dim/4)
     */
    void enable_biome_lnn(int biome_id, int hidden_size);

    /**
     * Disable phase-shadow LNN for a biome.
     */
    void disable_biome_lnn(int biome_id);

    /**
     * Check if LNN is enabled for a biome.
     */
    bool is_lnn_enabled(int biome_id) const;

    // ========================================================================
    // PACING CONFIGURATION (CPU-gentle mode)
    // ========================================================================

    /**
     * Set pacing delay between evolution steps (milliseconds).
     * When > 0, C++ sleeps between steps to spread CPU load over time.
     * This prevents CPU spikes without requiring more GDScript↔C++ calls.
     *
     * @param delay_ms Milliseconds to sleep between steps (0 = disabled, default 1)
     */
    void set_pacing_delay_ms(int delay_ms);

    /**
     * Get current pacing delay.
     */
    int get_pacing_delay_ms() const;

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
     *         mi[biome_id] = mutual information array for last step (compat)
     *   "mi_steps": Array<Array<PackedFloat64Array>>
     *         mi_steps[biome_id][step] = mutual information array for step
     *   "bloch_steps": Array<Array<PackedFloat64Array>>
     *         bloch_steps[biome_id][step] = packed [p0,p1,x,y,z,r,theta,phi] per qubit
     *   "purity_steps": Array<Array<float>>
     *         purity_steps[biome_id][step] = Tr(rho^2)
     *   "position_steps": Array<Array<PackedVector2Array>>
     *         position_steps[biome_id][step] = node positions for step
     *   "velocity_steps": Array<Array<PackedVector2Array>>
     *         velocity_steps[biome_id][step] = node velocities for step
     *   "metadata": Array<Dictionary>
     *         metadata[biome_id] = emoji/axis mapping payload
     *   "couplings": Array<Dictionary>
     *         couplings[biome_id] = hamiltonian/lindblad/sink flux payload
     *   "icon_maps": Array<Dictionary>
     *         icon_maps[biome_id] = cumulative emoji probability map (sorted)
     */
    Dictionary evolve_all_lookahead(const Array& biome_rhos, int steps,
                                    float dt, float max_dt);

    /**
     * Store per-biome metadata payload (emoji mapping, axes, etc.).
     * This is returned verbatim in evolve_* results.
     */
    void set_biome_metadata(int biome_id, const Dictionary& metadata);

    /**
     * Store per-biome coupling payload (hamiltonian/lindblad/sink flux).
     * This is returned verbatim in evolve_* results.
     */
    void set_biome_couplings(int biome_id, const Dictionary& couplings);

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
     * @return Dictionary with "results", "mi", "mi_steps", "bloch_steps", "purity_steps",
     *         and "icon_map" for this biome only
     */
    Dictionary evolve_single_biome(int biome_id, const PackedFloat64Array& rho_packed,
                                   int steps, float dt, float max_dt);

    // ========================================================================
    // TIME-SLICED COMPUTATION (yields CPU periodically)
    // ========================================================================

    /**
     * Start a time-sliced computation. Call continue_sliced_compute() repeatedly
     * until is_sliced_compute_complete() returns true, then get_sliced_compute_result().
     *
     * This prevents the engine from hogging the CPU - it will yield after max_time_ms.
     *
     * @param biome_rhos Array of current density matrices (one per biome)
     * @param steps Number of lookahead steps to compute
     * @param dt Time step per step
     * @param max_dt Maximum substep for numerical stability
     */
    void start_sliced_compute(const Array& biome_rhos, int steps, float dt, float max_dt);

    /**
     * Continue time-sliced computation for up to max_time_ms.
     *
     * @param max_time_ms Maximum milliseconds to compute before yielding (e.g., 5)
     * @return true if computation completed, false if more work remains
     */
    bool continue_sliced_compute(int max_time_ms);

    /**
     * Check if sliced computation is complete.
     */
    bool is_sliced_compute_complete() const;

    /**
     * Get the result of a completed sliced computation.
     * Only valid after is_sliced_compute_complete() returns true.
     *
     * @return Same Dictionary format as evolve_all_lookahead()
     */
    Dictionary get_sliced_compute_result();

    /**
     * Cancel an in-progress sliced computation.
     */
    void cancel_sliced_compute();

    /**
     * Get progress of current sliced computation (0.0 to 1.0).
     */
    float get_sliced_compute_progress() const;

protected:
    static void _bind_methods();

private:
    // Registered biome engines (created during register_biome)
    std::vector<Ref<QuantumEvolutionEngine>> m_engines;
    std::vector<int> m_num_qubits;  // num_qubits per biome for MI
    std::vector<Dictionary> m_metadata;
    std::vector<Dictionary> m_couplings;

    // Pacing: sleep between steps to spread CPU load (0 = disabled)
    int m_pacing_delay_ms = 1;  // Default: 1ms sleep between steps (gentle)

    // Phase-shadow LNN (one per biome, nullptr if disabled)
    std::vector<std::unique_ptr<LiquidNeuralNet>> m_lnns;

    // Force graph engine for computing node positions (shared across all biomes)
    Ref<ForceGraphEngine> m_force_engine;

    // Current node positions/velocities per biome (for force integration)
    std::vector<PackedVector2Array> m_node_positions;
    std::vector<PackedVector2Array> m_node_velocities;
    std::vector<Vector2> m_biome_centers;  // Center position per biome

    // Apply LNN phase modulation to density matrix diagonal
    void _apply_lnn_phase_modulation(int biome_id, PackedFloat64Array& rho_packed);

    // Helper: evolve one biome for multiple steps
    struct BiomeStepResult {
        std::vector<PackedFloat64Array> steps;
        std::vector<PackedFloat64Array> mi_steps;
        std::vector<PackedFloat64Array> bloch_steps;
        std::vector<double> purity_steps;
        std::vector<PackedVector2Array> position_steps;
        std::vector<PackedVector2Array> velocity_steps;
        Dictionary icon_map;
    };

    BiomeStepResult
    _evolve_biome_steps(int biome_id, const PackedFloat64Array& rho_packed,
                        int steps, float dt, float max_dt, bool compute_mi = true);

    Dictionary _build_icon_map(int biome_id,
                               const std::vector<PackedFloat64Array>& bloch_steps);

    // ========================================================================
    // TIME-SLICED COMPUTATION STATE
    // ========================================================================

    // Sliced computation state
    struct SlicedComputeState {
        bool in_progress = false;
        bool complete = false;

        // Input parameters (saved from start_sliced_compute)
        Array biome_rhos;
        int total_steps = 0;
        float dt = 0.1f;
        float max_dt = 0.02f;

        // Progress tracking
        int current_biome = 0;      // Which biome we're processing
        int current_step = 0;       // Which step within current biome
        PackedFloat64Array current_rho;  // Current state being evolved

        // Accumulated results per biome
        std::vector<BiomeStepResult> biome_results;

        void reset() {
            in_progress = false;
            complete = false;
            biome_rhos = Array();
            total_steps = 0;
            current_biome = 0;
            current_step = 0;
            current_rho = PackedFloat64Array();
            biome_results.clear();
        }
    };

    SlicedComputeState m_sliced_state;

    // Helper: do one evolution step for current biome, update state
    // Returns true if this biome is complete
    bool _do_one_sliced_step();
};

}  // namespace godot

#endif  // MULTI_BIOME_LOOKAHEAD_ENGINE_H
