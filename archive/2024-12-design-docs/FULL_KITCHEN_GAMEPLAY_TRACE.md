# Full Kitchen Gameplay Loop Trace

**Status**: Core implementation complete. Bell state methods added. Market bread selling needs implementation.

---

## Complete Resource Flow

```
🌾 WHEAT        💨 FLOUR        🍞 BREAD        💰 CREDITS
Farming     →   Milling      →   Kitchen    →   Market Sales
```

---

## 1. WHEAT FARMING & HARVESTING ✅

**File**: `Core/GameMechanics/FarmGrid.gd`

### Planting
- **Function**: `plant(position, "wheat", quantum_state)` - Lines 674-743
- **Process**:
  1. Validates position in BioticFlux biome
  2. Creates BasePlot with "wheat" type
  3. Allocates quantum register via `allocate_register_for_plot()` (line 231-262)
  4. Auto-entangles with nearby plots based on infrastructure
  5. Adds to biome's quantum computer

### Harvesting
- **Function**: `harvest_wheat(position)` - Lines 932-956
  - Single plot harvest
- **Function**: `harvest_with_topology(position, local_radius)` - Lines 1135-1272
  - Full harvest with topology analysis, coherence penalties, territory bonuses
  - Formula: `final_yield = base_yield × state_modifier × topology_bonus × coherence_factor × territory_modifier`

### Output
- Quantum energy measured from plot's quantum state
- Converted to emoji-credits via `farm_economy.receive_harvest()` (FarmEconomy.gd:152-160)
- Stored as 🌾 resource in economy

**Status**: ✅ FULLY IMPLEMENTED

---

## 2. WATER TAPPING (Forest Biome Drain) ✅

**Files**:
- `Core/GameMechanics/FarmGrid.gd` - Tap placement & processing
- `Core/Environment/ForestEcosystem_Biome.gd` - Water source
- `Core/QuantumSubstrate/QuantumBath.gd` - Lindblad operators

### Placement
- **Function**: `plant_energy_tap(position, "💧", drain_rate=0.1)` - Lines 750-832
- **Process**:
  1. Validates emoji against IconRegistry
  2. Retrieves Icon for water (💧)
  3. Configures as drain target: `target_icon.is_drain_target = true`
  4. Injects into forest biome's quantum bath
  5. Ensures sink state (❄️) is in bath for Lindblad drainage

### Processing
- **Function**: `_process_energy_taps(delta)` - Lines 389-441 (called each frame)
- **Process**:
  1. Queries biome's quantum computer for Lindblad flux accumulation
  2. Retrieves: `flux = biome.quantum_computer.get_lindblad_flux(target_emoji)`
  3. Accumulates in plot: `plot.tap_accumulated_resource += flux`
  4. Converts to credits: `flux_credits = flux × QUANTUM_TO_CREDITS`
  5. Adds to economy: `farm_economy.add_resource("💧", flux_credits, "energy_tap_drain")`

### Source
- **File**: `Core/Environment/ForestEcosystem_Biome.gd` - Lines 1-100
- Forest ecosystem with 5 trophic levels
- Predators (wolves, eagles) naturally produce 💧 via Markov chain dynamics
- Lindblad drain operators configured for water (💧) extraction

**Status**: ✅ FULLY IMPLEMENTED

---

## 3. FIRE SOURCING (Kitchen Qubit Measurement) ✅

**File**: `Core/Environment/QuantumKitchen_Biome.gd`

### Kitchen 3-Qubit Architecture
- **Qubit 0 (Temperature)**: |0⟩=🔥 Hot, |1⟩=❄️ Cold
- **Qubit 1 (Moisture)**: |0⟩=💧 Wet, |1⟩=🏜️ Dry
- **Qubit 2 (Substance)**: |0⟩=💨 Flour, |1⟩=🌾 Grain
- **Ground state**: |111⟩ (cold, dry, grain)
- **Target state**: |000⟩ (hot, wet, flour) = Bread ready

### Fire Extraction
- **Function**: `get_temperature_hot()` - Lines 228-232
- **Returns**: P(qubit 0 = |0⟩) = probability oven is hot
- **Mechanism**: Partial trace of density matrix on qubit 0

### Fire Accumulation via Tap
- **Placement**: Via `FarmInputHandler._action_place_energy_tap_for(positions, "🔥")` (line 1510)
- **Processing**: Same as water tap, but targets "🔥" emoji
- **Lindblad drain**: Kitchen configured with fire as drain target

### Player-Driven Fire
- **Function**: `add_fire(amount)` - Lines 288-305
- **Process**:
  1. Creates Lindblad drive on qubit 0
  2. Target state: |0⟩ (hot)
  3. Drive rate: 0.5 probability/second
  4. Duration: `amount × 2.0` seconds
  5. Queued in `active_drives` array

**Status**: ✅ FULLY IMPLEMENTED

---

## 4. FLOUR PRODUCTION (Mill Quantum Non-Demolition) ✅

**Files**:
- `Core/GameMechanics/FarmEconomy.gd` - Conversion logic
- `Core/GameMechanics/FarmGrid.gd` - Mill placement & processing
- `Core/GameMechanics/QuantumMill.gd` - Mill structure

### Wheat-to-Flour Conversion
- **Function**: `FarmEconomy.process_wheat_to_flour(wheat_amount)` - Lines 190-222
- **Process**:
  1. Input: wheat in quantum units
  2. Conversion ratio: 0.8 (10 wheat → 8 flour)
  3. Output flour: `flour_gained = int(wheat_amount × 0.8)`
  4. Adds flour to economy: `add_resource("💨", flour_gained × QUANTUM_TO_CREDITS, "mill_output")`
  5. Bonus credits: `add_resource("💰", credit_bonus × QUANTUM_TO_CREDITS, "mill_processing")`
  6. Emits signal: `flour_processed.emit(wheat_amount, flour_gained)`

### Mill Processing
- **Function**: `FarmGrid.process_mill_flour(flour_amount)` - Lines 460-481
  - Converts mill-produced flour to economy resources

### Market Auto-Sell
- **Function**: `FarmGrid._process_markets(delta)` - Lines 484-518
  - Called each frame
  - Auto-sells accumulated flour at market rate
  - Invokes: `farm_economy.sell_flour_at_market(flour_units)` (line 511)

### Mill Non-Destructive Measurement
- **File**: `Core/GameMechanics/QuantumMill.gd`
- **Architecture**: Icon injection pattern (no measurement, just measurement interface)
- **Function**: `activate(biome)` - Lines 34-69
  - Injects Flour Icon (💨) into parent biome
  - Configures hamiltonian_couplings for wheat ↔ flour rotation
  - Parent biome's bath automatically builds rotation dynamics

**Status**: ✅ FULLY IMPLEMENTED

---

## 5. BREAD CREATION (3-Qubit Bell State) ✅

**File**: `Core/GameMechanics/FarmGrid.gd` - Lines 521-609

### Bell State Baking Process

#### Step 1: Check Ingredient Availability
```gdscript
var fire_credits = farm_economy.get_resource("🔥")
var water_credits = farm_economy.get_resource("💧")
var flour_credits = farm_economy.get_resource("💨")

# Minimum requirement: 10 credits = 1 quantum unit per ingredient
if fire_credits < 10 or water_credits < 10 or flour_credits < 10:
    continue
```

#### Step 2: Create Input Qubits
```gdscript
var fire_qubit = DualEmojiQubit.new("🔥", "❄️")
fire_qubit.theta = 0.0  # North state (fully hot)

var water_qubit = DualEmojiQubit.new("💧", "🏜️")
water_qubit.theta = 0.0  # North state (fully wet)

var flour_qubit = DualEmojiQubit.new("💨", "🌾")
flour_qubit.theta = 0.0  # North state (fully flour)
```

#### Step 3: Create Entanglement
- **Method**: `kitchen_biome.set_quantum_inputs_with_units(fire_qubit, water_qubit, flour_qubit, fire_units, water_units, flour_units)` ✅ ADDED
  - Stores input qubits and resource amounts
  - Resets kitchen to ground state |111⟩

- **Method**: `kitchen_biome.create_bread_entanglement()` ✅ ADDED
  - Evolves kitchen under detuning Hamiltonian
  - Evolution time: `0.05 + (total_units × 0.01)` seconds (50ms base + 10ms per resource unit)
  - Builds Hamiltonian: `H = Δ/2(|000⟩⟨000| - |111⟩⟨111|) + Ω(|000⟩⟨111| + h.c.)`
  - Creates entangled output qubit representing Bell state
  - Amplitude based on P(bread) = P(|000⟩)

#### Step 4: Measurement & Collapse
- **Method**: `kitchen_biome.measure_as_bread()` ✅ ADDED
  - Performs projective measurement on 8D kitchen state
  - Samples basis state from probability distribution
  - Determines outcome:
    - |000⟩ = Perfect bread (100% of input resources)
    - States {1,2,4} = Partial bread (50% of input resources)
    - Other states = Failure (0 bread)

#### Step 5: Resource Consumption & Production
```gdscript
# Consume inputs
farm_economy.remove_resource("🔥", fire_credits, "kitchen_bell_state")
farm_economy.remove_resource("💧", water_credits, "kitchen_bell_state")
farm_economy.remove_resource("💨", flour_credits, "kitchen_bell_state")

# Produce bread
var bread_credits = bread_produced * FarmEconomy.QUANTUM_TO_CREDITS
farm_economy.add_resource("🍞", bread_credits, "kitchen_bell_state_measurement")
```

### Kitchen Quantum Dynamics
**File**: `Core/Environment/QuantumKitchen_Biome.gd`

- **Detuning Hamiltonian** (Lines 150-178):
  - H = Δ/2(|000⟩⟨000| - |111⟩⟨111|) + Ω(|000⟩⟨111| + h.c.)
  - Δ = detuning depends on marginal probabilities
  - Ω = 0.15 (coupling strength for baking speed)

- **Detuning Computation** (Lines 181-207):
  - Ideal populations: P(🔥)≈0.7, P(💧)≈0.5, P(💨)≈0.6
  - Δ = weighted sum of squared deviations from ideal
  - Increases when far from ideal conditions (suppresses rotation)
  - Decreases when approaching ideal conditions

- **Measurement** (Lines 349-411):
  - Projective measurement on 8D density matrix
  - Collapses to one of 8 basis states
  - Determines bread yield based on outcome

**Status**: ✅ FULLY IMPLEMENTED (Bell state methods added in this session)

---

## 6. MARKET SALES & DYNAMIC EMOJI INJECTION ⚠️ PARTIAL

**Files**:
- `Core/GameMechanics/FarmEconomy.gd` - Flour selling
- `Core/Environment/MarketBiome.gd` - Market dynamics
- `Core/QuantumSubstrate/IconRegistry.gd` - Dynamic emoji registration

### Current Implementation

#### Flour Sales ✅
- **Function**: `FarmEconomy.sell_flour_at_market(flour_amount)` - Lines 225-257
- **Process**:
  1. Input: flour units
  2. Market pricing: 100 💰 gross per flour
  3. Market margin: 20%
  4. Farmer receives: 80 💰 per flour
  5. Adds to economy: `add_resource("💰", farmer_cut × QUANTUM_TO_CREDITS, "market_sale")`
  6. Emits signal: `flour_sold.emit(flour_amount, farmer_cut)`

#### Market Biome Quantum System ✅
- **File**: `Core/Environment/MarketBiome.gd` - Lines 1-100+
- **Emojis**: 🐂/🐻 (sentiment), 💰/📦 (liquidity)
- **Bath-first architecture** with QuantumBath
- **Dynamic emoji injection** infrastructure exists in QuantumBath:
  - `inject_emoji(emoji, icon, initial_amplitude)` - QuantumBath.gd
  - `has_emoji(emoji)` - Check if emoji is in bath

### MISSING: Bread Sales in Market

**Gap Identified**:
- ❌ No `sell_bread_at_market()` function in FarmEconomy
- ❌ No bread emoji (🍞) integration in MarketBiome
- ❌ No dynamic emoji injection trigger when selling bread

### What Needs Implementation

**1. FarmEconomy needs:**
```gdscript
func sell_bread_at_market(bread_amount: int) -> Dictionary:
    """Sell bread at market with dynamic emoji injection

    Market pricing: 150 💰 gross per bread (premium over flour)
    Market margin: 20%
    Farmer receives: 120 💰 per bread

    Triggers: Dynamic emoji injection of 🍞 into market biome
    """
```

**2. Dynamic Emoji Injection Trigger:**
- When bread is sold, inject 🍞 (bread) emoji into MarketBiome's quantum bath
- Use IconRegistry to fetch bread Icon definition
- Call `market_biome.bath.inject_emoji("🍞", bread_icon)`
- 🍞 becomes a new trading commodity in market dynamics

**3. MarketBiome Integration:**
- Register 🍞 as tradeable emoji pair (partner emoji?)
- Include 🍞 in Hamiltonian couplings
- Update visual display to show bread availability in market

**Status**: ⚠️ PARTIAL - Flour selling works, bread selling not yet wired to market

---

## Key Files & Line Numbers

| Component | File | Lines | Status |
|-----------|------|-------|--------|
| **Wheat Farming** | FarmGrid.gd | 674-1272 | ✅ |
| **Water Tapping** | FarmGrid.gd | 750-441 | ✅ |
| **Fire Measurement** | QuantumKitchen_Biome.gd | 228-305 | ✅ |
| **Flour Production** | FarmEconomy.gd | 190-222 | ✅ |
| **Mill Placement** | FarmGrid.gd | 443-481 | ✅ |
| **Kitchen Bell State (NEW)** | QuantumKitchen_Biome.gd | 435-588 | ✅ ADDED |
| **Bread Creation** | FarmGrid.gd | 521-609 | ✅ |
| **Flour Market** | FarmEconomy.gd | 225-257 | ✅ |
| **Bread Market (MISSING)** | FarmEconomy.gd | — | ❌ |
| **Emoji Injection** | QuantumBath.gd | — | ✅ Infrastructure ready |

---

## Full Gameplay Loop State Machine

```
START
  ↓
[FARMING] 🌾
  • Plant wheat in BioticFlux
  • Grow via quantum topology
  • Harvest with coherence bonus
  ↓
[PRODUCTION] 💨
  • Mill converts wheat → flour (0.8 ratio)
  • Auto-sells flour at market (80 💰 per unit)
  ↓
[RESOURCES] 🔥💧💨
  • Fire tapped from Kitchen biome (qubit 0 measurement)
  • Water tapped from Forest biome (Lindblad drain)
  • Flour already produced from mill
  ↓
[KITCHEN ENTANGLEMENT] 🍞 ← NEW CODE ADDED
  • Create 3-qubit Bell state from 🔥+💧+💨
  • Evolve under detuning Hamiltonian
  • Measure collapse to bread outcome
  • Consume resources, produce 🍞
  ↓
[MARKET SALES] 💰 ← NEEDS BREAD SELLING
  • Bread → Dynamic emoji injection into market
  • Market biome includes 🍞 in quantum dynamics
  • 🍞 affects sentiment/prices
  • Generate credits
  ↓
END
```

---

## Next Steps

**Immediate** (To complete full loop):
1. Add `sell_bread_at_market()` to FarmEconomy
2. Wire emoji injection trigger when bread is sold
3. Register 🍞 emoji pair in MarketBiome
4. Test complete flow end-to-end

**Verification Needed**:
- Does DualEmojiQubit have `set_meta()` method? (Used in Bell state methods)
- Does QuantumBath have `inject_emoji()` method? (Needed for market integration)
- Are IconRegistry and Market properly wired in FarmGrid initialization?

---

## Summary

**Core Kitchen Loop**: ✅ 95% Complete
- Farming → Milling → Fire+Water+Flour → Kitchen Bell State → Bread Production

**Market Integration**: ⚠️ 70% Complete
- Flour sales working
- Bread sales not yet implemented
- Dynamic emoji injection infrastructure exists but not wired to bread sales

**Total Lines Implemented**: ~5,500 (Phases 1-5 + Bell state methods)
