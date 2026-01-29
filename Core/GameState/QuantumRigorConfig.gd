class_name QuantumRigorConfig
extends Resource

## Quantum Rigor Configuration
## Controls the mathematical rigor of quantum operations
## Switches between educational (KID_LIGHT) and rigorous (LAB_TRUE) modes

enum ReadoutMode {
	HARDWARE,   # Simulates real quantum hardware imperfections
	INSPECTOR   # Idealized readout (default, for gameplay)
}

enum BackactionMode {
	KID_LIGHT,  # Weak measurement: collapse_strength = 0.5
	LAB_TRUE    # Projective measurement: collapse_strength = 1.0 (strict Manifest compliance)
}

enum SelectiveMeasureModel {
	POSTSELECT_COSTED,  # Measurement cost scales as 1/p_subspace (NOT IMPLEMENTED - UI only)
	CLICK_NOCLICK       # Binary success/failure (NOT IMPLEMENTED - UI only)
}

# Current configuration
@export var readout_mode: ReadoutMode = ReadoutMode.INSPECTOR
@export var backaction_mode: BackactionMode = BackactionMode.KID_LIGHT
@export var selective_measure_model: SelectiveMeasureModel = SelectiveMeasureModel.POSTSELECT_COSTED

# Debug and invariant checking
@export var enable_invariant_checks: bool = false  # Enable per-frame ρ validation (slow)
@export var enable_trace_warnings: bool = true     # Warn on trace violations

# Singleton pattern
static var instance: QuantumRigorConfig = null

func _init(p_readout: ReadoutMode = ReadoutMode.INSPECTOR,
           p_backaction: BackactionMode = BackactionMode.KID_LIGHT,
           p_selective: SelectiveMeasureModel = SelectiveMeasureModel.POSTSELECT_COSTED):
	readout_mode = p_readout
	backaction_mode = p_backaction
	selective_measure_model = p_selective

	if instance == null:
		instance = self


func is_lab_true_mode() -> bool:
	"""Check if running in strict mathematical mode"""
	return backaction_mode == BackactionMode.LAB_TRUE


func get_collapse_strength() -> float:
	"""Return collapse strength based on backaction mode

	KID_LIGHT: 0.5 (weak measurement, gentler on quantum coherence)
	LAB_TRUE: 1.0 (projective measurement, strict compliance)
	"""
	match backaction_mode:
		BackactionMode.LAB_TRUE:
			return 1.0
		BackactionMode.KID_LIGHT:
			return 0.5
		_:
			return 0.5


func mode_description() -> String:
	"""Human-readable description of current configuration"""
	var desc = ""
	desc += "Readout: %s\n" % ["HARDWARE", "INSPECTOR"][readout_mode]
	desc += "Backaction: %s (collapse_strength=%.1f)\n" % [
		["KID_LIGHT", "LAB_TRUE"][backaction_mode],
		get_collapse_strength()
	]
	desc += "Selective Measure: %s" % ["POSTSELECT_COSTED", "CLICK_NOCLICK"][selective_measure_model]
	return desc
