#include "multi_biome_lookahead_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void MultiBiomeLookaheadEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("register_biome", "dim", "H_packed", "lindblad_triplets", "num_qubits"),
                         &MultiBiomeLookaheadEngine::register_biome);
    ClassDB::bind_method(D_METHOD("clear_biomes"),
                         &MultiBiomeLookaheadEngine::clear_biomes);
    ClassDB::bind_method(D_METHOD("get_biome_count"),
                         &MultiBiomeLookaheadEngine::get_biome_count);

    ClassDB::bind_method(D_METHOD("evolve_all_lookahead", "biome_rhos", "steps", "dt", "max_dt"),
                         &MultiBiomeLookaheadEngine::evolve_all_lookahead);
    ClassDB::bind_method(D_METHOD("evolve_single_biome", "biome_id", "rho_packed", "steps", "dt", "max_dt"),
                         &MultiBiomeLookaheadEngine::evolve_single_biome);
}

MultiBiomeLookaheadEngine::MultiBiomeLookaheadEngine() {}

MultiBiomeLookaheadEngine::~MultiBiomeLookaheadEngine() {}

int MultiBiomeLookaheadEngine::register_biome(int dim, const PackedFloat64Array& H_packed,
                                               const Array& lindblad_triplets, int num_qubits) {
    // Create new QuantumEvolutionEngine for this biome
    Ref<QuantumEvolutionEngine> engine;
    engine.instantiate();

    // Configure dimension
    engine->set_dimension(dim);

    // Set Hamiltonian
    if (H_packed.size() > 0) {
        engine->set_hamiltonian(H_packed);
    }

    // Add Lindblad operators
    for (int i = 0; i < lindblad_triplets.size(); i++) {
        PackedFloat64Array triplets = lindblad_triplets[i];
        if (triplets.size() > 0) {
            engine->add_lindblad_triplets(triplets);
        }
    }

    // Finalize (precompute L†, L†L)
    engine->finalize();

    // Store engine and metadata
    int biome_id = static_cast<int>(m_engines.size());
    m_engines.push_back(engine);
    m_num_qubits.push_back(num_qubits);

    UtilityFunctions::print("MultiBiomeLookaheadEngine: Registered biome ",
                            biome_id, " (dim=", dim, ", num_qubits=", num_qubits,
                            ", lindblad_ops=", lindblad_triplets.size(), ")");

    return biome_id;
}

void MultiBiomeLookaheadEngine::clear_biomes() {
    m_engines.clear();
    m_num_qubits.clear();
}

int MultiBiomeLookaheadEngine::get_biome_count() const {
    return static_cast<int>(m_engines.size());
}

Dictionary MultiBiomeLookaheadEngine::evolve_all_lookahead(
    const Array& biome_rhos, int steps, float dt, float max_dt) {

    Dictionary result;
    Array all_results;  // Array<Array<PackedFloat64Array>>
    Array all_mi;       // Array<PackedFloat64Array>

    int num_biomes = static_cast<int>(biome_rhos.size());

    // Validate input size matches registered biomes
    if (num_biomes > static_cast<int>(m_engines.size())) {
        UtilityFunctions::push_warning(
            "MultiBiomeLookaheadEngine: More rhos than registered biomes (",
            num_biomes, " vs ", m_engines.size(), ")");
        num_biomes = static_cast<int>(m_engines.size());
    }

    // Process each biome
    for (int biome_id = 0; biome_id < num_biomes; biome_id++) {
        PackedFloat64Array rho_packed = biome_rhos[biome_id];

        // Evolve this biome for all steps
        auto [step_results, mi] = _evolve_biome_steps(biome_id, rho_packed, steps, dt, max_dt);

        // Convert step_results to Godot Array
        Array biome_steps;
        for (const auto& step_rho : step_results) {
            biome_steps.push_back(step_rho);
        }

        all_results.push_back(biome_steps);
        all_mi.push_back(mi);
    }

    result["results"] = all_results;
    result["mi"] = all_mi;

    return result;
}

Dictionary MultiBiomeLookaheadEngine::evolve_single_biome(
    int biome_id, const PackedFloat64Array& rho_packed,
    int steps, float dt, float max_dt) {

    Dictionary result;

    if (biome_id < 0 || biome_id >= static_cast<int>(m_engines.size())) {
        UtilityFunctions::push_warning(
            "MultiBiomeLookaheadEngine: Invalid biome_id ", biome_id);
        return result;
    }

    // Evolve this biome
    auto [step_results, mi] = _evolve_biome_steps(biome_id, rho_packed, steps, dt, max_dt);

    // Convert to Godot types
    Array biome_steps;
    for (const auto& step_rho : step_results) {
        biome_steps.push_back(step_rho);
    }

    result["results"] = biome_steps;
    result["mi"] = mi;

    return result;
}

std::pair<std::vector<PackedFloat64Array>, PackedFloat64Array>
MultiBiomeLookaheadEngine::_evolve_biome_steps(
    int biome_id, const PackedFloat64Array& rho_packed,
    int steps, float dt, float max_dt) {

    std::vector<PackedFloat64Array> step_results;
    PackedFloat64Array final_mi;

    if (biome_id < 0 || biome_id >= static_cast<int>(m_engines.size())) {
        return {step_results, final_mi};
    }

    Ref<QuantumEvolutionEngine> engine = m_engines[biome_id];
    int num_qubits = m_num_qubits[biome_id];

    // Start with current rho
    PackedFloat64Array current_rho = rho_packed;

    // Evolve for each step
    for (int step = 0; step < steps; step++) {
        // Single evolution step (with subcycling inside)
        PackedFloat64Array evolved_rho = engine->evolve(current_rho, dt, max_dt);

        // Store result
        step_results.push_back(evolved_rho);

        // Update for next step
        current_rho = evolved_rho;
    }

    // Compute MI for the final state (used for force graph)
    if (num_qubits >= 2 && !step_results.empty()) {
        final_mi = engine->compute_all_mutual_information(step_results.back(), num_qubits);
    }

    return {step_results, final_mi};
}
