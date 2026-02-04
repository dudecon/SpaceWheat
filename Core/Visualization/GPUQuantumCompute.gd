## GPUQuantumCompute - Godot 4 RenderingDevice wrapper for quantum calculations
##
## Provides async GPU compute for:
## - Mutual Information (MI) calculations
## - Force graph physics
##
## Uses Vulkan compute shaders, with automatic fallback to CPU if GPU unavailable.

extends Node

class_name GPUQuantumCompute

## RenderingDevice for GPU compute
var rd: RenderingDevice = null
var gpu_available: bool = false

## Shader pipelines
var mi_pipeline: RID = RID()
var force_pipeline: RID = RID()
var shadow_pipeline: RID = RID()

## Storage buffers (GPU-side)
var _mi_buffer: RID = RID()
var _rho_buffer: RID = RID()
var _bloch_buffer: RID = RID()
var _force_input_buffer: RID = RID()
var _force_output_buffer: RID = RID()

## Query results (async fetch)
var _mi_query_pending: bool = false
var _force_query_pending: bool = false

func _ready():
	"""Initialize GPU compute if available."""
	if not _init_gpu_compute():
		push_warning("GPUQuantumCompute: GPU unavailable, using CPU fallback")
		gpu_available = false
	else:
		gpu_available = true
		print("GPUQuantumCompute: GPU acceleration enabled (Vulkan compute)")


func _init_gpu_compute() -> bool:
	"""Initialize RenderingDevice and compile shaders."""
	# Create local rendering device for compute
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		return false

	# Compile MI shader
	if not _compile_shader("mi"):
		return false

	# Compile force shader
	if not _compile_shader("force"):
		return false

	# Compile shadow influence shader
	if not _compile_shader("shadow"):
		push_warning("GPUQuantumCompute: Shadow shader not available, will skip shadow influences")

	return true


func _compile_shader(shader_type: String) -> bool:
	"""Compile compute shader and create pipeline."""
	var shader_path = "res://shaders/compute_%s.glsl" % shader_type

	if not ResourceLoader.exists(shader_path):
		push_error("Shader not found: %s" % shader_path)
		return false

	var shader_source = load(shader_path)
	if not shader_source:
		return false

	# Create shader from source
	var shader_spirv: RDShaderSPIRV = shader_source.get_spirv()
	if not shader_spirv or shader_spirv.get_spirv().is_empty():
		push_error("Failed to compile %s shader" % shader_type)
		return false

	# Create pipeline
	match shader_type:
		"mi":
			var shader_rid = rd.shader_create_from_spirv(shader_spirv)
			mi_pipeline = rd.compute_pipeline_create(shader_rid)
			return mi_pipeline != RID()

		"force":
			var shader_rid = rd.shader_create_from_spirv(shader_spirv)
			force_pipeline = rd.compute_pipeline_create(shader_rid)
			return force_pipeline != RID()

		"shadow":
			var shader_rid = rd.shader_create_from_spirv(shader_spirv)
			shadow_pipeline = rd.compute_pipeline_create(shader_rid)
			return shadow_pipeline != RID()

	return false


## =============================================================================
## MUTUAL INFORMATION GPU COMPUTATION
## =============================================================================

func compute_mi_gpu(
	rho_packed: PackedFloat64Array,
	num_qubits: int
) -> PackedFloat64Array:
	"""Compute mutual information on GPU (async).

	Args:
		rho_packed: Density matrix as packed floats [re_ij, im_ij, ...]
		num_qubits: Number of qubits

	Returns:
		MI values (upper triangular): [mi_01, mi_02, ..., mi_{n-1,n}]
		Returns empty array if GPU computation not available.
	"""

	if not gpu_available:
		return PackedFloat64Array()

	var dim = 1 << num_qubits  # 2^n
	var num_mi_pairs = num_qubits * (num_qubits - 1) / 2

	# Create/update GPU buffers
	if rho_packed.size() != dim * dim * 2:
		push_error("Invalid density matrix size")
		return PackedFloat64Array()

	# Upload density matrix
	var rho_bytes = _pack_float64_array_to_bytes(rho_packed)
	if _rho_buffer == RID():
		_rho_buffer = rd.storage_buffer_create(rho_bytes.size(), rho_bytes)
	else:
		rd.buffer_update(_rho_buffer, 0, rho_bytes.size(), rho_bytes)

	# Create MI output buffer if needed
	if _mi_buffer == RID():
		var mi_size = num_mi_pairs * 8  # float64 per pair
		_mi_buffer = rd.storage_buffer_create(mi_size, PackedByteArray())

	# Set up compute uniforms
	var uniforms = [
		RDUniform.new(),
		RDUniform.new(),
		RDUniform.new(),
	]
	uniforms[0].uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniforms[0].binding = 0
	uniforms[0].add_id(_rho_buffer)

	uniforms[1].uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniforms[1].binding = 1
	uniforms[1].add_id(_mi_buffer)

	# Push constants: num_qubits, dim
	var push_constant = PackedInt32Array([num_qubits, dim])
	var push_constant_bytes = push_constant.to_byte_array()

	# Create uniform set
	var uniform_set = rd.uniform_set_create(uniforms, mi_pipeline, 0)

	# Dispatch compute
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(
		compute_list,
		push_constant_bytes,
		push_constant_bytes.size()
	)

	# Dispatch: one thread per MI pair (276 max for 24 qubits)
	var workgroup_count = ceili(float(num_mi_pairs) / 32.0)  # 32 threads per workgroup
	rd.compute_list_dispatch(compute_list, workgroup_count, 1, 1)
	rd.compute_list_end()

	# Wait for compute to finish (TODO: make async)
	rd.submit()
	rd.sync()

	# Read back results
	var mi_bytes = rd.buffer_get_data(_mi_buffer)
	return _unpack_float64_from_bytes(mi_bytes, num_mi_pairs)


## =============================================================================
## FORCE GRAPH GPU COMPUTATION
## =============================================================================

func compute_forces_gpu(
	positions: PackedVector2Array,
	velocities: PackedVector2Array,
	mi_values: PackedFloat64Array,
	bloch_packet: PackedFloat64Array,
	num_qubits: int,
	biome_center: Vector2,
	delta: float,
	config: Dictionary = {}
) -> Dictionary:
	"""Compute force graph on GPU.

	Args:
		positions: Current node positions
		velocities: Current node velocities
		mi_values: Mutual information matrix (upper triangular)
		bloch_packet: Bloch vector data [x, y, z, r] per qubit
		num_qubits: Number of qubits
		biome_center: Center position of biome
		delta: Timestep
		config: Configuration dict with force constants

	Returns:
		{
			"positions": PackedVector2Array (updated),
			"velocities": PackedVector2Array (updated)
		}
	"""

	if not gpu_available or positions.is_empty():
		return {}

	var num_nodes = positions.size()

	# Get configuration (use defaults if not provided)
	var purity_radial_spring = config.get("purity_radial_spring", 0.08)
	var phase_angular_spring = config.get("phase_angular_spring", 0.04)
	var correlation_spring = config.get("correlation_spring", 0.12)
	var repulsion_strength = config.get("repulsion_strength", 1500.0)
	var damping = config.get("damping", 0.89)
	var base_distance = config.get("base_distance", 120.0)
	var min_distance = config.get("min_distance", 15.0)

	# Create frozen mask (all nodes free for now)
	var frozen_mask = PackedByteArray()
	for _i in range(num_nodes):
		frozen_mask.append(0)

	# Pack all input data to bytes
	var pos_bytes = _pack_vector2_array_to_bytes(positions)
	var vel_bytes = _pack_vector2_array_to_bytes(velocities)
	var mi_bytes = _pack_float64_array_to_bytes(mi_values)
	var bloch_bytes = _pack_float64_array_to_bytes(bloch_packet)
	var frozen_bytes = frozen_mask

	# Create/update input buffers
	var pos_buffer = rd.storage_buffer_create(pos_bytes.size(), pos_bytes)
	var vel_buffer = rd.storage_buffer_create(vel_bytes.size(), vel_bytes)
	var mi_buffer = rd.storage_buffer_create(mi_bytes.size(), mi_bytes)
	var bloch_buffer = rd.storage_buffer_create(bloch_bytes.size(), bloch_bytes)
	var frozen_buffer = rd.storage_buffer_create(frozen_bytes.size(), frozen_bytes)

	# Create output buffers
	var out_pos_buffer = rd.storage_buffer_create(pos_bytes.size())
	var out_vel_buffer = rd.storage_buffer_create(vel_bytes.size())

	# Set up uniform set
	var uniforms = [
		RDUniform.new(),
		RDUniform.new(),
		RDUniform.new(),
		RDUniform.new(),
		RDUniform.new(),
		RDUniform.new(),
		RDUniform.new(),
	]

	for i in range(uniforms.size()):
		uniforms[i].uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		uniforms[i].binding = i

	uniforms[0].add_id(pos_buffer)
	uniforms[1].add_id(vel_buffer)
	uniforms[2].add_id(mi_buffer)
	uniforms[3].add_id(bloch_buffer)
	uniforms[4].add_id(frozen_buffer)
	uniforms[5].add_id(out_pos_buffer)
	uniforms[6].add_id(out_vel_buffer)

	var uniform_set = rd.uniform_set_create(uniforms, force_pipeline, 0)

	# Pack push constants
	var push_const = PackedFloat32Array([
		biome_center.x, biome_center.y,  # vec2 biome_center
		delta,                            # float dt
		float(num_nodes),                 # uint num_nodes
		float(num_qubits),                # uint num_qubits
		purity_radial_spring,             # float purity_radial_spring
		phase_angular_spring,             # float phase_angular_spring
		correlation_spring,               # float correlation_spring
		repulsion_strength,               # float repulsion_strength
		damping,                          # float damping
		base_distance,                    # float base_distance
		min_distance,                     # float min_distance
	])

	# Dispatch compute shader
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(
		compute_list,
		push_const.to_byte_array(),
		push_const.to_byte_array().size()
	)

	# Workgroups: 24 threads per group (one per node), 1 group
	var workgroup_count = ceili(float(num_nodes) / 24.0)
	rd.compute_list_dispatch(compute_list, workgroup_count, 1, 1)
	rd.compute_list_end()

	# Submit and wait
	rd.submit()
	rd.sync()

	# Read back results
	var new_pos_bytes = rd.buffer_get_data(out_pos_buffer)
	var new_vel_bytes = rd.buffer_get_data(out_vel_buffer)

	var new_positions = _unpack_vector2_from_bytes(new_pos_bytes)
	var new_velocities = _unpack_vector2_from_bytes(new_vel_bytes)

	# Clean up temporary buffers
	rd.free_rid(pos_buffer)
	rd.free_rid(vel_buffer)
	rd.free_rid(mi_buffer)
	rd.free_rid(bloch_buffer)
	rd.free_rid(frozen_buffer)
	rd.free_rid(out_pos_buffer)
	rd.free_rid(out_vel_buffer)

	return {
		"positions": new_positions,
		"velocities": new_velocities
	}


## =============================================================================
## SHADOW INFLUENCE GPU COMPUTATION
## =============================================================================

func compute_shadow_gpu(
	positions: PackedVector2Array,
	phi_values: PackedFloat32Array,
	season_projections: Array,  # Array of [r, g, b, coherence] per node
	coupling_matrix: PackedFloat32Array,  # N×N flattened
	max_distance: float = 300.0,
	wedge_half_angle: float = 0.523599  # 30 degrees in radians
) -> Array:
	"""Compute shadow influences on GPU.

	Args:
		positions: Node positions
		phi_values: Raw phase angles per node
		season_projections: Array of [r, g, b, coherence] arrays per node
		coupling_matrix: N×N coupling strengths (flattened row-major)
		max_distance: Maximum influence distance
		wedge_half_angle: Half-angle of wedge cone in radians

	Returns:
		Array of {tint: Color, strength: float} per node
		Returns empty array if GPU unavailable.
	"""
	if not gpu_available or shadow_pipeline == RID():
		return []

	var num_nodes = positions.size()
	if num_nodes == 0:
		return []

	# Pack season projections to vec4 array (xyz = rgb, w = coherence)
	var season_packed = PackedFloat32Array()
	for i in range(num_nodes):
		if i < season_projections.size():
			var proj = season_projections[i]
			season_packed.append(proj[0] if proj.size() > 0 else 0.5)  # r
			season_packed.append(proj[1] if proj.size() > 1 else 0.5)  # g
			season_packed.append(proj[2] if proj.size() > 2 else 0.5)  # b
			season_packed.append(proj[3] if proj.size() > 3 else 0.5)  # coherence
		else:
			season_packed.append_array([0.5, 0.5, 0.5, 0.0])

	# Pack positions as float pairs
	var pos_packed = PackedFloat32Array()
	for p in positions:
		pos_packed.append(p.x)
		pos_packed.append(p.y)

	# Convert to bytes
	var pos_bytes = pos_packed.to_byte_array()
	var phi_bytes = phi_values.to_byte_array()
	var season_bytes = season_packed.to_byte_array()
	var coupling_bytes = coupling_matrix.to_byte_array()

	# Create buffers
	var pos_buffer = rd.storage_buffer_create(pos_bytes.size(), pos_bytes)
	var phi_buffer = rd.storage_buffer_create(phi_bytes.size(), phi_bytes)
	var season_buffer = rd.storage_buffer_create(season_bytes.size(), season_bytes)
	var coupling_buffer = rd.storage_buffer_create(coupling_bytes.size(), coupling_bytes)

	# Output buffer: vec4 per node (rgb tint + strength)
	var output_size = num_nodes * 4 * 4  # 4 floats × 4 bytes each
	var output_buffer = rd.storage_buffer_create(output_size)

	# Set up uniforms
	var uniforms = []
	for i in range(5):
		var u = RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.binding = i
		uniforms.append(u)

	uniforms[0].add_id(pos_buffer)
	uniforms[1].add_id(phi_buffer)
	uniforms[2].add_id(season_buffer)
	uniforms[3].add_id(coupling_buffer)
	uniforms[4].add_id(output_buffer)

	var uniform_set = rd.uniform_set_create(uniforms, shadow_pipeline, 0)

	# Push constants
	var push_const = PackedFloat32Array([
		float(num_nodes),
		max_distance,
		wedge_half_angle,
		0.0  # padding for alignment
	])
	# Repack as uint + 2 floats to match shader layout
	var push_bytes = PackedByteArray()
	push_bytes.append_array(PackedInt32Array([num_nodes]).to_byte_array())
	push_bytes.append_array(PackedFloat32Array([max_distance, wedge_half_angle]).to_byte_array())

	# Dispatch compute
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_bytes, push_bytes.size())

	var workgroup_count = ceili(float(num_nodes) / 32.0)
	rd.compute_list_dispatch(compute_list, workgroup_count, 1, 1)
	rd.compute_list_end()

	# Submit and wait
	rd.submit()
	rd.sync()

	# Read back results
	var result_bytes = rd.buffer_get_data(output_buffer)
	var result_floats = result_bytes.to_float32_array()

	# Convert to array of dictionaries
	var results = []
	for i in range(num_nodes):
		var base = i * 4
		if base + 3 < result_floats.size():
			results.append({
				"tint": Color(result_floats[base], result_floats[base + 1], result_floats[base + 2]),
				"strength": result_floats[base + 3]
			})
		else:
			results.append({"tint": Color.WHITE, "strength": 0.0})

	# Clean up buffers
	rd.free_rid(pos_buffer)
	rd.free_rid(phi_buffer)
	rd.free_rid(season_buffer)
	rd.free_rid(coupling_buffer)
	rd.free_rid(output_buffer)

	return results


## =============================================================================
## HELPER FUNCTIONS
## =============================================================================

func _pack_float64_array_to_bytes(arr: PackedFloat64Array) -> PackedByteArray:
	"""Convert PackedFloat64Array to bytes."""
	var bytes = PackedByteArray()
	for val in arr:
		bytes.append_array(var_to_bytes(val))
	return bytes


func _unpack_float64_from_bytes(bytes: PackedByteArray, count: int) -> PackedFloat64Array:
	"""Convert bytes back to PackedFloat64Array."""
	var result = PackedFloat64Array()
	var pos = 0
	for _i in range(count):
		if pos + 8 <= bytes.size():
			var val = bytes_to_var(bytes.slice(pos, pos + 8))
			result.append(val as float)
			pos += 8
	return result


func _pack_vector2_array_to_bytes(arr: PackedVector2Array) -> PackedByteArray:
	"""Convert PackedVector2Array to bytes."""
	var bytes = PackedByteArray()
	for vec in arr:
		bytes.append_array(var_to_bytes(vec))
	return bytes


func _unpack_vector2_from_bytes(bytes: PackedByteArray) -> PackedVector2Array:
	"""Convert bytes back to PackedVector2Array."""
	var result = PackedVector2Array()
	var pos = 0
	while pos + 16 <= bytes.size():  # Vector2 = 2 × float32 = 8 bytes, but might be padded
		var vec = bytes_to_var(bytes.slice(pos, pos + 8))
		if vec is Vector2:
			result.append(vec)
			pos += 8
		else:
			break
	return result


func cleanup():
	"""Clean up GPU resources."""
	if rd:
		if _mi_buffer != RID():
			rd.free_rid(_mi_buffer)
		if _rho_buffer != RID():
			rd.free_rid(_rho_buffer)
		if _bloch_buffer != RID():
			rd.free_rid(_bloch_buffer)
		if _force_input_buffer != RID():
			rd.free_rid(_force_input_buffer)
		if _force_output_buffer != RID():
			rd.free_rid(_force_output_buffer)

		rd.free()
		rd = null
