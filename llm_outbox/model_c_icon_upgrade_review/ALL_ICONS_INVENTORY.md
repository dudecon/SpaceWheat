# SpaceWheat Icons - Complete Inventory
**Generated:** 2026-01-07
**Source:** /home/tehcr33d/ws/SpaceWheat/Core/Icons/CoreIcons.gd

This document provides a comprehensive inventory of all icons defined in the SpaceWheat analog quantum model.

---

## Table of Contents
1. [Celestial Icons (Drivers)](#celestial-icons-drivers)
2. [Flora Icons (Producers)](#flora-icons-producers)
3. [Fauna Icons (Consumers)](#fauna-icons-consumers)
4. [Elemental Icons (Abiotic)](#elemental-icons-abiotic)
5. [Abstract Icons (Conceptual)](#abstract-icons-conceptual)
6. [Reserved Icons (Future Expansion)](#reserved-icons-future-expansion)
7. [Market Icons (Economic Dynamics)](#market-icons-economic-dynamics)
8. [Kitchen Icons (Production/Cooking)](#kitchen-icons-production-cooking)
9. [Summary Statistics](#summary-statistics)

---

## Celestial Icons (Drivers)

### ☀ Sol (Sun)
- **Emoji:** ☀
- **Display Name:** Sol
- **Description:** The eternal light that drives all life
- **Self Energy:** 1.0
- **Self Energy Driver:** cosine
  - Frequency: 0.05 cycles/sec
  - Phase: 0.0
  - Amplitude: 1.0
- **Hamiltonian Couplings:**
  - 🌙 Moon: 0.8 (day/night opposition)
  - 🌿 Vegetation: 0.3
  - 🌾 Wheat: 0.4
  - 🌱 Seedling: 0.3
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** celestial, driver, light, eternal
- **Trophic Level:** Not specified
- **Special Flags:** is_driver=true, is_eternal=true

---

### 🌙 Luna (Moon)
- **Emoji:** 🌙
- **Display Name:** Luna
- **Description:** The pale companion, ruler of night and tides
- **Self Energy:** 0.8
- **Self Energy Driver:** sine (90° phase shift from sun)
  - Frequency: 0.05 cycles/sec
  - Phase: π/2
  - Amplitude: 1.0
- **Hamiltonian Couplings:**
  - ☀ Sun: 0.8
  - 🍄 Mushroom: 0.6 (strong coupling)
  - 💧 Water: 0.4 (tides)
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** celestial, driver, lunar, eternal
- **Trophic Level:** Not specified
- **Special Flags:** is_driver=true, is_eternal=true

---

## Flora Icons (Producers)

### 🌾 Wheat
- **Emoji:** 🌾
- **Display Name:** Wheat
- **Description:** The golden grain, sustainer of civilizations
- **Self Energy:** 0.1
- **Hamiltonian Couplings:**
  - ☀ Sun: 0.5
  - 💧 Water: 0.4
  - ⛰ Soil: 0.3
- **Lindblad Incoming:**
  - ☀ Sun: 0.0267 (10x faster than original 0.00267)
  - 💧 Water: 0.0167 (10x faster than original 0.00167)
  - ⛰ Soil: 0.0067 (10x faster than original 0.00067)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.02
- **Decay Target:** 🍂 Organic Matter
- **Energy Couplings:**
  - ☀ Sun: +0.08 (positive - grows from sun)
  - 💧 Water: +0.05 (positive - grows from water)
- **Tags:** flora, cultivated, producer
- **Trophic Level:** 1 (Producer)

---

### 🍄 Mushroom
- **Emoji:** 🍄
- **Display Name:** Mushroom
- **Description:** The moon-child, decomposer of dead things
- **Self Energy:** 0.05
- **Hamiltonian Couplings:**
  - 🌙 Moon: 0.6 (strong coupling)
  - 🍂 Organic Matter: 0.5
- **Lindblad Incoming:**
  - 🌙 Moon: 0.06 (10x faster than original 0.006)
  - 🍂 Organic Matter: 0.12 (10x faster than original 0.012)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.03
- **Decay Target:** 🍂 Organic Matter
- **Energy Couplings:**
  - ☀ Sun: -0.20 (negative - takes damage from sun)
  - 🌙 Moon: +0.40 (positive - grows from moon)
- **Tags:** flora, decomposer, lunar
- **Trophic Level:** 1 (Producer/Decomposer)

---

### 🌿 Vegetation
- **Emoji:** 🌿
- **Display Name:** Vegetation
- **Description:** The green foundation of all ecosystems
- **Self Energy:** 0.1
- **Hamiltonian Couplings:**
  - ☀ Sun: 0.6 (strong coupling)
  - 💧 Water: 0.5
  - 🍂 Organic Matter: 0.3 (nutrient cycling)
- **Lindblad Incoming:**
  - ☀ Sun: 0.10 (10x faster than original 0.010)
  - 💧 Water: 0.06 (10x faster than original 0.006)
  - 🍂 Organic Matter: 0.04 (10x faster than original 0.004)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.025
- **Decay Target:** 🍂 Organic Matter
- **Tags:** flora, producer, foundation
- **Trophic Level:** 1 (Producer)

---

### 🌱 Seedling
- **Emoji:** 🌱
- **Display Name:** Seedling
- **Description:** The promise of life, pure potential
- **Self Energy:** 0.05
- **Hamiltonian Couplings:**
  - ☀ Sun: 0.4
  - 💧 Water: 0.6 (strong coupling - needs it to germinate)
  - ⛰ Soil: 0.4
- **Lindblad Incoming:** None
- **Lindblad Outgoing:**
  - 🌿 Vegetation: 0.08 (10x faster than original 0.008)
- **Decay Rate:** 0.04 (higher decay - many seeds fail)
- **Decay Target:** 🍂 Organic Matter
- **Tags:** flora, potential, fragile
- **Trophic Level:** 1 (Producer)

---

## Fauna Icons (Consumers)

### 🐺 Wolf
- **Emoji:** 🐺
- **Display Name:** Wolf
- **Description:** The apex hunter, keeper of balance
- **Self Energy:** -0.05 (slight negative - needs food to survive)
- **Hamiltonian Couplings:**
  - 🐇 Rabbit: 0.6 (strong coupling - hunting awareness)
  - 🦌 Deer: 0.5
  - 🌳 Forest: 0.2 (weak coupling - shelter)
- **Lindblad Incoming:**
  - 🐇 Rabbit: 0.15 (10x faster than original 0.015)
  - 🦌 Deer: 0.12 (10x faster than original 0.012)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.03
- **Decay Target:** 💀 Death/Labor
- **Tags:** fauna, predator, apex
- **Trophic Level:** 3 (Carnivore)

---

### 🐇 Rabbit
- **Emoji:** 🐇
- **Display Name:** Rabbit
- **Description:** The swift reproducer, food for many
- **Self Energy:** 0.02 (slight positive - reproductive)
- **Hamiltonian Couplings:**
  - 🌿 Vegetation: 0.5 (food)
  - 🐺 Wolf: 0.6 (strong coupling - danger awareness)
  - 🦅 Eagle: 0.4 (danger)
- **Lindblad Incoming:**
  - 🌿 Vegetation: 0.10 (10x faster than original 0.010)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.05
- **Decay Target:** 💀 Death/Labor
- **Tags:** fauna, herbivore, prey
- **Trophic Level:** 2 (Herbivore)

---

### 🦌 Deer
- **Emoji:** 🦌
- **Display Name:** Deer
- **Description:** The graceful grazer of the forest
- **Self Energy:** 0.01
- **Hamiltonian Couplings:**
  - 🌿 Vegetation: 0.6 (strong coupling)
  - 🌳 Forest: 0.4
  - 🐺 Wolf: 0.5 (danger)
- **Lindblad Incoming:**
  - 🌿 Vegetation: 0.08 (10x faster than original 0.008)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.04
- **Decay Target:** 💀 Death/Labor
- **Tags:** fauna, herbivore, large
- **Trophic Level:** 2 (Herbivore)

---

### 🦅 Eagle
- **Emoji:** 🦅
- **Display Name:** Eagle
- **Description:** The sky-lord, swift death from above
- **Self Energy:** -0.03
- **Hamiltonian Couplings:**
  - 🐇 Rabbit: 0.5
  - 🐭 Mouse: 0.4
- **Lindblad Incoming:**
  - 🐇 Rabbit: 0.10 (10x faster than original 0.010)
  - 🐭 Mouse: 0.08 (10x faster than original 0.008)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.025
- **Decay Target:** 💀 Death/Labor
- **Tags:** fauna, predator, aerial
- **Trophic Level:** 3 (Carnivore)

---

## Elemental Icons (Abiotic)

### 💧 Water
- **Emoji:** 💧
- **Display Name:** Water
- **Description:** The flow of life, essence of all things
- **Self Energy:** 0.0 (neutral)
- **Hamiltonian Couplings:**
  - 🌙 Moon: 0.4 (tides)
  - 🌿 Vegetation: 0.3
  - 🌾 Wheat: 0.3
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** element, water, abiotic, essential
- **Trophic Level:** 0 (Abiotic)
- **Special Flags:** is_eternal=true

---

### ⛰ Soil
- **Emoji:** ⛰
- **Display Name:** Soil
- **Description:** The foundation, holder of minerals and memory
- **Self Energy:** 0.0
- **Hamiltonian Couplings:**
  - 🌿 Vegetation: 0.3
  - 🌾 Wheat: 0.3
  - 🍂 Organic Matter: 0.4
- **Lindblad Incoming:**
  - 🍂 Organic Matter: 0.02 (10x faster than original 0.002)
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** element, soil, abiotic, foundation
- **Trophic Level:** 0 (Abiotic)
- **Special Flags:** is_eternal=true (NOTE: Bug in code - sets water.is_eternal instead of soil.is_eternal)

---

### 🍂 Organic Matter
- **Emoji:** 🍂
- **Display Name:** Organic Matter
- **Description:** The cycle's currency, death's gift to life
- **Self Energy:** 0.0
- **Hamiltonian Couplings:**
  - 🌿 Vegetation: 0.3 (nutrient cycling)
  - 🍄 Mushroom: 0.5 (strong coupling)
  - ⛰ Soil: 0.3
- **Lindblad Incoming:** None (receives from many decay_rate terms)
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** element, decay, recycling, foundation
- **Trophic Level:** 0 (Abiotic/decomposed)

---

## Abstract Icons (Conceptual)

### 💀 Death/Labor
- **Emoji:** 💀
- **Display Name:** Death/Labor
- **Description:** The end and the beginning, the price of life
- **Self Energy:** 0.0
- **Hamiltonian Couplings:**
  - 🍂 Organic Matter: 0.4
  - 👥 Human Effort: 0.3
- **Lindblad Incoming:** None (receives from many decay_target terms)
- **Lindblad Outgoing:**
  - 🍂 Organic Matter: 0.05 (10x faster than original 0.005)
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** abstract, death, transformation
- **Trophic Level:** 0 (Abstract)

---

### 👥 Human Effort
- **Emoji:** 👥
- **Display Name:** Human Effort
- **Description:** The will applied, civilization's engine
- **Self Energy:** 0.05
- **Hamiltonian Couplings:**
  - 🌾 Wheat: 0.5 (strong coupling - cultivation)
  - 💀 Death/Labor: 0.3
  - ⛰ Soil: 0.3 (working the land)
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** abstract, labor, human, cultivation
- **Trophic Level:** 0 (Abstract)

---

## Reserved Icons (Future Expansion)

### 🌳 Forest
- **Emoji:** 🌳
- **Display Name:** Forest
- **Description:** The living cathedral, home to multitudes
- **Self Energy:** 0.0
- **Hamiltonian Couplings:**
  - 🌿 Vegetation: 0.4
  - 🐺 Wolf: 0.2 (weak coupling - shelter)
  - 🦌 Deer: 0.3
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** ecosystem, forest, structure
- **Trophic Level:** 0 (Ecosystem)

---

### 🐭 Mouse
- **Emoji:** 🐭
- **Display Name:** Mouse
- **Description:** The tiny survivor, food for many
- **Self Energy:** 0.01
- **Hamiltonian Couplings:**
  - 🌿 Vegetation: 0.4
  - 🦅 Eagle: 0.5 (danger)
  - 🐜 Bug: 0.2 (weak coupling)
- **Lindblad Incoming:**
  - 🌿 Vegetation: 0.06 (10x faster than original 0.006)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.06
- **Decay Target:** 💀 Death/Labor
- **Tags:** fauna, herbivore, small, prey
- **Trophic Level:** 2 (Herbivore)

---

### 🐦 Bird
- **Emoji:** 🐦
- **Display Name:** Bird
- **Description:** The wanderer, seed-carrier and singer
- **Self Energy:** 0.0
- **Hamiltonian Couplings:**
  - 🌿 Vegetation: 0.3
  - 🐜 Bug: 0.4
  - 🌱 Seedling: 0.3 (dispersal)
- **Lindblad Incoming:**
  - 🐜 Bug: 0.07 (10x faster than original 0.007)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.04
- **Decay Target:** 💀 Death/Labor
- **Tags:** fauna, omnivore, disperser
- **Trophic Level:** 2 (Omnivore)

---

### 🐜 Bug
- **Emoji:** 🐜
- **Display Name:** Bug
- **Description:** The tireless recycler, foundation of the food web
- **Self Energy:** 0.02
- **Hamiltonian Couplings:**
  - 🍂 Organic Matter: 0.5 (strong coupling)
  - 🌿 Vegetation: 0.3
  - 🐦 Bird: 0.4 (danger)
- **Lindblad Incoming:**
  - 🍂 Organic Matter: 0.08 (10x faster than original 0.008)
- **Lindblad Outgoing:** None
- **Decay Rate:** 0.05
- **Decay Target:** 🍂 Organic Matter
- **Tags:** fauna, decomposer, small
- **Trophic Level:** 1 (Decomposer/Detritivore)

---

### 🏪 Market
- **Emoji:** 🏪
- **Display Name:** Market
- **Description:** The meeting place, where value flows
- **Self Energy:** 0.0
- **Hamiltonian Couplings:**
  - 🌾 Wheat: 0.4
  - 👥 Human Effort: 0.5
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** abstract, economy, exchange
- **Trophic Level:** 0 (Abstract/Economic)

---

## Market Icons (Economic Dynamics)

### 🐂 Bull Market
- **Emoji:** 🐂
- **Display Name:** Bull Market
- **Description:** Rising prices, optimistic sentiment
- **Self Energy:** 0.5
- **Self Energy Driver:** cosine
  - Frequency: 1/30 (30-second period)
  - Phase: 0.0
  - Amplitude: 0.8
- **Hamiltonian Couplings:**
  - 🐻 Bear: 0.9 (strong coupling - opposition)
  - 💰 Money: 0.4 (money flows to bull markets)
  - 🏛️ Stability: 0.3 (stability moderates bulls)
- **Lindblad Incoming:**
  - 💰 Money: 0.08 (10x faster than original 0.008)
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** market, driver, sentiment, rising
- **Trophic Level:** Not specified
- **Special Flags:** is_driver=true

---

### 🐻 Bear Market
- **Emoji:** 🐻
- **Display Name:** Bear Market
- **Description:** Falling prices, pessimistic sentiment
- **Self Energy:** -0.5
- **Self Energy Driver:** sine (180° out of phase with bull)
  - Frequency: 1/30 (30-second period)
  - Phase: π
  - Amplitude: 0.8
- **Hamiltonian Couplings:**
  - 🐂 Bull: 0.9 (strong coupling - opposition)
  - 📦 Goods: 0.4 (goods accumulate in bear markets)
  - 🏚️ Chaos: 0.3 (chaos amplifies bears)
- **Lindblad Incoming:**
  - 📦 Goods: 0.06 (10x faster than original 0.006)
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** market, driver, sentiment, falling
- **Trophic Level:** Not specified
- **Special Flags:** is_driver=true

---

### 💰 Money
- **Emoji:** 💰
- **Display Name:** Money
- **Description:** Liquid capital, ready to trade
- **Self Energy:** 0.1
- **Hamiltonian Couplings:**
  - 📦 Goods: 0.6 (money exchanges for goods)
  - 🐂 Bull: 0.3 (flows toward bull markets)
  - 🏛️ Stability: 0.2 (stable markets attract capital)
- **Lindblad Incoming:** None
- **Lindblad Outgoing:**
  - 📦 Goods: 0.05 (10x faster than original 0.005)
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** market, currency, liquidity
- **Trophic Level:** Not specified

---

### 📦 Goods
- **Emoji:** 📦
- **Display Name:** Goods
- **Description:** Commodities and inventory
- **Self Energy:** 0.0
- **Hamiltonian Couplings:**
  - 💰 Money: 0.6 (goods exchange for money)
  - 🐻 Bear: 0.2 (accumulate in bear markets)
- **Lindblad Incoming:** None
- **Lindblad Outgoing:**
  - 💰 Money: 0.04 (10x faster than original 0.004)
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** market, commodity, inventory
- **Trophic Level:** Not specified

---

### 🏛️ Stable Markets
- **Emoji:** 🏛️
- **Display Name:** Stable Markets
- **Description:** Orderly, predictable trading
- **Self Energy:** 0.2
- **Hamiltonian Couplings:**
  - 🏚️ Chaos: 0.7 (opposition to chaos)
  - 💰 Money: 0.3 (attracts capital)
  - 🐂 Bull: 0.2 (moderates bulls)
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** market, stability, order
- **Trophic Level:** Not specified

---

### 🏚️ Chaotic Markets
- **Emoji:** 🏚️
- **Display Name:** Chaotic Markets
- **Description:** Volatile, unpredictable swings
- **Self Energy:** -0.1
- **Hamiltonian Couplings:**
  - 🏛️ Stability: 0.7 (opposition to stability)
  - 🐻 Bear: 0.4 (amplifies bear markets)
- **Lindblad Incoming:** None
- **Lindblad Outgoing:**
  - 🏛️ Stability: 0.03 (10x faster than original 0.003)
- **Decay Rate:** 0.02
- **Decay Target:** 🏛️ Stable Markets
- **Tags:** market, volatility, chaos
- **Trophic Level:** Not specified

---

## Kitchen Icons (Production/Cooking)

### 🔥 Heat
- **Emoji:** 🔥
- **Display Name:** Heat
- **Description:** The oven's fire, transforming ingredients
- **Self Energy:** 0.8
- **Self Energy Driver:** cosine
  - Frequency: 1/15 (15-second period)
  - Phase: 0.0
  - Amplitude: 1.0
- **Hamiltonian Couplings:**
  - ❄️ Cold: 0.8 (opposition to cold)
  - 🍞 Bread: 0.5 (drives bread production)
  - 🌾 Wheat: 0.3 (transforms wheat)
- **Lindblad Incoming:**
  - 🍞 Bread: 0.1 (10x faster than original 0.01)
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** kitchen, driver, heat, transformation
- **Trophic Level:** Not specified
- **Special Flags:** is_driver=true

---

### ❄️ Cold
- **Emoji:** ❄️
- **Display Name:** Cold
- **Description:** The oven rests, preserving ingredients
- **Self Energy:** -0.3
- **Self Energy Driver:** sine (180° out of phase with fire)
  - Frequency: 1/15 (15-second period)
  - Phase: π
  - Amplitude: 0.8
- **Hamiltonian Couplings:**
  - 🔥 Heat: 0.8 (opposition to heat)
  - 🌾 Wheat: 0.4 (preserves raw wheat)
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** kitchen, driver, cold, preservation
- **Trophic Level:** Not specified
- **Special Flags:** is_driver=true

---

### 💧 Water (Kitchen Context)
- **Emoji:** 💧
- **Display Name:** Water
- **Description:** Moisture in the dough, essential for transformation
- **Self Energy:** 0.0 (neutral baseline)
- **Hamiltonian Couplings:**
  - 🔥 Heat: 0.2 (weak coupling - evaporation)
  - 🍞 Bread: 0.3 (contributes to bread)
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** kitchen, ingredient, moisture
- **Trophic Level:** 0
- **Special Flags:** is_eternal=true
- **NOTE:** Conditionally registered only if not already registered from Elements section

---

### 🏜️ Dry
- **Emoji:** 🏜️
- **Display Name:** Dry
- **Description:** Absence of moisture, dough loses plasticity
- **Self Energy:** 0.0 (neutral baseline)
- **Hamiltonian Couplings:**
  - 🔥 Heat: 0.3 (heat causes drying)
  - 💧 Water: 0.0 (direct opposition - orthogonal states)
- **Lindblad Incoming:** None
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** kitchen, absence, dryness
- **Trophic Level:** Not specified
- **Special Flags:** is_drain_target=false

---

### 💨 Flour
- **Emoji:** 💨
- **Display Name:** Flour
- **Description:** Processed grain, ready for transformation
- **Self Energy:** 0.1
- **Hamiltonian Couplings:**
  - 🌾 Wheat: 0.5 (comes from wheat - coupling for mill)
  - 🍞 Bread: 0.4 (transformed into bread)
- **Lindblad Incoming:**
  - 🌾 Wheat: 0.08 (10x faster than original 0.008)
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** kitchen, ingredient, processed
- **Trophic Level:** Not specified

---

### 🍞 Bread
- **Emoji:** 🍞
- **Display Name:** Bread
- **Description:** The fruit of labor and fire
- **Self Energy:** 0.0
- **Hamiltonian Couplings:**
  - 🌾 Wheat: 0.5 (connection to wheat input)
  - 🔥 Heat: 0.4 (created by heat)
- **Lindblad Incoming:**
  - 🌾 Wheat: 0.08 (10x faster than original 0.008)
  - 🔥 Heat: 0.05 (10x faster than original 0.005)
- **Lindblad Outgoing:** None
- **Decay Rate:** None
- **Decay Target:** None
- **Tags:** kitchen, product, food, processed
- **Trophic Level:** Not specified

---

## Summary Statistics

### Total Icons by Category
- **Celestial:** 2 icons (☀, 🌙)
- **Flora:** 4 icons (🌾, 🍄, 🌿, 🌱)
- **Fauna:** 4 icons (🐺, 🐇, 🦌, 🦅)
- **Elements:** 3 icons (💧, ⛰, 🍂)
- **Abstract:** 2 icons (💀, 👥)
- **Reserved:** 5 icons (🌳, 🐭, 🐦, 🐜, 🏪)
- **Market:** 6 icons (🐂, 🐻, 💰, 📦, 🏛️, 🏚️)
- **Kitchen:** 6 icons (🔥, ❄️, 💧, 🏜️, 💨, 🍞)
- **TOTAL:** 32 icons

### Icons by Type
- **Drivers (is_driver=true):** 4 icons (☀, 🌙, 🐂, 🐻, 🔥, ❄️) - 6 total
- **Eternal (is_eternal=true):** 4 icons (☀, 🌙, 💧, ⛰)
- **With Decay:** 17 icons
- **With Lindblad Incoming:** 18 icons
- **With Lindblad Outgoing:** 5 icons (🌱, 💀, 💰, 📦, 🏚️)

### Icons by Trophic Level
- **Level 0 (Abiotic/Abstract):** 10 icons (💧, ⛰, 🍂, 💀, 👥, 🌳, 🏪, 💧kitchen)
- **Level 1 (Producers/Decomposers):** 5 icons (🌾, 🍄, 🌿, 🌱, 🐜)
- **Level 2 (Herbivores/Omnivores):** 4 icons (🐇, 🦌, 🐭, 🐦)
- **Level 3 (Carnivores):** 2 icons (🐺, 🦅)
- **Unspecified:** 11 icons (mostly market and kitchen icons)

### Driver Frequencies
- **0.05 cycles/sec (20-second period):** Celestial drivers (☀, 🌙)
- **1/30 cycles/sec (30-second period):** Market drivers (🐂, 🐻)
- **1/15 cycles/sec (15-second period):** Kitchen drivers (🔥, ❄️)

### Notable Patterns

#### Strongest Hamiltonian Couplings (≥0.9)
- 🐂 Bull ↔ 🐻 Bear: 0.9 (market opposition)

#### Energy Couplings
Only 2 icons have explicit energy_couplings defined:
1. **🌾 Wheat:** ☀ Sun (+0.08), 💧 Water (+0.05)
2. **🍄 Mushroom:** ☀ Sun (-0.20), 🌙 Moon (+0.40)

#### Decay Targets
- **🍂 Organic Matter:** 7 icons decay here (🌾, 🍄, 🌿, 🌱, 🐜)
- **💀 Death/Labor:** 7 icons decay here (🐺, 🐇, 🦌, 🦅, 🐭, 🐦)
- **🏛️ Stability:** 1 icon decays here (🏚️)

#### Lindblad Rate Scaling
All Lindblad rates have been scaled 10x faster from their original values for improved gameplay visibility.

### Potential Issues Noted

1. **Line 302:** Bug - `water.is_eternal = true` should be `soil.is_eternal = true`
2. **💧 Water:** Defined twice - once in Elements (line 269) and once in Kitchen (line 600), with conditional registration to avoid duplication
3. **🌾 Wheat:** Referenced in Kitchen section (line 661) but defined in Flora section

---

**End of Inventory**
