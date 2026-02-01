## GPUForceCalculator - Offload force calculations to GPU via RenderingDevice
##
## Computes force-directed physics for quantum nodes on GPU compute shader.
## One compute shader invocation per node, perfect parallelization.

extends RefCounted

class_name GPUForceCalculator

# Shared shader cache (class-level) to avoid recompilation
static var _shared_shader: RID = RID()
static var _shared_pipeline: RID = RID()
static var _shared_rd: RenderingDevice = null
static var _shader_compiled: bool = false

var rd: RenderingDevice = null
var gpu_available: bool = false

var force_shader: RID = RID()     # Shader RID (needed for uniform set creation)
var force_pipeline: RID = RID()   # Pipeline RID (needed for dispatch)
var position_buffer: RID = RID()
var velocity_buffer: RID = RID()
var mi_buffer: RID = RID()
var bloch_buffer: RID = RID()
var frozen_buffer: RID = RID()
var out_position_buffer: RID = RID()
var out_velocity_buffer: RID = RID()

func _init():
	"""Initialize GPU compute on construction."""
	_init_gpu()

static func pre_compile_shader() -> Dictionary:
	"""Pre-compile shader at boot time (called once, shared by all instances).

	Returns: {success: bool, device_name: String, message: String, duration_ms: float}
	"""
	if _shader_compiled:
		return {
			"success": true,
			"device_name": _shared_rd.get_device_name() if _shared_rd else "unknown",
			"message": "Shader already compiled (cached)",
			"duration_ms": 0.0
		}

	var start_time = Time.get_ticks_msec()

	# Create shared rendering device
	_shared_rd = RenderingServer.create_local_rendering_device()
	if not _shared_rd:
		return {
			"success": false,
			"device_name": "unknown",
			"message": "Failed to create RenderingDevice",
			"duration_ms": 0.0
		}

	var device_name = _shared_rd.get_device_name()

	# Compile shader
	var shader_code = _get_force_shader_glsl_static()
	var rd_shader_source = RDShaderSource.new()
	rd_shader_source.source_compute = shader_code

	var shader_spirv = _shared_rd.shader_compile_spirv_from_source(rd_shader_source)
	if shader_spirv.compile_error_compute != "":
		_shared_rd.free()
		_shared_rd = null
		return {
			"success": false,
			"device_name": device_name,
			"message": "Shader compile error: %s" % shader_spirv.compile_error_compute,
			"duration_ms": Time.get_ticks_msec() - start_time
		}

	# Create shader RID
	_shared_shader = _shared_rd.shader_create_from_spirv(shader_spirv)
	if _shared_shader == RID():
		_shared_rd.free()
		_shared_rd = null
		return {
			"success": false,
			"device_name": device_name,
			"message": "Failed to create shader RID",
			"duration_ms": Time.get_ticks_msec() - start_time
		}

	# Create pipeline
	_shared_pipeline = _shared_rd.compute_pipeline_create(_shared_shader)
	if _shared_pipeline == RID():
		_shared_rd.free_rid(_shared_shader)
		_shared_rd.free()
		_shared_rd = null
		_shared_shader = RID()
		return {
			"success": false,
			"device_name": device_name,
			"message": "Failed to create compute pipeline",
			"duration_ms": Time.get_ticks_msec() - start_time
		}

	_shader_compiled = true
	var duration = Time.get_ticks_msec() - start_time

	return {
		"success": true,
		"device_name": device_name,
		"message": "Shader compiled successfully",
		"duration_ms": duration
	}

func _init_gpu() -> void:
	"""Try to initialize GPU compute (uses pre-compiled shader if available)."""
	# Create local rendering device for compute
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		return

	# If shader was pre-compiled, use the shared version
	if _shader_compiled and _shared_shader != RID() and _shared_pipeline != RID():
		force_shader = _shared_shader
		force_pipeline = _shared_pipeline
		gpu_available = true
		return

	# Fallback: compile on-demand (shouldn't happen if boot did pre-compilation)
	if not _compile_force_shader():
		rd.free()
		rd = null
		return

	gpu_available = true


func _compile_force_shader() -> bool:
	"""Compile force calculation compute shader."""
	# In Godot 4.5, we create shader directly from GLSL source
	var shader_code = _get_force_shader_glsl()

	# Create RDShaderSource with compute shader code
	var rd_shader_source = RDShaderSource.new()
	rd_shader_source.source_compute = shader_code

	# Create shader from source
	var shader_spirv = rd.shader_compile_spirv_from_source(rd_shader_source)
	if shader_spirv.compile_error_compute != "":
		print("GPUForceCalculator: Shader compile error: ", shader_spirv.compile_error_compute)
		return false

	# Create shader RID and store it (needed for uniform set creation)
	force_shader = rd.shader_create_from_spirv(shader_spirv)
	if force_shader == RID():
		print("GPUForceCalculator: Failed to create shader RID")
		return false

	# Create pipeline from shader
	force_pipeline = rd.compute_pipeline_create(force_shader)

	return force_pipeline != RID()


static func _get_force_shader_glsl_static() -> String:
	"""Static version of shader source getter for pre-compilation."""
	return """
#version 450

layout(local_size_x = 24, local_size_y = 1, local_size_z = 1) in;

// Input buffers
layout(std430, binding = 0) readonly buffer Positions {
	vec2 pos[];
};

layout(std430, binding = 1) readonly buffer Velocities {
	vec2 vel[];
};

layout(std430, binding = 2) readonly buffer MutualInfo {
	float mi[];
};

// Bloch packet: [p0, p1, x, y, z, r, theta, phi] per qubit (stride=8)
layout(std430, binding = 3) readonly buffer BlochPacket {
	float bloch[];  // 8 floats per qubit
};

layout(std430, binding = 4) readonly buffer FrozenMask {
	uint frozen[];
};

// Output buffers
layout(std430, binding = 5) writeonly buffer OutPositions {
	vec2 new_pos[];
};

layout(std430, binding = 6) writeonly buffer OutVelocities {
	vec2 new_vel[];
};

// Push constants (64 bytes total, 16-byte aligned)
layout(push_constant) uniform PushConstants {
	vec2 biome_center;
	float dt;
	uint num_nodes;
	uint num_qubits;
	float purity_radial_spring;
	float phase_angular_spring;
	float mi_spring;
	float repulsion_strength;
	float damping;
	float base_distance;
	float min_distance;
	float correlation_scaling;
	float max_biome_radius;
	float _pad1;  // Padding for 64-byte alignment
	float _pad2;  // Padding for 64-byte alignment
} pc;

const float PI = 3.14159265359;
const float EPSILON = 0.001;

// Get MI index for pair (i, j) in upper triangular format
uint mi_index(uint i, uint j, uint n) {
	if (i > j) {
		uint tmp = i; i = j; j = tmp;
	}
	return i * n - (i * (i + 1u)) / 2u + j - i - 1u;
}

void main() {
	uint node_id = gl_GlobalInvocationID.x;
	if (node_id >= pc.num_nodes) return;

	if (frozen[node_id] > 0u) {
		new_pos[node_id] = pos[node_id];
		new_vel[node_id] = vel[node_id];
		return;
	}

	vec2 force = vec2(0.0);
	vec2 node_pos = pos[node_id];

	// === 1. PURITY RADIAL FORCE ===
	// Pure states (purity~=1) at center, mixed (purity~=0) at edge
	uint bloch_offset = node_id * 8u;
	if (bloch_offset + 7u < bloch.length()) {
		float p0 = bloch[bloch_offset];      // |0> probability
		float p1 = bloch[bloch_offset + 1u]; // |1> probability
		float purity = abs(p0 - p1);         // Purity ~= |p0 - p1|

		// Target radius: pure=center, mixed=edge
		float target_radius = pc.max_biome_radius * (1.0 - purity);

		vec2 radial = node_pos - pc.biome_center;
		float current_radius = length(radial);

		if (current_radius > EPSILON) {
			vec2 radial_dir = radial / current_radius;
			float radial_error = target_radius - current_radius;
			force += radial_dir * (pc.purity_radial_spring * radial_error);
		} else if (target_radius > 1.0) {
			// At center, push outward if target > 0
			force += vec2(1.0, 0.0) * (pc.purity_radial_spring * target_radius);
		}
	}

	// === 2. PHASE ANGULAR FORCE ===
	// Tangent force to cluster by phase (theta on Bloch sphere)
	if (bloch_offset + 7u < bloch.length()) {
		float theta = bloch[bloch_offset + 6u];  // Bloch theta

		vec2 radial = node_pos - pc.biome_center;
		float current_radius = length(radial);

		if (current_radius > EPSILON) {
			// Current angle in 2D
			float current_angle = atan(radial.y, radial.x);

			// Target angle from Bloch theta
			float target_angle = theta;

			// Angular error wrapped to [-PI, PI]
			float angular_error = target_angle - current_angle;
			if (angular_error > PI) angular_error -= 2.0 * PI;
			if (angular_error < -PI) angular_error += 2.0 * PI;

			// Tangent direction (perpendicular to radial)
			vec2 tangent = vec2(-radial.y, radial.x) / current_radius;

			// Tangent force proportional to angular error × radius
			force += tangent * (pc.phase_angular_spring * angular_error * current_radius);
		}
	}

	// === 3. CORRELATION FORCES (MI-based springs) ===
	// High MI → attract (shorter spring length)
	for (uint j = 0u; j < pc.num_nodes; j++) {
		if (j == node_id) continue;
		if (frozen[j] > 0u) continue;

		// Get MI value
		uint mi_idx = mi_index(node_id, j, pc.num_nodes);
		float mi_val = 0.0;
		if (mi_idx < mi.length()) {
			mi_val = mi[mi_idx];
		}
		if (mi_val < 0.000001) continue;  // Skip if no correlation

		// Distance between nodes
		vec2 delta = pos[j] - node_pos;
		float dist = length(delta);
		if (dist < EPSILON) continue;

		// Target distance decreases with MI
		float target_distance = pc.base_distance / (1.0 + pc.correlation_scaling * mi_val);
		target_distance = max(target_distance, pc.min_distance);

		// Spring force: F = k * (dist - target)
		float error = dist - target_distance;
		vec2 direction = delta / dist;
		force += direction * (pc.mi_spring * error);
	}

	// === 4. REPULSION FORCES ===
	// Inverse-square prevents overlap
	for (uint j = 0u; j < pc.num_nodes; j++) {
		if (j == node_id) continue;
		if (frozen[j] > 0u) continue;

		vec2 delta = node_pos - pos[j];
		float dist = length(delta);

		if (dist < EPSILON) {
			// Exactly on top: push in random-ish direction
			force += vec2(float(node_id) * 0.1, float(j) * 0.1);
			continue;
		}

		if (dist < pc.min_distance) {
			// Strong repulsion for very close nodes
			vec2 direction = delta / dist;
			force += direction * pc.repulsion_strength;
		} else if (dist < pc.base_distance) {
			// Soft inverse-square repulsion
			vec2 direction = delta / dist;
			float repel_mag = pc.repulsion_strength / (dist * dist + 1.0);
			force += direction * repel_mag;
		}
	}

	// === INTEGRATION ===
	vec2 new_velocity = (vel[node_id] + force * pc.dt) * pc.damping;

	// Clamp velocity to prevent instability
	float vel_mag = length(new_velocity);
	if (vel_mag > 500.0) {
		new_velocity = normalize(new_velocity) * 500.0;
	}

	vec2 new_position = node_pos + new_velocity * pc.dt;

	// Clamp to biome bounding box
	float max_extent = pc.max_biome_radius * 1.5;
	new_position.x = clamp(new_position.x, pc.biome_center.x - max_extent, pc.biome_center.x + max_extent);
	new_position.y = clamp(new_position.y, pc.biome_center.y - max_extent, pc.biome_center.y + max_extent);

	new_pos[node_id] = new_position;
	new_vel[node_id] = new_velocity;
}
"""

func _get_force_shader_glsl() -> String:
	"""Return inline force calculation shader source.

	Matches C++ ForceGraphEngine calculations:
	1. Purity radial force - pure states at center, mixed at edge
	2. Phase angular force - tangent force based on Bloch theta
	3. Correlation forces - MI-based springs between coupled nodes
	4. Repulsion forces - inverse-square prevents overlap
	"""
	return _get_force_shader_glsl_static()


func compute_forces(
	positions: PackedVector2Array,
	velocities: PackedVector2Array,
	mi_values: PackedFloat64Array,
	bloch_packet: PackedFloat64Array,  # Full 8-float format: [p0, p1, x, y, z, r, theta, phi] per qubit
	num_qubits: int,
	biome_center: Vector2,
	delta: float,
	config: Dictionary = {}
) -> Dictionary:
	"""Compute forces on GPU, return updated positions/velocities.

	Calculates all four force types matching C++ ForceGraphEngine:
	1. Purity radial force
	2. Phase angular force
	3. Correlation forces (MI-based)
	4. Repulsion forces
	"""

	if not gpu_available or positions.is_empty():
		return {}

	var num_nodes = positions.size()

	# Get config with defaults (matching C++ ForceGraphEngine defaults)
	var purity_spring = config.get("purity_radial_spring", 0.08)
	var phase_spring = config.get("phase_angular_spring", 0.04)
	var mi_spring = config.get("mi_spring", 0.18)
	var repulsion = config.get("repulsion_strength", 1500.0)
	var damping = config.get("damping", 0.89)
	var base_dist = config.get("base_distance", 120.0)
	var min_dist = config.get("min_distance", 15.0)
	var corr_scaling = config.get("correlation_scaling", 3.0)
	var max_radius = config.get("max_biome_radius", 250.0)

	# Pack data as bytes - use float32 for GPU (converts from float64)
	var pos_bytes = _pack_vector2_to_bytes(positions)
	var vel_bytes = _pack_vector2_to_bytes(velocities)
	var mi_bytes = _pack_float32_array(mi_values)
	var bloch_bytes = _pack_float32_array(bloch_packet)

	# Ensure we have valid buffer data
	if mi_bytes.is_empty():
		mi_bytes = PackedByteArray([0, 0, 0, 0])  # Minimum 4 bytes
	if bloch_bytes.is_empty():
		bloch_bytes = PackedByteArray([0, 0, 0, 0])

	var frozen = PackedByteArray()
	frozen.resize(num_nodes * 4)  # uint per node, 4 bytes each
	frozen.fill(0)

	# Create/update input buffers
	position_buffer = rd.storage_buffer_create(pos_bytes.size(), pos_bytes)
	velocity_buffer = rd.storage_buffer_create(vel_bytes.size(), vel_bytes)
	mi_buffer = rd.storage_buffer_create(mi_bytes.size(), mi_bytes)
	bloch_buffer = rd.storage_buffer_create(bloch_bytes.size(), bloch_bytes)
	frozen_buffer = rd.storage_buffer_create(frozen.size(), frozen)
	out_position_buffer = rd.storage_buffer_create(pos_bytes.size())
	out_velocity_buffer = rd.storage_buffer_create(vel_bytes.size())

	# Create uniform set
	var uniforms = []
	for i in range(7):
		var u = RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.binding = i
		uniforms.append(u)

	uniforms[0].add_id(position_buffer)
	uniforms[1].add_id(velocity_buffer)
	uniforms[2].add_id(mi_buffer)
	uniforms[3].add_id(bloch_buffer)
	uniforms[4].add_id(frozen_buffer)
	uniforms[5].add_id(out_position_buffer)
	uniforms[6].add_id(out_velocity_buffer)

	# Create uniform set (requires shader RID, not pipeline RID)
	var uniform_set = rd.uniform_set_create(uniforms, force_shader, 0)

	# Pack push constants (must match shader layout exactly)
	# Layout: biome_center(vec2), dt, num_nodes(uint), num_qubits(uint),
	#         purity_radial_spring, phase_angular_spring, mi_spring,
	#         repulsion_strength, damping, base_distance, min_distance,
	#         correlation_scaling, max_biome_radius, _pad1, _pad2
	# Total: 64 bytes (16-byte alignment required by Vulkan)
	var push_bytes = PackedByteArray()

	# vec2 biome_center (8 bytes)
	push_bytes.append_array(PackedFloat32Array([biome_center.x, biome_center.y]).to_byte_array())
	# float dt (4 bytes)
	push_bytes.append_array(PackedFloat32Array([delta]).to_byte_array())
	# uint num_nodes (4 bytes)
	push_bytes.append_array(PackedInt32Array([num_nodes]).to_byte_array())
	# uint num_qubits (4 bytes)
	push_bytes.append_array(PackedInt32Array([num_qubits]).to_byte_array())
	# 9 floats (36 bytes)
	push_bytes.append_array(PackedFloat32Array([
		purity_spring,
		phase_spring,
		mi_spring,
		repulsion,
		damping,
		base_dist,
		min_dist,
		corr_scaling,
		max_radius,
	]).to_byte_array())
	# Padding to 64 bytes (8 bytes)
	push_bytes.append_array(PackedFloat32Array([0.0, 0.0]).to_byte_array())

	# Dispatch compute
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, force_pipeline)  # CRITICAL: Must bind pipeline before dispatch
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	rd.compute_list_set_push_constant(compute_list, push_bytes, push_bytes.size())

	var workgroups = ceilf(float(num_nodes) / 24.0)
	rd.compute_list_dispatch(compute_list, int(workgroups), 1, 1)
	rd.compute_list_end()

	# Wait for GPU
	rd.submit()
	rd.sync()

	# Read results
	var new_pos_bytes = rd.buffer_get_data(out_position_buffer)
	var new_vel_bytes = rd.buffer_get_data(out_velocity_buffer)

	# Cleanup
	rd.free_rid(position_buffer)
	rd.free_rid(velocity_buffer)
	rd.free_rid(mi_buffer)
	rd.free_rid(bloch_buffer)
	rd.free_rid(frozen_buffer)
	rd.free_rid(out_position_buffer)
	rd.free_rid(out_velocity_buffer)

	return {
		"positions": _unpack_vector2_from_bytes(new_pos_bytes),
		"velocities": _unpack_vector2_from_bytes(new_vel_bytes),
	}


func _pack_vector2_to_bytes(arr: PackedVector2Array) -> PackedByteArray:
	"""Pack Vector2 array as raw float32 data for GPU (8 bytes per vector)."""
	var bytes = PackedByteArray()
	for v in arr:
		# Each Vector2 = 2 float32 values (4 bytes each)
		bytes.append_array(PackedFloat32Array([v.x, v.y]).to_byte_array())
	return bytes

func _unpack_vector2_from_bytes(bytes: PackedByteArray) -> PackedVector2Array:
	"""Unpack Vector2 array from raw float32 GPU data (8 bytes per vector)."""
	var result = PackedVector2Array()
	var num_vectors = bytes.size() / 8
	for i in range(num_vectors):
		var offset = i * 8
		# Decode 2 float32 values (x, y)
		var floats = bytes.slice(offset, offset + 8).to_float32_array()
		if floats.size() >= 2:
			result.append(Vector2(floats[0], floats[1]))
	return result

func _pack_float64_to_bytes(arr: PackedFloat64Array) -> PackedByteArray:
	var bytes = PackedByteArray()
	for f in arr:
		bytes.append_array(var_to_bytes(f))
	return bytes


func _pack_float32_array(arr: PackedFloat64Array) -> PackedByteArray:
	"""Pack float64 array as float32 for GPU (4 bytes per value)."""
	var bytes = PackedByteArray()
	for f in arr:
		# Convert to float32 and pack as 4 bytes
		var f32 = PackedFloat32Array([float(f)])
		bytes.append_array(f32.to_byte_array())
	return bytes

func cleanup():
	"""Free GPU resources."""
	if rd:
		if position_buffer != RID():
			rd.free_rid(position_buffer)
		if velocity_buffer != RID():
			rd.free_rid(velocity_buffer)
		if mi_buffer != RID():
			rd.free_rid(mi_buffer)
		if bloch_buffer != RID():
			rd.free_rid(bloch_buffer)
		if frozen_buffer != RID():
			rd.free_rid(frozen_buffer)
		if out_position_buffer != RID():
			rd.free_rid(out_position_buffer)
		if out_velocity_buffer != RID():
			rd.free_rid(out_velocity_buffer)
		rd.free()
		rd = null
