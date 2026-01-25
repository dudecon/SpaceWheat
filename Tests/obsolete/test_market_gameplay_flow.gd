#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Complete Market Gameplay Flow
##
## Shows integrated system:
## 1. Player plants wheat → harvests in farming biome
## 2. Mill converts wheat → flour (injects into market)
## 3. Market measures → determines exchange rate
## 4. Player sells flour → receives credits
## 5. Feedback: Market state changes, affecting next cycle

const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const MarketQubit = preload("res://Core/GameMechanics/MarketQubit.gd")

var economy: FarmEconomy
var market: MarketQubit

var starting_wheat: int = 100
var starting_credits: int = 50

func _init():
	print("\n" + print_line("=", 80))
	print("🌾💰 INTEGRATED MARKET GAMEPLAY FLOW")
	print("Farming → Milling → Market Measurement → Trading → Credits")
	print(print_line("=", 80) + "\n")

	economy = FarmEconomy.new()
	economy.wheat_inventory = starting_wheat
	economy.credits = starting_credits

	market = MarketQubit.new()

	print("📦 Starting State:")
	print("   Wheat: %d" % economy.wheat_inventory)
	print("   Credits: %d" % economy.credits)
	print()

	_simulate_game_cycle(3)

	print(print_line("=", 80))
	print("✅ GAMEPLAY FLOW COMPLETE")
	print(print_line("=", 80) + "\n")

	quit()


func print_line(char: String, count: int) -> String:
	var line = ""
	for i in range(count):
		line += char
	return line


func print_sep() -> String:
	var line = ""
	for i in range(80):
		line += "─"
	return line


func _simulate_game_cycle(num_cycles: int):
	"""Simulate complete game cycles: Plant → Mill → Trade"""

	for cycle in range(1, num_cycles + 1):
		print(print_sep())
		print("CYCLE %d" % cycle)
		print(print_sep() + "\n")

		# STEP 1: Check market state before cycle
		print("📊 MARKET STATUS (Before Trading):\n")
		var market_state = market.get_market_state()
		var flour_prob = market_state["flour_probability"]
		var coins_prob = market_state["coins_probability"]

		print("   Theta: %.2f° (θ %.2f rad)" % [
			market_state["theta_degrees"],
			market_state["theta"]
		])
		print("   P(flour abundant): %.1f%%" % [flour_prob * 100])
		print("   P(coins abundant): %.1f%%" % [coins_prob * 100])
		print("   Market Energy: %.2f" % market_state["energy"])
		print()

		# STEP 2: Player has wheat, mills some
		print("🏭 MILLING PHASE:\n")

		var wheat_to_mill = min(economy.wheat_inventory, 40 + cycle * 10)
		print("   Milling %d wheat..." % wheat_to_mill)

		var mill_result = economy.process_wheat_to_flour(wheat_to_mill)
		var flour_produced = mill_result["flour_produced"]

		print("   Result: %d flour + %d credits (processing bonus)" % [
			flour_produced,
			mill_result["credits_earned"]
		])
		economy.credits += mill_result["credits_earned"]

		# STEP 3: Mill injection affects market
		print("\n💫 MARKET INJECTION (Mill → Market):\n")

		var injection = market.inject_flour_from_mill(flour_produced)
		print("   Flour injected: %d" % flour_produced)
		print("   Market theta: %.2f° → %.2f°" % [
			market_state["theta_degrees"],
			injection["new_theta"] * 180 / PI
		])
		print("   P(flour) now: %.1f%%" % [injection["flour_probability"] * 100])
		print()

		# STEP 4: Player trades flour for coins
		print("💰 TRADING PHASE:\n")

		var flour_to_sell = economy.flour_inventory

		if flour_to_sell > 0:
			print("   Selling %d flour to market..." % flour_to_sell)

			# Show what COULD happen
			var rate_preview = market.get_exchange_rate_for_flour(flour_to_sell)
			print("   Exchange rate could be: %d - %d credits/flour" % [
				rate_preview["worst_case_rate"],
				rate_preview["best_case_rate"]
			])
			print()

			# Execute trade
			var trade_result = market.trade_flour_for_coins(flour_to_sell)

			if trade_result["success"]:
				var credits_received = trade_result["credits_received"]
				economy.credits += credits_received

				print("   ✓ Measured: %s state" % trade_result["measurement"])
				print("   ✓ Actual rate: %d credits/flour" % trade_result["rate_achieved"])
				print("   ✓ Received: %d credits" % credits_received)
				print()

				# Show market after trade
				var market_after = market.get_market_state()
				print("   Market after trade:")
				print("   • Theta: %.2f° → %.2f°" % [
					trade_result["new_theta"] * 180 / PI,
					market_after["theta"] * 180 / PI
				])
				print("   • Energy: %.2f → %.2f" % [
					trade_result["new_energy"],
					market_after["energy"]
				])
		else:
			print("   No flour to sell (need to mill first)")
			print()

		# STEP 5: Summary
		print("\n" + print_sep())
		print("CYCLE %d SUMMARY:" % cycle)
		print(print_sep())
		print()

		print("📊 Economy:")
		print("   Wheat: %d" % economy.wheat_inventory)
		print("   Flour: %d" % economy.flour_inventory)
		print("   Credits: %d (started at %d, +%d)" % [
			economy.credits,
			starting_credits,
			economy.credits - starting_credits
		])
		print()

		print("💡 Key Insight:")
		if flour_prob > 0.7:
			print("   Market favors COINS right now (flour was cheap to sell)")
			print("   → Next cycle: prices will improve as coins abundant")
		elif flour_prob < 0.3:
			print("   Market favors FLOUR right now (flour was expensive)")
			print("   → Next cycle: expect boom as supply flows in")
		else:
			print("   Market balanced (fair exchange rates)")

		print()
		print()


func show_strategy_insight():
	print(print_sep())
	print("🎯 STRATEGIC INSIGHTS")
	print(print_sep())
	print()

	print("1. MARKET TIMING:")
	print("   • Measure probability before trading")
	print("   • Sell flour when P(coins) high (flour expensive)")
	print("   • Buy flour when P(flour) high (flour cheap)")
	print()

	print("2. INJECTION MECHANICS:")
	print("   • Mill injection pushes market toward flour (π)")
	print("   • Trading injection pushes toward coins (0)")
	print("   • Leads to natural boom/bust cycles")
	print()

	print("3. ENERGY DECAY:")
	print("   • Market energy decreases with each transaction")
	print("   • Low energy = easier to move market (price impact)")
	print("   • High energy = stable prices")
	print()

	print("4. OPTIMAL STRATEGY:")
	print("   • Watch for market overcorrection")
	print("   • Mill when flour cheap, sell when coins abundant")
	print("   • Use energy decay to predict price swings")
	print()
