class_name BaseSubmenu
extends RefCounted

## BaseSubmenu - Utility class for dynamic submenu generation
##
## Provides shared utilities that submenus compose together:
## - Pagination (OPTIONS_PER_PAGE, page cycling)
## - Action building (Q/E/R mapping)
## - Cost formatting and affordability checks
## - Consistent submenu structure
##
## Usage Pattern (in concrete submenus):
##   static func generate_submenu(biome, farm, selection, page) -> Dictionary:
##       var options = _collect_options(...)
##       var pagination = BaseSubmenu.paginate(options, page)
##       var actions = BaseSubmenu.build_actions(pagination.page_options, _build_action)
##       return BaseSubmenu.build_result("name", "title", pagination, actions)
##
## Submenu Structure:
## {
##     "name": String,
##     "title": String,
##     "dynamic": true,
##     "page": int,
##     "max_pages": int,
##     "total_options": int,
##     "actions": {
##         "Q": {action, label, hint, cost, can_afford, ...},
##         "E": {...},
##         "R": {...}
##     }
## }

const OPTIONS_PER_PAGE = 3  # Q/E/R slots
const ACTION_KEYS = ["Q", "E", "R"]


## ============================================================================
## PAGINATION
## ============================================================================

static func paginate(options: Array, page: int) -> Dictionary:
	"""Calculate pagination for options array.

	Args:
		options: Full array of options
		page: Requested page number (will wrap)

	Returns:
		{
			"page": int,           # Current page (0-indexed)
			"max_pages": int,      # Total pages
			"total_options": int,  # Total option count
			"page_options": Array  # Options for current page (up to 3)
		}
	"""
	var total = options.size()
	var max_pages = ceili(float(total) / OPTIONS_PER_PAGE) if total > 0 else 1
	var current_page = page % max_pages if max_pages > 0 else 0

	var start_idx = current_page * OPTIONS_PER_PAGE
	var end_idx = mini(start_idx + OPTIONS_PER_PAGE, total)
	var page_options = options.slice(start_idx, end_idx) if total > 0 else []

	return {
		"page": current_page,
		"max_pages": max_pages,
		"total_options": total,
		"page_options": page_options
	}


## ============================================================================
## ACTION BUILDING
## ============================================================================

static func build_actions(page_options: Array, action_builder: Callable = Callable()) -> Dictionary:
	"""Build Q/E/R action dictionary from page options.

	Args:
		page_options: Array of up to 3 options for current page
		action_builder: Optional Callable(option) -> Dictionary
		                If not provided, uses default_action_data()

	Returns:
		{"Q": action_data, "E": action_data, "R": action_data}
		(only includes keys for available options)
	"""
	var actions = {}

	for i in range(mini(page_options.size(), OPTIONS_PER_PAGE)):
		var option = page_options[i]
		if action_builder.is_valid():
			actions[ACTION_KEYS[i]] = action_builder.call(option)
		else:
			actions[ACTION_KEYS[i]] = default_action_data(option)

	return actions


static func default_action_data(option: Dictionary) -> Dictionary:
	"""Default action data builder - passes through common fields.

	Override by providing custom action_builder to build_actions().
	"""
	return {
		"action": option.get("action", ""),
		"label": option.get("label", ""),
		"hint": option.get("hint", ""),
		"emoji": option.get("emoji", ""),
		"icon": option.get("icon", ""),
		"enabled": option.get("enabled", true),
		"cost": option.get("cost", {}),
		"can_afford": option.get("can_afford", true),
		"option_data": option  # Full option for custom handlers
	}


## ============================================================================
## RESULT BUILDING
## ============================================================================

static func build_result(
	name: String,
	title: String,
	pagination: Dictionary,
	actions: Dictionary,
	extras: Dictionary = {}
) -> Dictionary:
	"""Build final submenu result dictionary.

	Args:
		name: Submenu identifier (e.g., "gate_selection")
		title: Display title (e.g., "Build Gate")
		pagination: Result from paginate()
		actions: Result from build_actions()
		extras: Additional fields to merge (e.g., selection_count)

	Returns:
		Complete submenu dictionary
	"""
	var result = {
		"name": name,
		"title": title,
		"dynamic": true,
		"page": pagination.get("page", 0),
		"max_pages": pagination.get("max_pages", 1),
		"total_options": pagination.get("total_options", 0),
		"actions": actions
	}

	# Merge any extra fields
	for key in extras:
		result[key] = extras[key]

	return result


## ============================================================================
## COST UTILITIES
## ============================================================================

static func format_cost(cost: Dictionary) -> String:
	"""Format cost dictionary as display string.

	Args:
		cost: {"emoji": amount, ...} e.g., {"🍼": 2, "🌾": 5}

	Returns:
		Formatted string like "🍼×2 🌾×5"
	"""
	if cost.is_empty():
		return ""

	var parts: Array = []
	for emoji in cost:
		var amount = cost[emoji]
		if amount > 1:
			parts.append("%s×%d" % [emoji, amount])
		else:
			parts.append(emoji)

	return " ".join(parts)


static func check_affordability(cost: Dictionary, economy) -> bool:
	"""Check if economy can afford the cost.

	Args:
		cost: {"resource_name": amount, ...}
		economy: FarmEconomy instance with can_afford() or get_balance()

	Returns:
		true if affordable, false otherwise
	"""
	if cost.is_empty():
		return true

	if not economy:
		return false

	# Try can_afford method first
	if economy.has_method("can_afford"):
		return economy.can_afford(cost)

	# Fallback: check each resource individually
	for resource in cost:
		var required = cost[resource]
		var available = 0

		if economy.has_method("get_balance"):
			available = economy.get_balance(resource)
		elif resource in economy:
			available = economy[resource]

		if available < required:
			return false

	return true


static func apply_cost_to_options(options: Array, economy) -> Array:
	"""Add can_afford and cost_display fields to options with costs.

	Args:
		options: Array of option dictionaries (may have "cost" field)
		economy: FarmEconomy instance

	Returns:
		Same array with can_afford and cost_display added where applicable
	"""
	for option in options:
		var cost = option.get("cost", {})
		if not cost.is_empty():
			option["can_afford"] = check_affordability(cost, economy)
			option["cost_display"] = format_cost(cost)
			# Disable if can't afford (unless explicitly enabled)
			if not option.get("can_afford", true) and not option.has("force_enabled"):
				option["enabled"] = false

	return options


## ============================================================================
## SORTING UTILITIES
## ============================================================================

static func sort_by_field(options: Array, field: String, descending: bool = true) -> Array:
	"""Sort options by a numeric field.

	Args:
		options: Array of option dictionaries
		field: Field name to sort by (e.g., "affinity", "priority")
		descending: true for highest first, false for lowest first

	Returns:
		Sorted array (modifies in place and returns)
	"""
	if descending:
		options.sort_custom(func(a, b): return a.get(field, 0) > b.get(field, 0))
	else:
		options.sort_custom(func(a, b): return a.get(field, 0) < b.get(field, 0))

	return options


static func sort_enabled_first(options: Array) -> Array:
	"""Sort options with enabled=true before enabled=false.

	Preserves relative order within each group.
	"""
	var enabled: Array = []
	var disabled: Array = []

	for opt in options:
		if opt.get("enabled", true):
			enabled.append(opt)
		else:
			disabled.append(opt)

	enabled.append_array(disabled)
	return enabled


## ============================================================================
## EMPTY/DISABLED STATE HELPERS
## ============================================================================

static func empty_submenu(name: String, title: String, message: String) -> Dictionary:
	"""Create a submenu showing a disabled message (e.g., "No options available").

	Args:
		name: Submenu identifier
		title: Display title
		message: Message to show in Q slot

	Returns:
		Submenu with single disabled option
	"""
	return {
		"name": name,
		"title": title,
		"dynamic": true,
		"page": 0,
		"max_pages": 1,
		"total_options": 0,
		"_disabled": true,
		"_message": message,
		"actions": {
			"Q": {
				"action": "",
				"label": message,
				"hint": "",
				"enabled": false
			}
		}
	}
