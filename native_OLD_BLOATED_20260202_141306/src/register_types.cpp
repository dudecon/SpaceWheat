#include "register_types.h"
#include "quantum_matrix_native.h"
#include "quantum_evolution_engine.h"        // RE-ENABLED: Pure CPU Eigen code
#include "multi_biome_lookahead_engine.h"    // RE-ENABLED: Pure CPU Eigen code
#include "force_graph_engine.h"              // NEW: Native force graph calculations
// DISABLED: batched_bubble_renderer.h - BubbleAtlasBatcher.gd always used instead
#include "parametric_selector_native.h"      // NEW: Fast parametric music selection (100× speedup)

// DISABLED HEADERS: GPU-dependent and dead code classes
// #include "quantum_sparse_native.h"
// #include "liquid_neural_net_native.h"
// #include "quantum_solver_cpu_native.h"  // Dead: LNN now in QuantumComputer._apply_phase_lnn()

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_quantum_matrix_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    // Core CPU-based classes
    ClassDB::register_class<QuantumMatrixNative>();

    // RE-ENABLED: Pure CPU evolution engines (10-20× speedup via Eigen)
    ClassDB::register_class<QuantumEvolutionEngine>();
    ClassDB::register_class<MultiBiomeLookaheadEngine>();

    // NEW: Native force graph calculations (3-5× speedup)
    ClassDB::register_class<ForceGraphEngine>();

    // DISABLED: NativeBubbleRenderer - BubbleAtlasBatcher.gd (GPU atlas) always used instead
    // ClassDB::register_class<NativeBubbleRenderer>();

    // NEW: Fast parametric selection for music Layer 4/5 (100× speedup over GDScript)
    ClassDB::register_class<ParametricSelectorNative>();

    // DISABLED: Causes crashes in WSL due to platform/GPU dependencies
    // - QuantumSolverCPUNative (replaced by integrated QuantumComputer._apply_phase_lnn)
    // - QuantumSparseMatrixNative (GPU-optimized)
    // - LiquidNeuralNetNative (loads GPU code during init)
}

void uninitialize_quantum_matrix_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
    GDExtensionBool GDE_EXPORT quantum_matrix_library_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        const GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization
    ) {
        godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

        init_obj.register_initializer(initialize_quantum_matrix_module);
        init_obj.register_terminator(uninitialize_quantum_matrix_module);
        init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

        return init_obj.init();
    }
}
