# Faction Vocabulary Constraint Fix

## Problem

Quest vocabulary rewards (North/South emoji pairs) were being rolled from emojis outside the faction's vocabulary:

**Before:**
- **South pole**: Rolled from ALL player resources (any emoji)
- **North pole**: Tried faction signature first, but fell back to ANY connected emoji
- **Result**: Factions offering quests with emojis they don't care about

Example issue:
- Faction signature: [🌾, 👥, 🍂]
- Quest reward showed: 💰/⚡ (neither in faction vocabulary)

## Solution

Both North AND South poles now come from **faction's available vocabulary**:

```
Available Vocabulary = Faction Signature ∩ Player Known Emojis
```

**After:**
- **South pole**: Rolled from faction's available vocabulary (weighted by player resources)
- **North pole**: Rolled from faction signature (connected to South, unknown to player)
- **Result**: All quest rewards thematically consistent with faction

## Implementation

### 1. QuestTheming.gd: `_roll_vocabulary_reward_pair()`

**Changed behavior:**

```gdscript
# Step 1: Calculate available vocabulary
var available_vocab: Array = []
for emoji in faction_signature:
    if emoji in player_vocab:
        available_vocab.append(emoji)

# Step 2: Roll SOUTH from available vocabulary
var south_result = VocabularyPairing._roll_south_pole_constrained(
    icon_registry,
    available_vocab  # ← Constrained to faction!
)

# Step 3: Roll NORTH from faction signature (connected to South)
# (Already constrained, just removed fallback that ignored faction)
```

**Removed fallback:**
```gdscript
# OLD: Fallback to ANY emoji if no faction matches
if north_candidates.is_empty():
    for emoji in south_connections:
        if emoji not in player_vocab and emoji != south:
            north_candidates.append(...)  # ← REMOVED
```

### 2. VocabularyPairing.gd: New Function

Added `_roll_south_pole_constrained()`:

```gdscript
static func _roll_south_pole_constrained(icon_registry, allowed_vocab: Array) -> Dictionary:
    """Roll south pole from constrained vocabulary (faction-specific)"""

    # Only consider emojis in allowed_vocab
    var candidates = {}
    for emoji in allowed_vocab:
        var amount = all_resources.get(emoji, 0)
        if amount > 0:
            var connections = get_connection_weights(emoji, icon_registry)
            if not connections.is_empty():
                candidates[emoji] = {
                    "weight": 1.0 + log(1.0 + amount) / 3.0,
                    "amount": amount,
                    "connections": connections
                }

    # Weighted random selection from candidates
    # ...
```

## Examples

### Example 1: Granary Guilds

**Faction Signature:** [🌾, 👥, 💰, 🍂]

**Player Known:** [🌾, 👥, 💰]

**Available Vocabulary:** [🌾, 👥, 💰] (intersection)

**Possible Quest Rewards:**
- 🌾 (cost) → 🍂 (learn) ✅ (🌾 in available, 🍂 in faction)
- 👥 (cost) → 🍂 (learn) ✅ (👥 in available, 🍂 in faction)
- 💰 (cost) → 🍂 (learn) ✅ (💰 in available, 🍂 in faction)

**Impossible Rewards:**
- ⚡ (cost) → anything ❌ (⚡ not in faction signature)
- anything → 🔥 (learn) ❌ (🔥 not in faction signature)

### Example 2: Kilowatt Collective

**Faction Signature:** [⚡, 🔋, 💡, ⚙️]

**Player Known:** [🌾, 👥, ⚡]

**Available Vocabulary:** [⚡] (only one overlap!)

**Possible Quest Rewards:**
- ⚡ (cost) → 🔋 (learn) ✅ (if connected)
- ⚡ (cost) → 💡 (learn) ✅ (if connected)
- ⚡ (cost) → ⚙️ (learn) ✅ (if connected)

**Impossible Rewards:**
- 🌾 (cost) → anything ❌ (🌾 not in faction signature)

### Example 3: No Overlap

**Faction Signature:** [🔥, 🕯️, 📿]

**Player Known:** [🌾, 👥]

**Available Vocabulary:** [] (no overlap)

**Result:** Faction is **inaccessible** - returns error:
```json
{
    "error": "no_vocabulary_overlap",
    "message": "Learn more about Sacred Flame Keepers's interests first...",
    "required_emojis": ["🔥", "🕯️", "📿"]
}
```

## Behavior Changes

### Before
```
Player has: [🌾=50, 👥=20, 💰=30, ⚡=10, 🔥=5]
Faction signature: [🌾, 👥, 🍂]

Quest reward: 💰 (cost) → ⚡ (learn)
              ↑ Not in faction!  ↑ Not in faction!
```

### After
```
Player has: [🌾=50, 👥=20, 💰=30, ⚡=10, 🔥=5]
Faction signature: [🌾, 👥, 🍂]
Available vocab: [🌾, 👥]

Quest reward: 🌾 (cost) → 🍂 (learn)
              ↑ In available!  ↑ In faction signature!
```

## Edge Cases Handled

### 1. Player has resources, but not in faction signature
**Before:** Quest used any resource
**After:** Faction is inaccessible until player learns faction emojis

### 2. All faction emojis already known
**Before:** Could return empty north pole
**After:** Returns `{north: "", south: south_emoji, no_north_candidates: true}`
- Quest still offered (for resource delivery)
- No vocabulary reward (already known everything)

### 3. South emoji has no connections to unknown faction emojis
**Before:** Fell back to ANY connected emoji
**After:** Returns `no_north_candidates` (no fallback bypass)

## Testing

Test these scenarios:

1. **Basic constraint**: Faction with [🌾, 👥, 🍂], player knows [🌾, 👥]
   - Verify rewards only use 🌾, 👥, 🍂

2. **No overlap**: Faction with [🔥, 🕯️], player knows [🌾, 👥]
   - Verify faction shows as inaccessible

3. **All known**: Faction with [🌾, 👥], player knows [🌾, 👥]
   - Verify quest offered but no north pole

4. **Resource constraint**: Player has [🌾=50, ⚡=10], faction with [🌾, 👥]
   - Verify only 🌾 used for south (not ⚡)

## Files Changed

- `Core/Quests/QuestTheming.gd` - Updated `_roll_vocabulary_reward_pair()`
- `Core/Quests/VocabularyPairing.gd` - Added `_roll_south_pole_constrained()`

## Migration Notes

No save file migration needed - this only affects new quest generation.
Existing offered quests retain their pre-rolled rewards.
