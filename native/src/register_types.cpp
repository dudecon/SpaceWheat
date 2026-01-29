#include "register_types.h"
#include "quantum_matrix_native.h"
#include "quantum_sparse_native.h"
#include "quantum_evolution_engine.h"
#include "batched_bubble_renderer.h"
#include "multi_biome_lookahead_engine.h"
#include "liquid_neural_net_native.h"
#include "quantum_solver_cpu_native.h"

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
    ClassDB::register_class<MultiBiomeLookaheadEngine>();
    ClassDB::register_class<QuantumSolverCPUNative>();

    // DISABLED: Graphics/GPU classes that crash in WSL without GPU
    // - QuantumSparseMatrixNative (GPU-optimized)
    // - QuantumEvolutionEngine (GPU pipeline)
    // - NativeBubbleRenderer (GL rendering)
    // - LiquidNeuralNetNative (loads GPU code during init)
    //
    // These cause signal 11 crashes in swrast_dri.so/libd3d12core.so
    // when native extensions are loaded in WSL. Re-enable when:
    // 1. Running on hardware with proper GPU support, or
    // 2. WSL graphics drivers are fixed
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
