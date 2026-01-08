# Quest Signature-Only Redesign

**Date:** 2026-01-07
**Status:** ✅ Implemented

---

## Problem

All factions were requesting wheat (🌾), making quests feel homogenous and breaking faction identity.

### Root Cause

1. **Player started with `["🌾", "🍄"]`** - wheat and mushroom
2. **Quest resources sampled from:** `faction_vocabulary ∩ player_vocabulary`
3. **Faction vocabulary included:** axial (12 emojis from bits) + signature (4-5 thematic emojis)
4. **Common factions (bit3=0) all had 🌾** in axial vocabulary
5. **Result:** 78% chance each quest requested wheat, 37% chance ALL 4 quests were wheat

### Example

**Millwright's Union:**
- Signature: `["⚙", "🏭", "🔩", "🍞", "🔨"]` (thematic!)
- Axial: `["📚", "🔮", "🌾", ...]` (from bit pattern)
- Old system: Requests **🌾** (only overlap with player's `["🌾", "🍄"]`)
- New system: Requests **⚙🏭🔩🍞🔨** (their signature!)

---

## Solution

### 1. Change Starter Vocabulary
```gdscript
// Core/GameState/GameState.gd:178
OLD: known_emojis = ["🌾", "🍄"]
NEW: known_emojis = ["🍞", "👥"]
```

**Rationale:** Bread and people match faction signatures (production/community themes), not axial vocabulary.

### 2. Use Signature-Only for Quest Requests
```gdscript
// Core/Quests/QuestTheming.gd:317-325
OLD: available_emojis = faction_vocab.all          // axial + signature
NEW: available_emojis = faction_vocab.signature    // signature only!
```

**Impact:**
- Quest resources MUST come from faction's 4-5 signature emojis
- Axial vocabulary still used for teaching/accessibility checks
- Factions feel distinct in their requests

### 3. Add Quest Generation Logging
```gdscript
// Core/Quests/QuestTheming.gd:14,318-343,240-298
VerboseConfig.debug("quest", "📚", "Quest gen: %s signature=%s axial=%s" % [...])
VerboseConfig.debug("quest", "🔍", "Player knows %s, faction signature %s → available %s" % [...])
VerboseConfig.debug("quest", "🎯", "Sampled %s (p=%.3f, roll=%.3f) from bath" % [...])
```

**Category:** `"quest"` - trace faction vocabulary, player overlap, and resource sampling

---

## Expected Results

### ✅ ZERO Wheat Requests
- Wheat (🌾) is NOT in any faction's signature
- Only appears in axial vocabulary for "Common" factions (bit3=0)
- Quest sampling can't select it

### ✅ Faction Variety
Each faction requests their thematic emojis:

| Faction | Signature | Quest Requests |
|---------|-----------|----------------|
| Granary Guilds | 🌱🍞💰🧺 | Bread, seeds, gold, baskets |
| Millwright's Union | ⚙🏭🔩🍞🔨 | Gears, industry, bread |
| Kilowatt Collective | 🔋⚡🔌💡🏭 | Batteries, energy, lights |
| Seedvault Curators | 🌱🔬🧬🗄🌾 | Seeds, science, specimens |
| Lantern Cant | 🔦🌃🗝🔮🎭 | Lanterns, keys, mystery |

### ✅ Distinct Faction Identity
- Quests reflect faction themes
- No "everyone wants wheat" homogenization
- Player learns faction personality through requests

---

## Testing

1. **Boot game:** `godot`
2. **Open Quest Board:** Press `C` key
3. **Observe quests:** Should see variety, NO wheat (🌾)
4. **Check logs:** Enable `VerboseConfig` quest category to see:
   - `"Quest gen: <faction> signature=..."` - faction vocabulary
   - `"Player knows ..., faction signature ... → available ..."` - overlap filtering
   - `"Sampled <emoji> (p=...) from bath"` - resource selection

---

## Architecture

### Vocabulary System (Preserved)

**Faction vocabulary still has TWO components:**
1. **Axial Vocabulary (12 emojis)** - From bit pattern, used for faction accessibility
2. **Signature (4-5 emojis)** - Thematic cluster, used for quest requests

**Separation of Concerns:**
- **Quest requests:** Signature only
- **Teaching/accessibility:** Full vocabulary (axial + signature)
- **Faction recognition:** Full vocabulary

### Quest Generation Flow

```
QuestManager.offer_all_faction_quests()
  ↓
  For each faction:
    ↓
    Get faction vocabulary (signature + axial)
    ↓
    Filter signature to player vocabulary
    ↓
    IF overlap.is_empty(): faction inaccessible
    ELSE: sample resource from (signature ∩ player_vocab)
    ↓
    Generate quest with sampled resource
```

---

## Files Modified

1. **Core/GameState/GameState.gd**
   - Line 178: Changed starter vocabulary to `["🍞", "👥"]`

2. **Core/Quests/QuestTheming.gd**
   - Line 14: Added VerboseConfig preload
   - Lines 317-325: Changed to use `faction_vocab.signature` instead of `faction_vocab.all`
   - Lines 333-334: Error hints now show signature, not full vocabulary
   - Lines 240-298: Added logging to `_sample_from_allowed_emojis()`
   - Lines 318-343: Added logging to `generate_quest()`

---

## Future Enhancements

1. **Dynamic starter vocabulary** - Could base on current biome state
2. **Signature-first weighted sampling** - Prefer signature emojis when both available
3. **Teachable vocabulary hints** - Show what player could learn from faction
4. **Vocabulary progression rewards** - Unlock emojis as quest rewards

---

## Notes

- This preserves quantum alignment system (FactionStateMatcher still generates abstract parameters)
- Biome state still influences quest difficulty/rewards through alignment scoring
- Full vocabulary system intact for future features (teaching, accessibility, faction browsing)
- Logging can be toggled with VerboseConfig quest category
