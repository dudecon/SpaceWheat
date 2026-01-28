extends Node

func _ready():
	var diag = load("res://Tests/test_quantum_visualization_diagnostics.gd").new()
	add_child(diag)
