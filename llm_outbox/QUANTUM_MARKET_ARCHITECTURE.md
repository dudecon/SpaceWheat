# Quantum Market Architecture: Emoji-First Trading System

**Status**: Design phase - exported for external review and refinement
**Replaced**: Classical `Market.gd` file with hardcoded pricing (DELETED)
**New Paradigm**: Quantum-first market where price emerges from coupling dynamics

---

## Core Insight: Markets as Quantum Systems

Traditional markets model price as a classical function of supply/demand. Instead:

**The market is a quantum bath where:**
- 🐂/🐻 (sentiment) is a dynamic axis evolving under Hamiltonian
- Any commodity emoji (🌾, 💨, 🍞, etc.) pairs with 💰 (money)
- Coupling strength between commodity and money encodes "tradability"
- Sentiment's coupling to commodity creates price dynamics
- Player injects commodities; market evolves them; price emerges from evolution

---

## Architecture: The Quantum Market Biome

### Current Implementation (MarketBiome.gd)
```
Bath-First Model:
┌──────────────────────────────────────┐
│ QuantumBath with 6 emojis:           │
│ - 🐂/🐻 (Sentiment: Bull/Bear)      │
│ - 💰/📦 (Liquidity: Money/Goods)    │
│ - 🏛️/🏚️ (Stability: Order/Chaos)  │
│                                      │
│ Hamiltonian:                         │
│ - Sentiment ↔ Liquidity coupling     │
│ - Stability influences volatility    │
└──────────────────────────────────────┘
```

### What's Missing: Dynamic Commodity Injection

**Problem**: Current market has fixed emojis (🐂🐻💰📦🏛️🏚️). No way to add new tradeable commodities.

**Solution**: `inject_commodity(emoji, amount)` method that:
1. Checks if emoji exists in IconRegistry
2. If new emoji: adds to bath with registered Icon
3. If existing emoji: increases amplitude
4. Creates automatic coupling: `emoji ↔ 💰` pair
5. Updates Hamiltonian to include sentiment-commodity coupling

---

## Detailed Design: Quantum Market Dynamics

### Phase 1: Commodity Injection

```gdscript
# Player/Farm produces flour
farm_economy.add_resource("💨", 100)

# Market processing automatically injects
market_biome.inject_commodity("💨", 10)  # 10 units
```

**What happens**:
1. Fetch flour Icon from IconRegistry: `Icon("💨", north=🌾, south=💨, ...)`
2. Check if 💨 in bath:
   - If NO: `bath.inject_emoji("💨", flour_icon)`
   - If YES: increase amplitude (Bloch vector extends further)
3. Add to Hamiltonian: `H += ω_sentiment-commodity (🐂|💨⟩⟨💰| + h.c.)`

### Phase 2: Coupling Strength (Emergent Price)

**Key insight**: Price isn't hardcoded. It emerges from Hamiltonian structure.

**The coupling strength ω encodes trading dynamics:**
- **Strong coupling** (ω large): Commodity readily trades for money
  - Market wants this commodity
  - Fast population transfer: commodity → money

- **Weak coupling** (ω small): Commodity slowly converts to money
  - Market doesn't want this commodity
  - Slow population transfer

- **Coupling direction**:
  - Sentiment ↔ Commodity pair (🐂 prefers commodities, 🐻 prefers money)

### Phase 3: Dynamic Price Calculation

Instead of `price = 100 * quantity`, we have:

```
Effective Exchange Rate = f(ω_coupling, sentiment_state, commodity_amount)

Where:
ω_coupling = strength of commodity ↔ money coupling
sentiment_state = current 🐂/🐻 probability distribution
commodity_amount = how much of emoji in bath (population)

Implementation options:
A) Query Hamiltonian eigenvalues (most quantum-accurate)
B) Sample coupling strength from spectral analysis
C) Compute coupling from Icon definitions (trophic level, self_energy)
```

---

## Implementation Roadmap

### Step 1: Add `inject_commodity()` to MarketBiome

```gdscript
func inject_commodity(emoji: String, amount: float) -> bool:
    """
    Inject tradeable commodity into market quantum bath.

    Process:
    1. Get Icon from IconRegistry
    2. If emoji not in bath: inject with initial state
    3. If emoji in bath: increase population
    4. Update Hamiltonian to couple sentiment ↔ commodity ↔ money
    5. Evolve system one step

    Returns: true if injection successful
    """
    # Implementation details below...
```

**Implementation considerations:**
- Does Icon have `hamiltonian_couplings` field defining interactions?
- Should coupling strength be constant or state-dependent?
- How to handle conservation laws? (money_total = constant?)

### Step 2: Add `query_trading_rate()` to MarketBiome

```gdscript
func query_trading_rate(from_emoji: String, to_emoji: String = "💰") -> float:
    """
    Query current exchange rate between commodities.

    Based on:
    - Hamiltonian coupling strength
    - Current sentiment (🐂 increases commodity value)
    - Population of emojis in bath

    Returns: effective exchange rate (how much of to_emoji per from_emoji)

    Example: query_trading_rate("💨", "💰") → 73.5 (current flour price)
    """
    # Implementation details below...
```

### Step 3: Modify FarmGrid to use quantum queries instead of fixed sales

```gdscript
# OLD (deleted):
var result = farm_economy.sell_flour_at_market(flour_units)
var credits = result["credits_received"]  # 80 per flour (hardcoded)

# NEW:
var rate = market_biome.query_trading_rate("💨")  # Quantum-dependent
var credits = flour_units * rate
farm_economy.add_resource("💰", credits, "market_coupling")
```

---

## Key Design Questions

### Q1: How does sentiment affect commodity price?

**Current idea**:
- Bull market (🐂): increases appetite for commodities, stronger coupling
- Bear market (🐻): hoards money, weaker coupling

**Implementation**:
```gdscript
func _compute_coupling_strength(commodity: String) -> float:
    var p_bull = sentiment_component.get_marginal_probability(0, 0)  # P(🐂)
    var coupling_base = icon.hamiltonian_couplings.get("💰", 0.5)

    # Bull sentiment amplifies coupling
    return coupling_base * (1.0 + p_bull * 0.5)  # 0.5x to 1.5x range
```

### Q2: What about market sentiment drift?

**Current idea**:
- Sentiment has natural cycle: bull → bear → bull
- Commodity abundance can influence sentiment
- Lots of flour in market → deflation pressure → sentiment shifts

**Implementation**:
- Sentiment qubit couples to total commodity population
- When flour abundant: bear pressure increases
- Creates natural market cycles

### Q3: Money conservation?

**Current idea**:
- Total 💰 in market should be conserved (money isn't created)
- Commodity ↔ Money trading is transfer, not creation
- Money "value" emerges from Hamiltonian eigenvalues

**Implementation**:
```gdscript
# When flour injected:
bath.add_commodity("💨")
# Market evolves flour ↔ money coupling
# But Tr(ρ) = 1.0 still, money is just redistributed

# Player can query:
# "How much money should I expect for X flour?"
# Answer comes from Hamiltonian spectroscopy
```

### Q4: How do player actions affect market?

**Current idea**: Player injects any emoji they want
```gdscript
# Player finds a wild emoji (e.g., 🍄 mushroom)
# They can inject it into market:
market_biome.inject_commodity("🍄", 50)

# Market instantly couples it to money/sentiment
# Creates new trading opportunity
# Price emerges from Hamiltonian, not predefined
```

---

## Integration with Gameplay Loop

### Current Flow (Broken - used old sell function):
```
Farming: 🌾 → Mill → 💨
            (FarmGrid._process_mills)

Market: 💨 → sell_flour_at_market() → 💰 (HARDCODED: 80 per flour)
            (FarmGrid._process_markets - DELETED)
```

### New Flow (Quantum-first):
```
Farming: 🌾 → Mill → 💨
            (FarmGrid._process_mills)

Market: 💨 → inject_commodity("💨", units)
            (FarmGrid._process_markets)
            ↓
Market Evolves:
    - Sentiment couples to flour availability
    - Flour population damps over time (as traded)
    - Price emerges: query_trading_rate("💨")
            ↓
Player can:
    - Query: "What's flour worth now?" → calls query_trading_rate()
    - Inject new commodities (bread, mushrooms, etc.)
    - Watch sentiment shift with commodity changes
    - Extract value when conditions favorable
```

---

## Emergent Behaviors (What We Hope Happens)

### 1. Dynamic Pricing
- Flour abundance → price drops (sentiment shifts bear)
- Flour scarcity → price rises (market wants it)
- No hardcoded "100 credits per flour"

### 2. Timing Strategies
- Player learns: "sell flour when sentiment is bullish"
- "Hold bread until market develops appetite"
- Adds skill dimension to economy

### 3. Commodity Mixing
- Player injects 🍞 (bread) AND 💨 (flour)
- Market creates coupling: flour → bread → money
- Bread might trade at premium (scarcer, refined good)

### 4. Market Cycles
- Sentiment drift → commodity appetite changes → prices cycle
- Player can't control market, but can predict it
- Creates dynamic trading window

---

## Mathematical Framework

### Bath State
```
ρ_market = density matrix of all emojis in market bath

Structure: multiple 2×2 reduced matrices
- ρ_sentiment: 🐂/🐻 probabilities
- ρ_commodity: |0⟩ (commodity) / |1⟩ (other) probabilities
- ρ_liquidity: 💰/📦 probabilities
```

### Hamiltonian (General Form)
```
H = H_sentiment + H_commodity + H_coupling + H_stability

H_sentiment: Natural bull/bear cycle (time-periodic)
H_commodity: Each commodity has self-energy (trophic level)
H_coupling: Sentiment ↔ Commodity ↔ Money interactions
H_stability: 🏛️/🏚️ damping terms

All from Icon definitions in IconRegistry
```

### Exchange Rate Query
```
Rate(commodity → money) = f(H, ρ, ω_coupling)

Options:
A) Eigenvalue method:
   λ₀ = lowest eigenvalue of H_coupling
   Rate ∝ |λ₀| (stronger coupling → faster exchange)

B) Spectral method:
   Rate = integral of coupling spectrum weighted by ρ
   Captures full quantum state information

C) Phenomenological:
   Rate = coupling_strength * (1 + p_bull) * (1 - commodity_amount)
   Simpler, captures main effects
```

---

## Risk Assessment & Unknowns

### ✅ Advantages of This Approach
1. **Unifies market with quantum physics** - single coherent system
2. **Emergent pricing** - no hardcoded numbers to balance
3. **Extensible** - add any emoji, market auto-couples it
4. **Player agency** - can inject commodities strategically
5. **Natural cycles** - sentiment drift creates market dynamics

### ⚠️ Challenges
1. **Computational**: Hamiltonian grows as emojis added (more basis states)
2. **Unpredictability**: Might be too chaotic for players to learn patterns
3. **Money conservation**: How to ensure money doesn't disappear?
4. **Icon design**: All new commodities need Icon definitions with couplings
5. **UI design**: How to display quantum market state clearly?

### ❓ Open Questions
1. Should player be able to "query" market price before trading?
2. What happens if player injects massive amount of commodity (breaks dynamics)?
3. How to prevent market from oscillating wildly (stabilize)?
4. Should there be a "gold standard" emoji (💰) that doesn't fluctuate?
5. How do we handle player's classical inventory vs. market quantum state?

---

## Comparison: Classical vs. Quantum Market

### Classical (Deleted Approach)
```gdscript
price_flour = 100  # Constant
farmer_gets = price_flour * 0.80  # Hardcoded margin
# Fixed, boring, no dynamics
```

**Problems**:
- No incentive to time trades
- No market interaction
- Trivial "game" (just farm, auto-sell, done)

### Quantum (Proposed Approach)
```gdscript
coupling_flour = compute_from_hamiltonian()  # Depends on state
sentiment = query_sentiment_probability()  # Current market mood
rate = coupling_flour * (1.0 + sentiment * 0.5)  # Dynamic
farmer_gets = flour_units * rate  # Depends on timing!
# Dynamic, emergent, strategic
```

**Advantages**:
- Timing matters (sell in bull market)
- Market reacts to commodity floods
- New commodities create new opportunities
- Players develop market intuition

---

## Recommended Next Steps

### Short Term (If you like this direction):
1. ✅ **DONE**: Delete Market.gd and hard-coded sell functions
2. **TODO**: Add `inject_commodity()` to MarketBiome.gd
3. **TODO**: Add `query_trading_rate()` to MarketBiome.gd
4. **TODO**: Update FarmGrid._process_markets() to use injection + queries
5. **TODO**: Add Icon definitions for 💨 (flour) with coupling to 💰

### Medium Term (Gameplay):
6. Test with simple 2-commodity market (flour + bread)
7. Observe: Does price vary with sentiment?
8. Tune: Adjust coupling strengths for good dynamics
9. Extend: Add more commodities (mushrooms, etc.)
10. Polish: UI to show market state and current rates

### Long Term (If physics works):
11. Add player agency: "What if I inject tons of flour?" (prediction)
12. Create trading quests: "Sell flour when sentiment > 0.7"
13. Emergent: Players discover arbitrage (buy low, sell high)
14. Extend: Multi-commodity strategies (bundle selling)

---

## External Review Request

**Key decisions needing external input:**

1. **Feasibility**: Is this computationally tractable? (Hamiltonian grows)
2. **Gameplay**: Will players enjoy unpredictable market, or prefer predictability?
3. **Physics**: Is the mathematical model sound? (Money conservation, etc.)
4. **Design**: Should there be safety rails? (max price, min price?)
5. **Integration**: How to bridge quantum market state ↔ classical player inventory?

**Questions for advisor:**
- Does the sentiment ↔ commodity coupling make physical sense?
- Should exchange rates be derived from eigenvalues, or phenomenological?
- How to prevent market from "dying" (all emojis concentrating in one state)?
- Is there a standard model in quantum economics we should follow?

---

## Files Modified

```
DELETED:
  ✅ Core/GameMechanics/Market.gd (classical pricing - gone!)

MODIFIED:
  Core/GameMechanics/FarmEconomy.gd
    - Removed: sell_flour_at_market() function

  Core/GameMechanics/FarmGrid.gd
    - Removed: calls to farm_economy.sell_flour_at_market()
    - Changed: _process_markets() to inject commodities instead
    - New: calls to market_biome.inject_commodity()

TODO:
  Core/Environment/MarketBiome.gd
    - Add: inject_commodity(emoji, amount) → bool
    - Add: query_trading_rate(from_emoji, to_emoji) → float
```

---

## Summary

**Old system**: Classical, deterministic, boring pricing (100 credits per flour, 20% margin)
- ❌ No dynamics
- ❌ No timing strategy
- ❌ No player agency

**New system**: Quantum, emergent, dynamic pricing via Hamiltonian coupling
- ✅ Price depends on sentiment + commodity state
- ✅ Timing strategy emerges naturally
- ✅ Players can inject any emoji to create trading opportunities
- ✅ Unified with rest of quantum game physics

**Status**: Ready for external review and refinement of implementation details.
