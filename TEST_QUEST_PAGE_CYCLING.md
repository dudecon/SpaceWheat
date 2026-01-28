# Quest Page Cycling - Test Scenarios

## Test 1: Basic Page Cycling

**Steps:**
1. Open quest board (Tab)
2. Observe Page 1 with 4 quests
3. Press F
4. Verify Page 2 with different 4 quests
5. Press F multiple times
6. Verify wraps back to Page 1

**Expected:**
- All 4 slots change on each F press
- Page indicator updates: "Page 1/N", "Page 2/N", etc.
- Wrap back to page 1 after last page

## Test 2: Locked Quest Persistence

**Steps:**
1. Open quest board
2. Select slot U (top-left)
3. Press E to lock quest in slot U
4. Note the quest faction name
5. Press F to go to page 2
6. Press F to return to page 1
7. Verify slot U still has same quest and is locked

**Expected:**
- Locked quest preserved on page 1
- Lock icon still shows
- Same faction in same slot position

## Test 3: Accepted Quest Bubble Sort

**Steps:**
1. Open quest board (page 1)
2. Note quest in slot I (top-right)
3. Press I to select it
4. Press Q to accept quest
5. Verify quest moved to slot U and shows "Active"
6. Press F to go to page 2
7. Press F to return to page 1
8. Verify active quest still in slot U

**Expected:**
- Accepted quest bubbles to slot U (top-left)
- Shows "Active" status
- Preserved when cycling back to page 1
- Other quests shifted down in pool

## Test 4: Multiple Page Memory

**Steps:**
1. Open quest board (page 1)
2. Lock quest in slot U
3. Press F to page 2
4. Lock quest in slot I
5. Press F to page 3
6. Lock quest in slot O
7. Press F back to page 1
8. Verify locked quest in U
9. Press F to page 2
10. Verify locked quest in I
11. Press F to page 3
12. Verify locked quest in O

**Expected:**
- Each page remembers its locked quests
- Page indicator shows "3 visited"
- All locks preserved in correct positions

## Test 5: Quest Completion Removal

**Steps:**
1. Open quest board
2. Accept a DELIVERY quest (Q key)
3. Note total quest count in page indicator
4. Gather required resources
5. Press Q to deliver quest
6. Verify quest removed from board
7. Verify quest count decreased by 1
8. Verify slot filled with next quest from pool

**Expected:**
- Completed quest removed from pool
- Total quest count decreases
- Slot auto-filled with next available quest
- All pages regenerated

## Test 6: Quest Abandonment

**Steps:**
1. Accept a quest (Q key)
2. Verify it shows "Active"
3. Press E to abandon
4. Verify quest removed from board
5. Verify slot filled with new quest

**Expected:**
- Abandoned quest removed from pool
- New quest appears in slot
- Total quest count decreases

## Test 7: Save/Load Persistence

**Steps:**
1. Open quest board
2. Lock quests on pages 1, 2, 3
3. Accept a quest
4. Close board (ESC)
5. Save game
6. Exit and reload save
7. Open quest board
8. Verify current page restored
9. Cycle through pages
10. Verify all locked quests preserved
11. Verify active quest preserved

**Expected:**
- Current page number restored
- All page memory restored
- Locked quests in correct positions
- Active quest in correct position

## Test 8: Edge Case - Small Quest Pool

**Steps:**
1. Start new game (only starter emojis)
2. Open quest board
3. Note small number of accessible quests
4. Press F to cycle
5. Verify empty slots if fewer than 4 quests per page

**Expected:**
- Empty slots show "Empty" with "?"
- Page count correct for small pool
- No crashes or errors

## Test 9: Edge Case - Quest Pool Expansion

**Steps:**
1. Open quest board, note quest count
2. Close board
3. Complete a quest to learn new emoji pair
4. Open quest board
5. Verify quest count increased
6. Press F to cycle through new pages

**Expected:**
- More quests available after learning emoji
- More pages available
- New quests appear in pool

## Test 10: Page Indicator Display

**Steps:**
1. Open quest board
2. Note page indicator format
3. Cycle through pages
4. Check indicator updates

**Expected Display:**
```
Page 1/5  |  68 quests  |  0 visited  |  [F] Next
Page 2/5  |  68 quests  |  1 visited  |  [F] Next
Page 3/5  |  68 quests  |  2 visited  |  [F] Next
```

## Performance Test

**Steps:**
1. Learn many emojis (large quest pool)
2. Open quest board
3. Rapidly press F to cycle through pages
4. Verify smooth performance
5. Check visited page count increases

**Expected:**
- No lag when cycling
- Smooth page transitions
- Memory usage reasonable

## Regression Test - Old Slot Pinning

**Steps:**
1. Verify old behavior is gone:
   - Lock a quest
   - Press F
   - Verify ALL slots change (not just unlocked ones)

**Expected:**
- Locked quest moves to different page
- No slot pinning behavior
- All 4 slots cycle together

## UI/UX Validation

**Checklist:**
- [ ] Page indicator easy to read
- [ ] Locked icon shows clearly
- [ ] Active quests easy to identify
- [ ] Empty slots clear indication
- [ ] F key action label always visible
- [ ] Visited page count informative
- [ ] Wrap to page 1 feels natural

## Bug Hunt

**Check for:**
- [ ] Quests duplicated across pages
- [ ] Locked state lost on cycle
- [ ] Active quests disappearing
- [ ] Page number wrapping incorrectly
- [ ] Empty slots on page with available quests
- [ ] Memory leaks with many visited pages
- [ ] Save/load corruption
- [ ] Quest acceptance not bubbling to top
