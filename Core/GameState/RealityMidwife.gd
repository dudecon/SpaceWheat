extends Node

## RealityMidwife - Save token economy for the 3R harvest-all action
##
## The Reality Midwife system gates the "proper" end-of-turn mechanic:
## - 3R (harvest-all) requires a midwife token to execute
## - Players start with a few tokens
## - Tokens are sold in shops and rarely dropped
## - Players can play indefinitely using manual 3E (pop) without tokens
## - Creates vocabulary depth for players who reach the shop system
##
## Philosophy: "Save forever" is a vocabulary reward for engaged players

const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const MIDWIFE_EMOJI: String = EconomyConstants.MIDWIFE_EMOJI

## Starting midwife tokens
const STARTING_TOKENS: int = 6

## Shop price for midwife tokens (in credits)
const MIDWIFE_PRICE: int = 1000

## Drop rate for midwife tokens (per harvest event)
const MIDWIFE_DROP_RATE: float = 0.001

## Current token count
var midwife_tokens: int = STARTING_TOKENS

## Signals
signal midwife_consumed(remaining: int)
signal midwife_acquired(total: int)
signal midwife_insufficient()


func _ready() -> void:
	add_to_group("reality_midwife")


## Consume a midwife token for harvest-all action
## Returns true if successful, false if no tokens available
func consume_midwife() -> bool:
	if midwife_tokens <= 0:
		midwife_insufficient.emit()
		return false

	midwife_tokens -= 1
	midwife_consumed.emit(midwife_tokens)
	return true


## Add midwife tokens (from shop purchase or drop)
func add_midwife(count: int = 1) -> void:
	if not _can_gain_midwife():
		return
	midwife_tokens += count
	midwife_acquired.emit(midwife_tokens)


## Check if player has at least one token
func has_token() -> bool:
	return midwife_tokens > 0


## Get current token count
func get_token_count() -> int:
	return midwife_tokens


## Set token count directly (for save/load)
func set_token_count(count: int) -> void:
	midwife_tokens = max(0, count)


## Try to purchase a midwife token from shop
## economy: FarmEconomy instance to deduct credits from
## Returns true if purchase successful
func try_purchase(economy) -> bool:
	if not economy:
		return false
	if not _can_gain_midwife():
		return false

	if not economy.has_method("get_resource") or not economy.has_method("remove_resource"):
		push_warning("RealityMidwife: economy doesn't have required methods")
		return false

	var current_credits = economy.get_resource("credits")
	if current_credits < MIDWIFE_PRICE:
		return false

	if economy.remove_resource("credits", MIDWIFE_PRICE, "midwife_purchase"):
		add_midwife(1)
		return true

	return false


## Roll for random midwife drop (call after harvest events)
## Returns true if a token dropped
func roll_for_drop() -> bool:
	if randf() < MIDWIFE_DROP_RATE:
		add_midwife(1)
		return true
	return false


## Get the shop price for midwife tokens
func get_price() -> int:
	return MIDWIFE_PRICE


func get_emoji() -> String:
	"""Emoji representing Reality Midwife tokens."""
	return MIDWIFE_EMOJI


func _can_gain_midwife() -> bool:
	"""Allow gains only if the emoji is in known vocabulary (standard rule)."""
	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm:
		return true

	# Prefer farm-owned vocabulary when available
	if "active_farm" in gsm and gsm.active_farm and gsm.active_farm.has_method("get_known_emojis"):
		var known_emojis = gsm.active_farm.get_known_emojis()
		return MIDWIFE_EMOJI in known_emojis

	if not gsm.current_state:
		return true
	var known = gsm.current_state.get_known_emojis() if gsm.current_state.has_method("get_known_emojis") else []
	return MIDWIFE_EMOJI in known


## Serialize for save system
func serialize() -> Dictionary:
	return {
		"midwife_tokens": midwife_tokens
	}


## Deserialize from save data
func deserialize(data: Dictionary) -> void:
	midwife_tokens = data.get("midwife_tokens", STARTING_TOKENS)


## Reset to starting state
func reset() -> void:
	midwife_tokens = STARTING_TOKENS
