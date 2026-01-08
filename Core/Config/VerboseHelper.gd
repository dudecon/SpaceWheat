class_name VerboseHelper
extends RefCounted

## Helper class to access VerboseConfig autoload without compile-time errors
## Usage: const V = preload("res://Core/Config/VerboseHelper.gd")
##        V.info("category", "emoji", "message")

static func get_config() -> Node:
	# Access the VerboseConfig autoload at runtime
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.get_node_or_null("VerboseConfig")
	return null

static func info(category: String, emoji: String, message: String) -> void:
	var config = get_config()
	if config:
		config.info(category, emoji, message)
	else:
		print("[INFO][%s] %s %s" % [category, emoji, message])

static func debug(category: String, emoji: String, message: String) -> void:
	var config = get_config()
	if config:
		config.debug(category, emoji, message)

static func warn(category: String, emoji: String, message: String) -> void:
	var config = get_config()
	if config:
		config.warn(category, emoji, message)
	else:
		push_warning("[WARN][%s] %s %s" % [category, emoji, message])

static func error(category: String, emoji: String, message: String) -> void:
	var config = get_config()
	if config:
		config.error(category, emoji, message)
	else:
		push_error("[ERROR][%s] %s %s" % [category, emoji, message])
