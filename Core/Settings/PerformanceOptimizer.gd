class_name PerformanceOptimizer
extends Node

## Smart performance optimization based on hardware detection
##
## - Detects software rendering (llvmpipe, Mesa) and disables VSYNC
## - Keeps VSYNC enabled for real GPUs
## - Allows user override via settings
## - Logs decisions for debugging

static func detect_software_renderer() -> bool:
	"""Returns true if using software rendering (llvmpipe, Mesa, etc)."""
	var gpu_name = RenderingServer.get_video_adapter_name().to_lower()
	var is_software = (
		gpu_name.is_empty() or
		"llvmpipe" in gpu_name or
		"mesa" in gpu_name or
		"software" in gpu_name or
		"cpu" in gpu_name or
		gpu_name == "unknown"
	)
	return is_software


static func optimize_for_platform() -> void:
	"""Auto-configure performance settings based on detected hardware."""
	var is_software_render = detect_software_renderer()
	var gpu_name = RenderingServer.get_video_adapter_name()

	# Log detection
	if is_software_render:
		print("[PerformanceOptimizer] Software rendering detected: %s" % gpu_name)
		print("[PerformanceOptimizer] Disabling VSYNC for better responsiveness")
	else:
		print("[PerformanceOptimizer] GPU detected: %s" % gpu_name)
		print("[PerformanceOptimizer] Keeping VSYNC enabled for smooth presentation")

	# Apply settings
	if is_software_render:
		# Software rendering: disable VSYNC for lower perceived latency
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("[PerformanceOptimizer] VSYNC: OFF (software rendering)")
	else:
		# Real GPU: keep VSYNC for power efficiency and smooth 60 FPS
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		print("[PerformanceOptimizer] VSYNC: ON (hardware GPU)")


static func get_performance_profile() -> Dictionary:
	"""Return hardware profile with recommended settings."""
	var is_software = detect_software_renderer()
	var gpu_name = RenderingServer.get_video_adapter_name()

	return {
		"gpu_name": gpu_name,
		"is_software_rendering": is_software,
		"recommended_vsync": DisplayServer.VSYNC_DISABLED if is_software else DisplayServer.VSYNC_ENABLED,
		"target_fps": 30 if is_software else 60,
	}
