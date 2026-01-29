#include "register_types.h"
#include "quantum_matrix_native.h"
// #include "multi_biome_lookahead_engine.h"  // DISABLED: Crashes in WSL

// DISABLED HEADERS: GPU-dependent and dead code classes
// #include "quantum_sparse_native.h"
// #include "quantum_evolution_engine.h"
// #include "batched_bubble_renderer.h"
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

    // Core CPU-based classes only
    ClassDB::register_class<QuantumMatrixNative>();
    // ClassDB::register_class<MultiBiomeLookaheadEngine>();  // DISABLED: Crashes in WSL

    // DISABLED: Causes crashes in WSL due to platform dependencies
    // - MultiBiomeLookaheadEngine (platform-specific initialization)
    // - QuantumSolverCPUNative (replaced by integrated QuantumComputer._apply_phase_lnn)
    // - QuantumSparseMatrixNative (GPU-optimized)
    // - QuantumEvolutionEngine (GPU pipeline)
    // - NativeBubbleRenderer (GL rendering)
    // - LiquidNeuralNetNative (loads GPU code during init)
    //
    // All evolution now uses pure GDScript CPU path (QuantumComputer._evolve_step)
    // ComplexMatrix native acceleration provides matrix operations only.
    // Keep C++ files for reference but don't register them.
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
