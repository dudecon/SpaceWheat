extends Node

## Global logging configuration with category-based filtering and log levels
##
## NOTE: This is an autoload singleton. Cannot use class_name due to Godot restriction.
## Access via VerboseConfig autoload at runtime, not during compilation.
##
## Usage:
##   VerboseConfig.info("farm", "🌾", "Planting wheat at position %s" % pos)
##   VerboseConfig.debug("quantum", "🔬", "State evolution complete")
##   VerboseConfig.error("save", "❌", "Failed to save game!")
##
## Legacy API (backwards compatible):
##   if VerboseConfig.is_verbose("quantum"):
##       print("Detailed quantum info")
##
## Configuration:
##   --verbose flag enables ALL categories at TRACE level
##   Runtime config via LoggerConfigPanel (press L key)

# ============================================================================
# LOG LEVELS
# ============================================================================

enum LogLevel {
	ERROR = 0,   # Critical failures only
	WARN = 1,    # Warnings and errors
	INFO = 2,    # Important state changes (default)
	DEBUG = 3,   # Detailed tracing
	TRACE = 4    # Everything (very verbose)
}

const LEVEL_NAMES = ["ERROR", "WARN", "INFO", "DEBUG", "TRACE"]

# ============================================================================
# CATEGORY CONFIGURATION
# ============================================================================

# Default log level per category
var category_levels = {
	"ui": LogLevel.INFO,
	"input": LogLevel.INFO,      # INFO for testing migration
	"quantum": LogLevel.INFO,
	"farm": LogLevel.INFO,
	"economy": LogLevel.INFO,
	"biome": LogLevel.WARN,       # Quieter by default
	"save": LogLevel.INFO,
	"quest": LogLevel.INFO,
	"boot": LogLevel.INFO,
	"test": LogLevel.TRACE,       # Tests want everything
	"perf": LogLevel.WARN,        # Only show slow frames
	"network": LogLevel.DEBUG,
}

# Category enable/disable flags
var category_enabled = {
	"ui": true,
	"input": true,
	"quantum": true,
	"farm": true,
	"economy": true,
	"biome": true,
	"save": true,
	"quest": true,
	"boot": true,
	"test": true,
	"perf": true,
	"network": true,
}

# ============================================================================
# OUTPUT CONFIGURATION
# ============================================================================

var enable_console_output: bool = true
var enable_file_logging: bool = false
var log_file_path: String = "user://logs/"
var show_timestamps: bool = false

# ============================================================================
# FILE LOGGING STATE
# ============================================================================

var _log_file: FileAccess = null
var _log_buffer: PackedStringArray = []
const LOG_BUFFER_SIZE = 10  # Flush every N messages

# ============================================================================
# LEGACY FLAGS (backwards compatibility)
# ============================================================================

var verbose_logging: bool = false
var verbose_forest: bool = false      # Maps to "biome"
var verbose_quantum: bool = false     # Maps to "quantum"
var verbose_biome: bool = false       # Maps to "biome"
var verbose_vocabulary: bool = false  # Maps to "quest"
var verbose_farm: bool = false        # Maps to "farm"
var verbose_network: bool = false     # Maps to "network"

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Check for --verbose flag or VERBOSE_LOGGING env var
	var args = OS.get_cmdline_args()
	if "--verbose" in args or OS.get_environment("VERBOSE_LOGGING") == "1":
		verbose_logging = true
		_enable_all_verbose()
		print("🔍 VERBOSE LOGGING ENABLED (ALL CATEGORIES AT TRACE LEVEL)")

	# Enable file logging in debug builds by default
	if OS.is_debug_build():
		enable_file_logging = true
		_init_file_logging()

	# Legacy: Check for subsystem-specific flags
	if OS.get_environment("VERBOSE_FOREST") == "1":
		verbose_forest = true
		set_category_level("biome", LogLevel.DEBUG)
		print("🌲 VERBOSE FOREST LOGGING ENABLED")


func _init_file_logging():
	"""Initialize file logging - create log directory and file"""
	if not enable_file_logging:
		return

	# Create logs directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("logs"):
		dir.make_dir("logs")

	# Create log file with timestamp
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var log_filename = "game_%s.log" % timestamp
	var full_path = log_file_path + log_filename

	_log_file = FileAccess.open(full_path, FileAccess.WRITE)
	if _log_file:
		print("📝 File logging enabled: %s" % full_path)
		_log_file.store_line("=== SpaceWheat Game Log ===")
		_log_file.store_line("Started: %s" % Time.get_datetime_string_from_system())
		_log_file.store_line("")
		_log_file.flush()
	else:
		push_error("Failed to open log file: %s" % full_path)


func _enable_all_verbose():
	"""Enable all categories at TRACE level (for --verbose flag)"""
	for category in category_levels.keys():
		category_levels[category] = LogLevel.TRACE

	# Legacy flags
	verbose_forest = true
	verbose_quantum = true
	verbose_biome = true
	verbose_vocabulary = true
	verbose_farm = true
	verbose_network = true


func _notification(what: int):
	"""Flush log buffer on exit"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_flush_file()
		if _log_file:
			_log_file.close()

# ============================================================================
# PUBLIC LOGGING API
# ============================================================================

func error(category: String, emoji: String, message: String) -> void:
	"""Log error message (always shown unless category disabled)"""
	_log(category, LogLevel.ERROR, emoji, message)


func warn(category: String, emoji: String, message: String) -> void:
	"""Log warning message"""
	_log(category, LogLevel.WARN, emoji, message)


func info(category: String, emoji: String, message: String) -> void:
	"""Log info message (default level for most categories)"""
	_log(category, LogLevel.INFO, emoji, message)


func debug(category: String, emoji: String, message: String) -> void:
	"""Log debug message (detailed tracing)"""
	_log(category, LogLevel.DEBUG, emoji, message)


func trace(category: String, emoji: String, message: String) -> void:
	"""Log trace message (extremely verbose)"""
	_log(category, LogLevel.TRACE, emoji, message)


# Shorter aliases for frequent use
func e(cat: String, emoji: String, msg: String) -> void:
	error(cat, emoji, msg)

func w(cat: String, emoji: String, msg: String) -> void:
	warn(cat, emoji, msg)

func i(cat: String, emoji: String, msg: String) -> void:
	info(cat, emoji, msg)

func d(cat: String, emoji: String, msg: String) -> void:
	debug(cat, emoji, msg)

func t(cat: String, emoji: String, msg: String) -> void:
	trace(cat, emoji, msg)

# ============================================================================
# CATEGORY CONFIGURATION API
# ============================================================================

func set_category_level(category: String, level: LogLevel) -> void:
	"""Set log level for a specific category"""
	if not category_levels.has(category):
		push_warning("Unknown logging category: %s" % category)
		return

	category_levels[category] = level
	print("🔧 Logger: %s level set to %s" % [category.to_upper(), LEVEL_NAMES[level]])


func set_category_enabled(category: String, enabled: bool) -> void:
	"""Enable or disable a category entirely"""
	if not category_enabled.has(category):
		push_warning("Unknown logging category: %s" % category)
		return

	category_enabled[category] = enabled
	print("🔧 Logger: %s %s" % [category.to_upper(), "ENABLED" if enabled else "DISABLED"])


func get_category_level(category: String) -> LogLevel:
	"""Get current log level for a category"""
	return category_levels.get(category, LogLevel.INFO)


func get_all_categories() -> Array[String]:
	"""Get list of all available categories"""
	var cats: Array[String] = []
	for cat in category_levels.keys():
		cats.append(cat)
	return cats

# ============================================================================
# LEGACY API (backwards compatibility)
# ============================================================================

static func safe_is_verbose(subsystem: String = "") -> bool:
	"""Safe check that works even if VerboseConfig isn't initialized"""
	if not is_instance_valid(VerboseConfig):
		return false

	if not VerboseConfig.is_node_ready():
		return false

	return VerboseConfig.is_verbose(subsystem)


func is_verbose(subsystem: String = "") -> bool:
	"""Check if we should show verbose output for a subsystem

	Legacy API - returns true if category level is DEBUG or TRACE
	Maps old subsystem names to new categories
	"""
	if not is_node_ready():
		return false

	# Global verbose flag
	if verbose_logging:
		return true

	# Map legacy subsystem names to new categories
	var category = _map_legacy_subsystem(subsystem)

	# Check if category is at DEBUG or TRACE level
	var level = category_levels.get(category, LogLevel.INFO)
	return level >= LogLevel.DEBUG


func _map_legacy_subsystem(subsystem: String) -> String:
	"""Map legacy subsystem names to new categories"""
	match subsystem:
		"forest":
			return "biome"
		"quantum":
			return "quantum"
		"biome":
			return "biome"
		"vocabulary":
			return "quest"
		"farm":
			return "farm"
		"network":
			return "network"
		_:
			return subsystem  # Pass through unknown names

# ============================================================================
# INTERNAL LOGGING IMPLEMENTATION
# ============================================================================

func _log(category: String, level: LogLevel, emoji: String, message: String) -> void:
	"""Internal logging method - routes to console and/or file"""
	# Early exit: check if we should log this
	if not _should_log(category, level):
		return

	# Format the log message
	var level_str = LEVEL_NAMES[level]
	var timestamp_str = ""
	if show_timestamps:
		timestamp_str = "[%s] " % Time.get_ticks_msec()

	var formatted = "%s[%s][%s] %s %s" % [
		timestamp_str,
		level_str,
		category.to_upper(),
		emoji,
		message
	]

	# Output to console
	if enable_console_output:
		_output_console(level, formatted)

	# Output to file
	if enable_file_logging:
		_output_file(formatted)


func _should_log(category: String, level: LogLevel) -> bool:
	"""Check if a message should be logged based on category and level"""
	# Check if category is enabled
	if not category_enabled.get(category, true):
		return false

	# Check if category exists
	if not category_levels.has(category):
		# Unknown category - log warnings and errors, ignore others
		return level <= LogLevel.WARN

	# Check log level threshold
	var category_level = category_levels[category]
	return level <= category_level


func _output_console(level: LogLevel, formatted: String) -> void:
	"""Output to console using appropriate function"""
	match level:
		LogLevel.ERROR:
			push_error(formatted)
		LogLevel.WARN:
			push_warning(formatted)
		_:
			print(formatted)


func _output_file(formatted: String) -> void:
	"""Output to log file with buffering"""
	if not _log_file:
		return

	_log_buffer.append(formatted)

	# Flush buffer if it's full
	if _log_buffer.size() >= LOG_BUFFER_SIZE:
		_flush_file()


func _flush_file() -> void:
	"""Write buffered log messages to file"""
	if not _log_file or _log_buffer.is_empty():
		return

	for line in _log_buffer:
		_log_file.store_line(line)

	_log_file.flush()
	_log_buffer.clear()
