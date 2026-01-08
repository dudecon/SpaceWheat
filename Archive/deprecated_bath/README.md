# Deprecated Bath System

This folder contains the old QuantumBath-based quantum simulation code that has been replaced by the unified QuantumComputer + RegisterMap architecture.

## What was deprecated

- **QuantumBath.gd** - N-state density matrix with flat basis (emoji → index mapping)
- **BiomeBase_with_bath.gd** - Old BiomeBase with dual bath/quantum_computer code paths
- **BathQuantumVisualizationController.gd** - Visualization controller for bath system
- **QuantumBathTest.gd** - Unit tests for QuantumBath
- **BathForceGraphTest.gd** - Force graph test for bath

## Why it was deprecated

The project had three parallel quantum models:
- **Model A (Legacy)**: Per-plot independent qubits (fully deprecated earlier)
- **Model B (bath)**: QuantumBath with flat N-state basis
- **Model C (density)**: QuantumComputer with RegisterMap (qubit tensor product)

Model C was chosen as the unified architecture because:
1. **Physics accuracy**: Proper qubit tensor product structure (2^n states)
2. **Faction+Icon integration**: Icons define Hamiltonian/Lindblad terms via HamiltonianBuilder/LindbladBuilder
3. **Cleaner API**: RegisterMap provides emoji → qubit coordinate mapping
4. **Single code path**: No more dual bath/quantum_computer conditionals

## Migration Summary

| Biome | Old System | New System |
|-------|------------|------------|
| BioticFlux | quantum_computer (3 qubits) | quantum_computer (3 qubits) |
| Kitchen | quantum_computer (3 qubits) | quantum_computer (3 qubits) |
| Market | bath (8 states) | quantum_computer (3 qubits) |
| Forest | bath (22 states) | quantum_computer (5 qubits) |

## Date Deprecated

2026-01-07

## Files Still Using bath Variable

The `bath` variable is kept in BiomeBase as `null` for compile compatibility. All biomes now use `quantum_computer` exclusively.
