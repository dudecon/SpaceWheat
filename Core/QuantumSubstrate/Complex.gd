class_name Complex
extends RefCounted

## Complex number representation for quantum amplitudes
## Used throughout the bath-first quantum mechanics system

var re: float = 0.0  # Real part
var im: float = 0.0  # Imaginary part

func _init(real: float = 0.0, imag: float = 0.0):
	re = real
	im = imag

## Magnitude squared: |z|² = re² + im²
func abs_sq() -> float:
	return re * re + im * im

## Magnitude: |z| = √(re² + im²)
func abs() -> float:
	return sqrt(abs_sq())

## Phase angle: arg(z) = atan2(im, re)
func arg() -> float:
	return atan2(im, re)

## Complex conjugate: z* = re - i·im
func conjugate():
	return get_script().new(re, -im)

## Addition: z1 + z2
func add(other: Complex):
	return get_script().new(re + other.re, im + other.im)

## Subtraction: z1 - z2
func sub(other: Complex):
	return get_script().new(re - other.re, im - other.im)

## Multiplication: z1 × z2 = (a+bi)(c+di) = (ac-bd) + (ad+bc)i
func mul(other: Complex):
	return get_script().new(
		re * other.re - im * other.im,
		re * other.im + im * other.re
	)

## Division: z1 / z2
func div(other: Complex):
	var denom = other.abs_sq()
	if denom < 1e-20:
		push_error("Complex division by zero")
		return get_script().new(0.0, 0.0)
	var conj = other.conjugate()
	var num = mul(conj)
	return get_script().new(num.re / denom, num.im / denom)

## Scalar multiplication: s × z
func scale(s: float):
	return get_script().new(re * s, im * s)

## ========================================
## Static Factory Methods (Lazy Singleton Pattern)
## ========================================
## These use lazy loading to avoid circular dependency issues
## Instances are cached for performance

static var _zero_instance = null
static var _one_instance = null
static var _i_instance = null

## Zero
static func zero():
	if _zero_instance == null:
		var script = load("res://Core/QuantumSubstrate/Complex.gd")
		_zero_instance = script.new(0.0, 0.0)
	return _zero_instance

## One
static func one():
	if _one_instance == null:
		var script = load("res://Core/QuantumSubstrate/Complex.gd")
		_one_instance = script.new(1.0, 0.0)
	return _one_instance

## Imaginary unit: i
static func i():
	if _i_instance == null:
		var script = load("res://Core/QuantumSubstrate/Complex.gd")
		_i_instance = script.new(0.0, 1.0)
	return _i_instance

## Create from polar coordinates: r × e^(iθ) = r(cos θ + i sin θ)
static func from_polar(r: float, theta: float):
	var script = load("res://Core/QuantumSubstrate/Complex.gd")
	return script.new(r * cos(theta), r * sin(theta))

## String representation for debugging
func _to_string() -> String:
	if abs(im) < 1e-10:
		return "%.4f" % re
	elif abs(re) < 1e-10:
		return "%.4fi" % im
	elif im >= 0:
		return "%.4f+%.4fi" % [re, im]
	else:
		return "%.4f%.4fi" % [re, im]

## Equality check with tolerance
func equals(other: Complex, tolerance: float = 1e-10) -> bool:
	return abs(re - other.re) < tolerance and abs(im - other.im) < tolerance
