# Quest Board Page Cycling Implementation

## Summary

Successfully implemented the page cycling UX improvement for the quest board. The system now cycles complete pages of 4 quests instead of using slot pinning.

## What Changed

### Before (Pinning Model)
- F-cycling advanced only unpinned slots
- Locked and active quests stayed in their physical slot positions
- Dynamic page size (1-4 slots depending on pinned count)
- Complex filtering logic to exclude pinned faction quests

### After (Page Cycling Model)
- F-cycling advances ALL 4 slots to next complete page
- Each page remembers its locked/active quest states
- Fixed page size (4 slots per page)
- Wrap back to page 0 after last page
- Accepted quests bubble to top of quest pool (page 0)

## Key Features

### 1. Multi-Page Memory System
- **Data Structure**: `quest_pages: Dictionary` in GameState
- **Structure**: `{page_num: [slot0, slot1, slot2, slot3]}`
- **Runtime Cache**: `quest_pages_memory` in QuestBoard
- **Current Page Tracking**: `quest_board_current_page` persisted

### 2. Page Save/Load
- `_save_current_page()` - Captures current slot configuration
- `_load_page(page_num)` - Restores page from memory
- `_display_page_slots(page_slots)` - Sets slots to match saved state
- `_generate_and_display_page(page_num)` - Creates new page from quest pool

### 3. Bubble Sort on Accept
When a quest is accepted:
1. Quest moves to index 0 of quest pool
2. All pages regenerated with new ordering
3. Active quest appears on page 0
4. Easy to find and track active quests

### 4. Quest Removal on Complete/Abandon
When quest completed/abandoned/rejected:
1. Quest removed from pool entirely
2. All pages regenerated
3. Ensures consistency across all pages

### 5. Session Persistence
- Page memory saved on board close
- Page memory restored on board open
- Current page number restored
- Migration from old `quest_slots` format

## Files Modified

### Core/GameState/GameState.gd
- Added `@export var quest_pages: Dictionary = {}`
- Added `@export var quest_board_current_page: int = 0`
- Kept old `quest_slots` for migration

### UI/Panels/QuestBoard.gd

**New Variables:**
- `quest_pages_memory: Dictionary` - Runtime page cache
- `current_page: int` - Current page number (0, 1, 2...)
- `QUESTS_PER_PAGE: int = 4` - Fixed page size

**New Functions:**
- `_save_current_page()` - Save current slots to page memory
- `_load_page(page_num)` - Load page from memory
- `_display_page_slots(page_slots)` - Display saved page
- `_generate_and_display_page(page_num)` - Generate new page
- `_calculate_total_pages()` - Calculate total pages from pool
- `_regenerate_all_pages()` - Clear memory and regenerate

**Modified Functions:**
- `open_board()` - Added page restoration and migration logic
- `close_board()` - Added page save call
- `_refresh_slots()` - Simplified to use page system
- `on_f_pressed()` - Complete rewrite for page cycling
- `_update_page_display()` - New page indicator format
- `_accept_quest()` - Added bubble sort logic
- `_deliver_quest()` - Added pool removal and regeneration
- `_claim_quest()` - Added pool removal and regeneration
- `_reject_quest()` - Added pool removal and regeneration
- `_abandon_quest()` - Added pool removal and regeneration
- `_on_quest_completed()` - Added pool removal and regeneration
- `action_e_on_selected()` - Changed to save current page
- `action_r_on_selected()` - Added page save calls
- `_on_faction_selected()` - Changed to save current page

**Removed Functions:**
- `_auto_fill_slot()` - No longer needed
- `_save_slot_state()` - Replaced by `_save_current_page()`

## Behavior Examples

### Basic Cycling
```
Page 0: [Quest A, Quest B, Quest C, Quest D]
Press F → Page 1: [Quest E, Quest F, Quest G, Quest H]
Press F → Page 2: [Quest I, Quest J, Quest K, Quest L]
Press F → Page 0: [Quest A, Quest B, Quest C, Quest D]
```

### Locked Quest Persistence
```
Page 0: [Quest A (locked), Quest B, Quest C, Quest D]
Press F → Page 1: [Quest E, Quest F, Quest G, Quest H]
Press F → Page 0: [Quest A (still locked), Quest B, Quest C, Quest D]
```

### Bubble Sort on Accept
```
Page 0: [Quest A, Quest B, Quest C, Quest D]
Accept Quest B →
Page 0: [Quest B (active), Quest A, Quest C, Quest D]  ← B moved to top
Press F → Page 1: [Quest E, Quest F, Quest G, Quest H]
Press F → Page 0: [Quest B (still active), Quest A, Quest C, Quest D]
```

### Quest Removal on Complete
```
Page 0: [Quest A (active), Quest B, Quest C, Quest D]
Complete Quest A →
Page 0: [Quest B, Quest C, Quest D, Quest E]  ← A removed, pool shifted
```

## Migration

Old saves are automatically migrated:
- Old `quest_slots` array becomes page 0
- `quest_board_current_page` set to 0
- Old format still saved for backward compatibility

## UI Changes

Page indicator format changed from:
```
Page 1/3  |  68 quests  |  2 pinned  |  [F] Next
```

To:
```
Page 1/3  |  68 quests  |  2 visited  |  [F] Next
```

Shows:
- Current page (1-indexed for display)
- Total pages
- Total quests in pool
- Number of visited pages (pages in memory)

## Testing Checklist

✅ F key cycles all 4 slots to next page
✅ Wrap back to page 0 after last page
✅ Locked quests preserved on their page
✅ Active quests bubble to top of quest pool (page 0)
✅ Page state persists across board close/open
✅ Page state persists across game save/load
✅ Quest removal on complete/abandon works
✅ Page regeneration on quest state change works
✅ Migration from old format works

## Performance Notes

- Page memory is sparse (only visited pages stored)
- Quest pool regenerated on board open (existing behavior)
- All pages regenerated when quest pool changes (accept/complete/abandon)
- Minimal memory overhead (only 4 slot dicts per visited page)

## Edge Cases Handled

1. **Empty slots**: Shown as "Empty" with "?" reward
2. **Quest pool smaller than page**: Remaining slots shown as empty
3. **Last page wrap**: Correctly wraps to page 0
4. **Quest completion on non-current page**: All pages regenerated
5. **Old save format**: Automatically migrated to new format
6. **Board closed with unsaved changes**: Auto-saved on close
