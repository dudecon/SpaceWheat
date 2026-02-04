#include "multi_biome_lookahead_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <numeric>
#include <thread>  // For pacing (sleep between steps)

using namespace godot;

void MultiBiomeLookaheadEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("register_biome", "dim", "H_packed", "lindblad_triplets", "num_qubits"),
                         &MultiBiomeLookaheadEngine::register_biome);
    ClassDB::bind_method(D_METHOD("set_biome_metadata", "biome_id", "metadata"),
                         &MultiBiomeLookaheadEngine::set_biome_metadata);
    ClassDB::bind_method(D_METHOD("set_biome_couplings", "biome_id", "couplings"),
                         &MultiBiomeLookaheadEngine::set_biome_couplings);
    ClassDB::bind_method(D_METHOD("clear_biomes"),
                         &MultiBiomeLookaheadEngine::clear_biomes);
    ClassDB::bind_method(D_METHOD("get_biome_count"),
                         &MultiBiomeLookaheadEngine::get_biome_count);

    // LNN methods
    ClassDB::bind_method(D_METHOD("enable_biome_lnn", "biome_id", "hidden_size"),
                         &MultiBiomeLookaheadEngine::enable_biome_lnn);
    ClassDB::bind_method(D_METHOD("disable_biome_lnn", "biome_id"),
                         &MultiBiomeLookaheadEngine::disable_biome_lnn);
    ClassDB::bind_method(D_METHOD("is_lnn_enabled", "biome_id"),
                         &MultiBiomeLookaheadEngine::is_lnn_enabled);

    ClassDB::bind_method(D_METHOD("evolve_all_lookahead", "biome_rhos", "steps", "dt", "max_dt"),
                         &MultiBiomeLookaheadEngine::evolve_all_lookahead);
    ClassDB::bind_method(D_METHOD("evolve_single_biome", "biome_id", "rho_packed", "steps", "dt", "max_dt"),
                         &MultiBiomeLookaheadEngine::evolve_single_biome);

    // Time-sliced computation methods
    ClassDB::bind_method(D_METHOD("start_sliced_compute", "biome_rhos", "steps", "dt", "max_dt"),
                         &MultiBiomeLookaheadEngine::start_sliced_compute);
    ClassDB::bind_method(D_METHOD("continue_sliced_compute", "max_time_ms"),
                         &MultiBiomeLookaheadEngine::continue_sliced_compute);
    ClassDB::bind_method(D_METHOD("is_sliced_compute_complete"),
                         &MultiBiomeLookaheadEngine::is_sliced_compute_complete);
    ClassDB::bind_method(D_METHOD("get_sliced_compute_result"),
                         &MultiBiomeLookaheadEngine::get_sliced_compute_result);
    ClassDB::bind_method(D_METHOD("cancel_sliced_compute"),
                         &MultiBiomeLookaheadEngine::cancel_sliced_compute);
    ClassDB::bind_method(D_METHOD("get_sliced_compute_progress"),
                         &MultiBiomeLookaheadEngine::get_sliced_compute_progress);

    // Pacing methods (CPU-gentle mode)
    ClassDB::bind_method(D_METHOD("set_pacing_delay_ms", "delay_ms"),
                         &MultiBiomeLookaheadEngine::set_pacing_delay_ms);
    ClassDB::bind_method(D_METHOD("get_pacing_delay_ms"),
                         &MultiBiomeLookaheadEngine::get_pacing_delay_ms);
}

MultiBiomeLookaheadEngine::MultiBiomeLookaheadEngine() {
    // Initialize force graph engine (shared across all biomes)
    m_force_engine.instantiate();
    m_force_engine->set_repulsion_strength(2500.0f);
    m_force_engine->set_damping(0.92f);
    m_force_engine->set_base_distance(100.0f);
    m_force_engine->set_min_distance(20.0f);
    m_force_engine->set_mi_spring(0.18f);
}

void MultiBiomeLookaheadEngine::set_pacing_delay_ms(int delay_ms) {
    m_pacing_delay_ms = (delay_ms >= 0) ? delay_ms : 0;
}

int MultiBiomeLookaheadEngine::get_pacing_delay_ms() const {
    return m_pacing_delay_ms;
}

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
    m_metadata.push_back(Dictionary());
    m_couplings.push_back(Dictionary());
    m_lnns.push_back(nullptr);  // LNN disabled by default

    // Initialize force graph data (positions/velocities for num_qubits nodes)
    PackedVector2Array initial_positions;
    PackedVector2Array initial_velocities;
    initial_positions.resize(num_qubits);
    initial_velocities.resize(num_qubits);

    // Initialize to random positions in a circle (will be refined by force calculation)
    for (int i = 0; i < num_qubits; i++) {
        float angle = (float(i) / float(num_qubits)) * 2.0f * 3.14159f;
        float radius = 100.0f;
        initial_positions[i] = Vector2(std::cos(angle) * radius, std::sin(angle) * radius);
        initial_velocities[i] = Vector2(0, 0);
    }

    m_node_positions.push_back(initial_positions);
    m_node_velocities.push_back(initial_velocities);
    m_biome_centers.push_back(Vector2(960, 540));  // Default center (will be updated by GDScript)

    UtilityFunctions::print("MultiBiomeLookaheadEngine: Registered biome ",
                            biome_id, " (dim=", dim, ", num_qubits=", num_qubits,
                            ", lindblad_ops=", lindblad_triplets.size(), ")");

    return biome_id;
}

void MultiBiomeLookaheadEngine::clear_biomes() {
    m_engines.clear();
    m_num_qubits.clear();
    m_metadata.clear();
    m_couplings.clear();
    m_lnns.clear();
    m_node_positions.clear();
    m_node_velocities.clear();
    m_biome_centers.clear();
}

int MultiBiomeLookaheadEngine::get_biome_count() const {
    return static_cast<int>(m_engines.size());
}

void MultiBiomeLookaheadEngine::set_biome_metadata(int biome_id, const Dictionary& metadata) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_metadata.size())) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid biome_id for metadata ", biome_id);
        return;
    }
    m_metadata[biome_id] = metadata;
    if (biome_id < static_cast<int>(m_engines.size())) {
        m_couplings[biome_id] = m_engines[biome_id]->compute_coupling_payload(metadata);
    }
}

void MultiBiomeLookaheadEngine::set_biome_couplings(int biome_id, const Dictionary& couplings) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_couplings.size())) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid biome_id for couplings ", biome_id);
        return;
    }
    m_couplings[biome_id] = couplings;
}

Dictionary MultiBiomeLookaheadEngine::evolve_all_lookahead(
    const Array& biome_rhos, int steps, float dt, float max_dt) {

    Dictionary result;
    Array all_results;        // Array<Array<PackedFloat64Array>>
    Array all_mi;             // Array<PackedFloat64Array> (last step)
    Array all_mi_steps;       // Array<Array<PackedFloat64Array>>
    Array all_bloch_steps;    // Array<Array<PackedFloat64Array>>
    Array all_purity_steps;   // Array<Array<float>>
    Array all_position_steps; // Array<Array<PackedVector2Array>> (NEW: force positions)
    Array all_velocity_steps; // Array<Array<PackedVector2Array>> (NEW: force velocities)
    Array all_metadata;       // Array<Dictionary>
    Array all_couplings;      // Array<Dictionary>
    Array all_icon_maps;      // Array<Dictionary>

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
        auto biome_result = _evolve_biome_steps(biome_id, rho_packed, steps, dt, max_dt);

        // Convert step_results to Godot Array
        Array biome_steps;
        for (const auto& step_rho : biome_result.steps) {
            biome_steps.push_back(step_rho);
        }

        all_results.push_back(biome_steps);

        Array biome_mi_steps;
        for (const auto& mi_step : biome_result.mi_steps) {
            biome_mi_steps.push_back(mi_step);
        }
        all_mi_steps.push_back(biome_mi_steps);
        if (!biome_result.mi_steps.empty()) {
            all_mi.push_back(biome_result.mi_steps.back());
        } else {
            all_mi.push_back(PackedFloat64Array());
        }

        Array biome_bloch_steps;
        for (const auto& bloch_step : biome_result.bloch_steps) {
            biome_bloch_steps.push_back(bloch_step);
        }
        all_bloch_steps.push_back(biome_bloch_steps);

        Array biome_purity_steps;
        for (double purity_val : biome_result.purity_steps) {
            biome_purity_steps.push_back(purity_val);
        }
        all_purity_steps.push_back(biome_purity_steps);

        // NEW: Collect force graph position/velocity steps
        Array biome_position_steps;
        for (const auto& position_step : biome_result.position_steps) {
            biome_position_steps.push_back(position_step);
        }
        all_position_steps.push_back(biome_position_steps);

        Array biome_velocity_steps;
        for (const auto& velocity_step : biome_result.velocity_steps) {
            biome_velocity_steps.push_back(velocity_step);
        }
        all_velocity_steps.push_back(biome_velocity_steps);

        if (biome_id < static_cast<int>(m_metadata.size())) {
            all_metadata.push_back(m_metadata[biome_id]);
        } else {
            all_metadata.push_back(Dictionary());
        }

        if (biome_id < static_cast<int>(m_couplings.size())) {
            all_couplings.push_back(m_couplings[biome_id]);
        } else {
            all_couplings.push_back(Dictionary());
        }

        all_icon_maps.push_back(biome_result.icon_map);
    }

    result["results"] = all_results;
    result["mi"] = all_mi;
    result["mi_steps"] = all_mi_steps;
    result["bloch_steps"] = all_bloch_steps;
    result["purity_steps"] = all_purity_steps;
    result["position_steps"] = all_position_steps;  // NEW: force positions
    result["velocity_steps"] = all_velocity_steps;  // NEW: force velocities
    result["metadata"] = all_metadata;
    result["couplings"] = all_couplings;
    result["icon_maps"] = all_icon_maps;

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
    auto biome_result = _evolve_biome_steps(biome_id, rho_packed, steps, dt, max_dt);

    // Convert to Godot types
    Array biome_steps;
    for (const auto& step_rho : biome_result.steps) {
        biome_steps.push_back(step_rho);
    }

    result["results"] = biome_steps;
    if (!biome_result.mi_steps.empty()) {
        result["mi"] = biome_result.mi_steps.back();
    } else {
        result["mi"] = PackedFloat64Array();
    }

    Array biome_mi_steps;
    for (const auto& mi_step : biome_result.mi_steps) {
        biome_mi_steps.push_back(mi_step);
    }
    result["mi_steps"] = biome_mi_steps;

    Array biome_bloch_steps;
    for (const auto& bloch_step : biome_result.bloch_steps) {
        biome_bloch_steps.push_back(bloch_step);
    }
    result["bloch_steps"] = biome_bloch_steps;

    Array biome_purity_steps;
    for (double purity_val : biome_result.purity_steps) {
        biome_purity_steps.push_back(purity_val);
    }
    result["purity_steps"] = biome_purity_steps;

    if (biome_id >= 0 && biome_id < static_cast<int>(m_metadata.size())) {
        result["metadata"] = m_metadata[biome_id];
    }
    if (biome_id >= 0 && biome_id < static_cast<int>(m_couplings.size())) {
        result["couplings"] = m_couplings[biome_id];
    }
    result["icon_map"] = biome_result.icon_map;

    return result;
}

MultiBiomeLookaheadEngine::BiomeStepResult
MultiBiomeLookaheadEngine::_evolve_biome_steps(
    int biome_id, const PackedFloat64Array& rho_packed,
    int steps, float dt, float max_dt, bool compute_mi) {

    BiomeStepResult out;

    if (biome_id < 0 || biome_id >= static_cast<int>(m_engines.size())) {
        return out;
    }

    Ref<QuantumEvolutionEngine> engine = m_engines[biome_id];
    int num_qubits = m_num_qubits[biome_id];

    // Start with current rho
    PackedFloat64Array current_rho = rho_packed;

    // Get current force positions/velocities for this biome
    PackedVector2Array current_positions = m_node_positions[biome_id];
    PackedVector2Array current_velocities = m_node_velocities[biome_id];
    Vector2 biome_center = m_biome_centers[biome_id];

    // Create frozen mask (all nodes active for now)
    PackedByteArray frozen_mask;
    frozen_mask.resize(num_qubits);
    for (int i = 0; i < num_qubits; i++) {
        frozen_mask[i] = 0;  // 0 = active, 1 = frozen
    }

    // Evolve for each step
    for (int step = 0; step < steps; step++) {
        // Single evolution step (with subcycling inside)
        PackedFloat64Array evolved_rho = engine->evolve(current_rho, dt, max_dt);

        // Apply phase-shadow LNN modulation (if enabled)
        _apply_lnn_phase_modulation(biome_id, evolved_rho);

        // Store result
        out.steps.push_back(evolved_rho);
        PackedFloat64Array bloch_packet = engine->compute_bloch_metrics_from_packed(evolved_rho, num_qubits);
        out.bloch_steps.push_back(bloch_packet);
        double purity = engine->compute_purity_from_packed(evolved_rho);
        out.purity_steps.push_back(purity);

        // OPTIMIZED MI: Adaptive computation with screening + high-purity approximation
        // - Step 0: Full scan to identify candidate pairs (pairs with MI > threshold)
        // - Steps 1+: Only compute for candidates, skip negligible pairs
        // - Uses linear entropy (no eigendecomp) when purity > 0.9
        PackedFloat64Array mi_values;
        if (compute_mi) {
            bool force_full_scan = (step == 0);  // Screen on first step only
            mi_values = engine->compute_mi_adaptive(
                evolved_rho, num_qubits, purity, force_full_scan);
            out.mi_steps.push_back(mi_values);
        } else {
            mi_values = PackedFloat64Array();  // Empty placeholder
            out.mi_steps.push_back(mi_values);
        }

        // NEW: Compute force-directed positions using Bloch + MI data
        if (m_force_engine.is_valid()) {
            Dictionary force_result = m_force_engine->update_positions(
                current_positions,
                current_velocities,
                bloch_packet,
                mi_values,
                biome_center,
                dt,
                frozen_mask
            );

            // Extract updated positions/velocities
            current_positions = force_result.get("positions", current_positions);
            current_velocities = force_result.get("velocities", current_velocities);

            // Store for this step
            out.position_steps.push_back(current_positions);
            out.velocity_steps.push_back(current_velocities);
        } else {
            // No force engine - use previous positions
            out.position_steps.push_back(current_positions);
            out.velocity_steps.push_back(current_velocities);
        }

        // Update for next step
        current_rho = evolved_rho;

        // CPU-gentle pacing: sleep between steps to spread load
        if (m_pacing_delay_ms > 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(m_pacing_delay_ms));
        }
    }

    out.icon_map = _build_icon_map(biome_id, out.bloch_steps);

    // Update stored positions/velocities for next refill
    m_node_positions[biome_id] = current_positions;
    m_node_velocities[biome_id] = current_velocities;

    return out;
}

// ============================================================================
// PHASE-SHADOW LNN METHODS
// ============================================================================

void MultiBiomeLookaheadEngine::enable_biome_lnn(int biome_id, int hidden_size) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_engines.size())) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid biome_id for LNN ", biome_id);
        return;
    }

    // Get dimension from the engine
    int dim = m_engines[biome_id]->get_dimension();
    if (dim <= 0) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid dimension for LNN");
        return;
    }

    // Create LNN: input = dim phases, output = dim phase modulations
    m_lnns[biome_id] = std::make_unique<LiquidNeuralNet>(dim, hidden_size, dim);

    UtilityFunctions::print("MultiBiomeLookaheadEngine: LNN enabled for biome ", biome_id,
                            " (dim=", dim, ", hidden=", hidden_size, ")");
}

void MultiBiomeLookaheadEngine::disable_biome_lnn(int biome_id) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_lnns.size())) {
        return;
    }
    m_lnns[biome_id].reset();
}

bool MultiBiomeLookaheadEngine::is_lnn_enabled(int biome_id) const {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_lnns.size())) {
        return false;
    }
    return m_lnns[biome_id] != nullptr;
}

void MultiBiomeLookaheadEngine::_apply_lnn_phase_modulation(int biome_id, PackedFloat64Array& rho_packed) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_lnns.size()) || !m_lnns[biome_id]) {
        return;
    }

    LiquidNeuralNet* lnn = m_lnns[biome_id].get();
    int dim = static_cast<int>(std::sqrt(rho_packed.size() / 2));
    if (dim * dim * 2 != rho_packed.size()) {
        return;
    }

    // Extract diagonal phases: phase[i] = arg(rho[i,i])
    std::vector<double> phases(dim);
    for (int i = 0; i < dim; i++) {
        int idx = (i * dim + i) * 2;  // Diagonal element rho[i,i]
        double re = rho_packed[idx];
        double im = rho_packed[idx + 1];
        phases[i] = std::atan2(im, re);
    }

    // Forward pass through LNN
    std::vector<double> phase_deltas = lnn->forward(phases);

    // Apply phase modulation to diagonal elements
    // rho[i,i] *= exp(i * delta_phase[i])
    for (int i = 0; i < dim && i < static_cast<int>(phase_deltas.size()); i++) {
        int idx = (i * dim + i) * 2;
        double re = rho_packed[idx];
        double im = rho_packed[idx + 1];

        // Scale delta to be small modulation (0.01 radians max)
        double delta = phase_deltas[i] * 0.01;

        // exp(i*delta) = cos(delta) + i*sin(delta)
        double cos_d = std::cos(delta);
        double sin_d = std::sin(delta);

        // (re + i*im) * (cos_d + i*sin_d) = (re*cos_d - im*sin_d) + i*(re*sin_d + im*cos_d)
        rho_packed[idx] = re * cos_d - im * sin_d;
        rho_packed[idx + 1] = re * sin_d + im * cos_d;
    }
}

// ============================================================================
// ICON MAP BUILDING
// ============================================================================

Dictionary MultiBiomeLookaheadEngine::_build_icon_map(
    int biome_id, const std::vector<PackedFloat64Array>& bloch_steps) {

    Dictionary icon_map;

    if (biome_id < 0 || biome_id >= static_cast<int>(m_num_qubits.size())) {
        return icon_map;
    }
    if (bloch_steps.empty()) {
        return icon_map;
    }
    if (biome_id < 0 || biome_id >= static_cast<int>(m_metadata.size())) {
        return icon_map;
    }

    Dictionary metadata = m_metadata[biome_id];
    if (metadata.is_empty()) {
        return icon_map;
    }

    Array emoji_list = metadata.get("emoji_list", Array());
    Dictionary emoji_to_qubit = metadata.get("emoji_to_qubit", Dictionary());
    Dictionary emoji_to_pole = metadata.get("emoji_to_pole", Dictionary());

    if (emoji_list.is_empty() || emoji_to_qubit.is_empty() || emoji_to_pole.is_empty()) {
        return icon_map;
    }

    int num_qubits = m_num_qubits[biome_id];
    const int stride = 8;
    const int expected = num_qubits * stride;

    std::vector<double> totals;
    totals.resize(emoji_list.size(), 0.0);

    for (const auto& bloch_step : bloch_steps) {
        if (bloch_step.is_empty() || bloch_step.size() < expected) {
            continue;
        }

        const double* ptr = bloch_step.ptr();
        for (int i = 0; i < emoji_list.size(); i++) {
            Variant emoji_var = emoji_list[i];
            if (emoji_var.get_type() != Variant::STRING) {
                continue;
            }
            String emoji = emoji_var;
            if (!emoji_to_qubit.has(emoji) || !emoji_to_pole.has(emoji)) {
                continue;
            }

            int qubit = static_cast<int>(emoji_to_qubit[emoji]);
            int pole = static_cast<int>(emoji_to_pole[emoji]);
            if (qubit < 0 || qubit >= num_qubits || (pole != 0 && pole != 1)) {
                continue;
            }

            int base = qubit * stride;
            double p0 = ptr[base + 0];
            double p1 = ptr[base + 1];
            double prob = (pole == 0) ? p0 : p1;
            totals[i] += prob;
        }
    }

    std::vector<int> order(totals.size());
    std::iota(order.begin(), order.end(), 0);
    std::sort(order.begin(), order.end(), [&totals](int a, int b) {
        return totals[a] > totals[b];
    });

    Array sorted_emojis;
    PackedFloat64Array sorted_weights;
    sorted_weights.resize(static_cast<int>(order.size()));

    Dictionary by_emoji;
    double total_sum = 0.0;
    int out_idx = 0;
    for (int idx : order) {
        Variant emoji_var = emoji_list[idx];
        if (emoji_var.get_type() != Variant::STRING) {
            continue;
        }
        String emoji = emoji_var;
        double weight = totals[idx];
        sorted_emojis.push_back(emoji);
        sorted_weights.set(out_idx, weight);
        out_idx += 1;
        by_emoji[emoji] = weight;
        total_sum += weight;
    }

    icon_map["emojis"] = sorted_emojis;
    icon_map["weights"] = sorted_weights;
    icon_map["by_emoji"] = by_emoji;
    icon_map["steps"] = static_cast<int>(bloch_steps.size());
    icon_map["total"] = total_sum;
    icon_map["num_qubits"] = num_qubits;

    return icon_map;
}

// ============================================================================
// TIME-SLICED COMPUTATION IMPLEMENTATION
// ============================================================================

void MultiBiomeLookaheadEngine::start_sliced_compute(
    const Array& biome_rhos, int steps, float dt, float max_dt) {

    // Cancel any existing computation
    m_sliced_state.reset();

    int num_biomes = static_cast<int>(biome_rhos.size());
    if (num_biomes == 0 || steps <= 0) {
        m_sliced_state.complete = true;
        return;
    }

    // Clamp to registered biomes
    if (num_biomes > static_cast<int>(m_engines.size())) {
        num_biomes = static_cast<int>(m_engines.size());
    }

    // Save parameters
    m_sliced_state.biome_rhos = biome_rhos;
    m_sliced_state.total_steps = steps;
    m_sliced_state.dt = dt;
    m_sliced_state.max_dt = max_dt;

    // Initialize progress
    m_sliced_state.current_biome = 0;
    m_sliced_state.current_step = 0;
    m_sliced_state.current_rho = biome_rhos[0];

    // Pre-allocate result storage for all biomes
    m_sliced_state.biome_results.resize(num_biomes);
    for (int i = 0; i < num_biomes; i++) {
        m_sliced_state.biome_results[i] = BiomeStepResult();
    }

    m_sliced_state.in_progress = true;
    m_sliced_state.complete = false;
}

bool MultiBiomeLookaheadEngine::continue_sliced_compute(int max_time_ms) {
    if (!m_sliced_state.in_progress || m_sliced_state.complete) {
        return true;  // Nothing to do or already complete
    }

    auto start_time = std::chrono::high_resolution_clock::now();
    int num_biomes = static_cast<int>(m_sliced_state.biome_rhos.size());
    if (num_biomes > static_cast<int>(m_engines.size())) {
        num_biomes = static_cast<int>(m_engines.size());
    }

    // Process steps until time budget exhausted or computation complete
    while (m_sliced_state.current_biome < num_biomes) {
        // Check time budget
        auto now = std::chrono::high_resolution_clock::now();
        auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - start_time).count();
        if (elapsed_ms >= max_time_ms) {
            // Time budget exhausted - yield
            return false;
        }

        // Do one step
        bool biome_complete = _do_one_sliced_step();

        if (biome_complete) {
            // Move to next biome
            m_sliced_state.current_biome++;
            m_sliced_state.current_step = 0;

            if (m_sliced_state.current_biome < num_biomes) {
                // Initialize next biome
                m_sliced_state.current_rho = m_sliced_state.biome_rhos[m_sliced_state.current_biome];
            }
        }
    }

    // All biomes complete - finalize
    m_sliced_state.complete = true;
    m_sliced_state.in_progress = false;

    // Build icon maps for all biomes
    for (int i = 0; i < num_biomes; i++) {
        m_sliced_state.biome_results[i].icon_map =
            _build_icon_map(i, m_sliced_state.biome_results[i].bloch_steps);
    }

    return true;
}

bool MultiBiomeLookaheadEngine::_do_one_sliced_step() {
    int biome_id = m_sliced_state.current_biome;
    int step = m_sliced_state.current_step;

    if (biome_id >= static_cast<int>(m_engines.size())) {
        return true;  // Invalid biome, skip
    }

    Ref<QuantumEvolutionEngine> engine = m_engines[biome_id];
    int num_qubits = m_num_qubits[biome_id];
    BiomeStepResult& result = m_sliced_state.biome_results[biome_id];

    // Evolve one step
    PackedFloat64Array evolved_rho = engine->evolve(
        m_sliced_state.current_rho,
        m_sliced_state.dt,
        m_sliced_state.max_dt
    );

    // Apply LNN phase modulation if enabled
    _apply_lnn_phase_modulation(biome_id, evolved_rho);

    // Store results
    result.steps.push_back(evolved_rho);
    result.bloch_steps.push_back(
        engine->compute_bloch_metrics_from_packed(evolved_rho, num_qubits));

    double purity = engine->compute_purity_from_packed(evolved_rho);
    result.purity_steps.push_back(purity);

    // Adaptive MI computation (full scan on first step only)
    bool force_full_scan = (step == 0);
    result.mi_steps.push_back(
        engine->compute_mi_adaptive(evolved_rho, num_qubits, purity, force_full_scan));

    // Update state for next step
    m_sliced_state.current_rho = evolved_rho;
    m_sliced_state.current_step++;

    // Check if this biome is complete
    return (m_sliced_state.current_step >= m_sliced_state.total_steps);
}

bool MultiBiomeLookaheadEngine::is_sliced_compute_complete() const {
    return m_sliced_state.complete || !m_sliced_state.in_progress;
}

Dictionary MultiBiomeLookaheadEngine::get_sliced_compute_result() {
    Dictionary result;

    if (!m_sliced_state.complete) {
        UtilityFunctions::push_warning(
            "MultiBiomeLookaheadEngine: get_sliced_compute_result called before completion");
        return result;
    }

    Array all_results;
    Array all_mi;
    Array all_mi_steps;
    Array all_bloch_steps;
    Array all_purity_steps;
    Array all_metadata;
    Array all_couplings;
    Array all_icon_maps;

    int num_biomes = static_cast<int>(m_sliced_state.biome_results.size());

    for (int biome_id = 0; biome_id < num_biomes; biome_id++) {
        const BiomeStepResult& biome_result = m_sliced_state.biome_results[biome_id];

        // Convert steps to Godot Array
        Array biome_steps;
        for (const auto& step_rho : biome_result.steps) {
            biome_steps.push_back(step_rho);
        }
        all_results.push_back(biome_steps);

        // MI steps
        Array biome_mi_steps;
        for (const auto& mi_step : biome_result.mi_steps) {
            biome_mi_steps.push_back(mi_step);
        }
        all_mi_steps.push_back(biome_mi_steps);
        if (!biome_result.mi_steps.empty()) {
            all_mi.push_back(biome_result.mi_steps.back());
        } else {
            all_mi.push_back(PackedFloat64Array());
        }

        // Bloch steps
        Array biome_bloch_steps;
        for (const auto& bloch_step : biome_result.bloch_steps) {
            biome_bloch_steps.push_back(bloch_step);
        }
        all_bloch_steps.push_back(biome_bloch_steps);

        // Purity steps
        Array biome_purity_steps;
        for (double purity_val : biome_result.purity_steps) {
            biome_purity_steps.push_back(purity_val);
        }
        all_purity_steps.push_back(biome_purity_steps);

        // Metadata
        if (biome_id < static_cast<int>(m_metadata.size())) {
            all_metadata.push_back(m_metadata[biome_id]);
        } else {
            all_metadata.push_back(Dictionary());
        }

        // Couplings
        if (biome_id < static_cast<int>(m_couplings.size())) {
            all_couplings.push_back(m_couplings[biome_id]);
        } else {
            all_couplings.push_back(Dictionary());
        }

        // Icon maps
        all_icon_maps.push_back(biome_result.icon_map);
    }

    result["results"] = all_results;
    result["mi"] = all_mi;
    result["mi_steps"] = all_mi_steps;
    result["bloch_steps"] = all_bloch_steps;
    result["purity_steps"] = all_purity_steps;
    result["metadata"] = all_metadata;
    result["couplings"] = all_couplings;
    result["icon_maps"] = all_icon_maps;

    // Clear state after retrieving result
    m_sliced_state.reset();

    return result;
}

void MultiBiomeLookaheadEngine::cancel_sliced_compute() {
    m_sliced_state.reset();
}

float MultiBiomeLookaheadEngine::get_sliced_compute_progress() const {
    if (!m_sliced_state.in_progress) {
        return m_sliced_state.complete ? 1.0f : 0.0f;
    }

    int num_biomes = static_cast<int>(m_sliced_state.biome_rhos.size());
    if (num_biomes > static_cast<int>(m_engines.size())) {
        num_biomes = static_cast<int>(m_engines.size());
    }

    if (num_biomes == 0 || m_sliced_state.total_steps == 0) {
        return 1.0f;
    }

    int total_work = num_biomes * m_sliced_state.total_steps;
    int completed_work = m_sliced_state.current_biome * m_sliced_state.total_steps
                       + m_sliced_state.current_step;

    return static_cast<float>(completed_work) / static_cast<float>(total_work);
}
