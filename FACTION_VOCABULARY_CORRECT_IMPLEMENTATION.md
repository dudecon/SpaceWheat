# Faction Vocabulary Reward System - Correct Implementation

## Requirements

**For each accessible faction, roll vocabulary reward pair:**

### South Pole
- **Source**: Full faction signature (all emojis in signature)
- **Can be**: Known OR unknown to player
- **Weighting**: Player inventory amounts using log formula
  - `weight = 1.0 + log(1.0 + amount) / 3.0`
  - 0 credits → 1.0x (base weight)
  - 50 credits → ~1.6x
  - 500 credits → ~2.4x

### North Pole
- **Source**: Full faction signature
- **Must be**: Unknown to player (not in player_vocab)
- **Weighting**: Two factors combined
  1. **Connectedness to South**: Connection weight from Hamiltonian + Lindbladian terms
  2. **Player vocab connectivity**: Sum of connection weights to player's known emojis
- **Formula**: `combined_weight = connection_to_south * (1.0 + vocab_connectivity)`

## Implementation

### 1. VocabularyPairing.gd

#### New Function: `_roll_south_pole_from_signature()`

```gdscript
static func _roll_south_pole_from_signature(icon_registry, faction_signature: Array) -> Dictionary:
    """Roll south pole from faction signature, weighted by player inventory

    South pole can be known OR unknown to player.
    Weights use log formula: weight = 1.0 + log(1.0 + amount) / 3.0
    """

    # Build candidates from faction signature
    var candidates = {}
    for emoji in faction_signature:
        var amount = all_resources.get(emoji, 0)  # 0 if player has none
        var connections = get_connection_weights(emoji, icon_registry)

        if not connections.is_empty():
            # Log weighting (even if amount = 0, base weight = 1.0)
            var weight = 1.0 + log(1.0 + amount) / 3.0
            candidates[emoji] = {
                "weight": weight,
                "amount": amount,
                "connections": connections
            }

    # Weighted random selection
    # ...
```

#### New Function: `calculate_vocab_connectivity()`

```gdscript
static func calculate_vocab_connectivity(emoji: String, player_vocab: Array, icon_registry) -> float:
    """Calculate sum of connection weights from emoji to player's known vocabulary

    Returns sum of (|H| + L_in + L_out) for all connections to player_vocab emojis.

    Example:
        emoji 🔥 connected to:
            🌾 (weight 0.5), 👥 (weight 0.8), ⚡ (weight 0.3)
        player_vocab = [🌾, 👥, 💰]
        Returns: 0.5 + 0.8 = 1.3 (sum of weights to known emojis)
    """

    var connections = get_connection_weights(emoji, icon_registry)

    var total_connectivity = 0.0
    for target in connections:
        if target in player_vocab:
            total_connectivity += connections[target]["weight"]

    return total_connectivity
```

### 2. QuestTheming.gd

#### Updated Function: `_roll_vocabulary_reward_pair()`

```gdscript
static func _roll_vocabulary_reward_pair(
    faction_signature: Array,
    player_vocab: Array,
    bias_emojis: Array = []
) -> Dictionary:
    """Roll vocabulary reward pair from faction signature

    NEW STRATEGY:
    1. Roll SOUTH pole from faction signature (weighted by player inventory, can be known/unknown)
    2. Roll NORTH pole from faction signature (weighted by connectedness + player vocab, must be unknown)
    """

    # Step 1: Roll SOUTH from faction signature
    var south_result = VocabularyPairing._roll_south_pole_from_signature(
        icon_registry,
        faction_signature
    )

    var south = south_result.south
    var south_connections = south_result.get("connections", {})

    # Step 2: Build NORTH candidates from faction signature
    var north_candidates: Array = []
    for emoji in faction_signature:
        # Must be unknown to player
        if emoji in player_vocab:
            continue
        # Must be different from south
        if emoji == south:
            continue
        # Must be connected to south
        if not south_connections.has(emoji):
            continue

        # Calculate combined weight
        var connection_weight = south_connections[emoji].get("weight", 1.0)
        var vocab_connectivity = VocabularyPairing.calculate_vocab_connectivity(
            emoji,
            player_vocab,
            icon_registry
        )

        var combined_weight = connection_weight * (1.0 + vocab_connectivity)

        north_candidates.append({
            "emoji": emoji,
            "weight": combined_weight
        })

    # Step 3: Weighted roll for NORTH
    # ...
```

## Connection Weight Sources

Connection weights come from IconRegistry's Hamiltonian and Lindbladian terms:

```gdscript
// From VocabularyPairing.get_connection_weights()
connections[target]["weight"] = |H| + |L_in| + |L_out|

Where:
- H: Hamiltonian coupling (icon.hamiltonian_couplings[target])
- L_in: Lindblad incoming (icon.lindblad_incoming[source])
- L_out: Lindblad outgoing (icon.lindblad_outgoing[target])
```

## Examples

### Example 1: Granary Guilds

**Faction Signature:** [🌾, 👥, 💰, 🍂]

**Player Inventory:**
- 🌾: 100 credits
- 👥: 50 credits
- 💰: 10 credits
- 🍂: 0 credits

**Player Known:** [🌾, 👥, 💰]

**South Roll Weights:**
```
🌾: 1.0 + log(101)/3.0 ≈ 2.54  (highest - most inventory)
👥: 1.0 + log(51)/3.0 ≈ 2.31
💰: 1.0 + log(11)/3.0 ≈ 1.80
🍂: 1.0 + log(1)/3.0 = 1.0     (base weight - no inventory)
```

Most likely South: **🌾** (highest inventory)

**North Candidates** (assuming 🌾 rolled for South):

Let's say 🌾 connections:
- 👥: weight 0.8
- 💰: weight 0.5
- 🍂: weight 0.6

And 🍂 connections to player vocab:
- 🌾: weight 0.6
- 👥: weight 0.4
- Total vocab connectivity: 1.0

**North Roll Weight:**
```
🍂: 0.6 (connection to 🌾) * (1.0 + 1.0 vocab connectivity) = 1.2
```

Result: **🌾 (cost) → 🍂 (learn)**

### Example 2: Kilowatt Collective (Minimal Overlap)

**Faction Signature:** [⚡, 🔋, 💡, ⚙️]

**Player Inventory:**
- 🌾: 100 credits
- 👥: 50 credits
- ⚡: 5 credits

**Player Known:** [🌾, 👥, ⚡]

**South Roll Weights:**
```
⚡: 1.0 + log(6)/3.0 ≈ 1.60  (only one player has)
🔋: 1.0 (base - player has 0)
💡: 1.0 (base - player has 0)
⚙️: 1.0 (base - player has 0)
```

Most likely South: **⚡** (only one with inventory)

**North Candidates:**
- 🔋, 💡, ⚙️ (all unknown to player)
- Weighted by connection to ⚡ and vocab connectivity

### Example 3: No Unknown Emojis

**Faction Signature:** [🌾, 👥]

**Player Known:** [🌾, 👥]

**Result:**
- South rolls normally (🌾 or 👥)
- North candidates: **empty** (all known to player)
- Returns: `{north: "", south: "🌾", no_north_candidates: true}`
- Quest still offered but no vocabulary reward

## Key Differences from Previous Implementation

| Aspect | Old (Wrong) | New (Correct) |
|--------|-------------|---------------|
| **South source** | Available vocab only | Full faction signature |
| **South can be** | Only known emojis | Known OR unknown |
| **South weight** | Inventory (known only) | Inventory (all signature emojis) |
| **North source** | Signature + fallback to any | Signature only (no fallback) |
| **North must be** | Unknown | Unknown |
| **North weight** | Connection to South only | Connection + vocab connectivity |

## Benefits

1. **Thematic Consistency**: All rewards from faction signature
2. **Resource Discovery**: South can be unknown (teaches new resources)
3. **Vocabulary Expansion**: Weighted toward emojis connected to player's knowledge
4. **No Bypasses**: Removed fallback that ignored faction signature
5. **Inventory Incentive**: Having more of a faction's emojis increases chance they appear as South

## Testing Checklist

- [ ] Faction with mixed known/unknown emojis
  - Verify South can be unknown
  - Verify weights favor high-inventory emojis

- [ ] Faction with one emoji known
  - Verify South can roll the one known emoji
  - Verify North weighted by vocab connectivity

- [ ] Faction with all emojis known
  - Verify South rolls normally
  - Verify North returns empty (no_north_candidates)

- [ ] Player has inventory in non-faction emojis
  - Verify those emojis never appear in faction quests

- [ ] Check connection weight calculation
  - Verify uses Hamiltonian + Lindbladian terms
  - Verify vocab connectivity sums correctly

## Files Changed

- `Core/Quests/VocabularyPairing.gd`
  - Added `_roll_south_pole_from_signature()`
  - Added `calculate_vocab_connectivity()`

- `Core/Quests/QuestTheming.gd`
  - Updated `_roll_vocabulary_reward_pair()` to use new strategy
