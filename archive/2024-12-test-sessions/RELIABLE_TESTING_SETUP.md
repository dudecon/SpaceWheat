# Reliable Testing Setup for Touch Q Button

## Problem

You reported that touch Q "worked a little bit but then stopped working" - this suggests an **intermittent bug** where the fix works sometimes but not consistently.

## Test Script Created

I've created a real-time testing script that will help us see exactly what's happening:

**Location:** `/tmp/test_touch_q_realtime.sh`

## How to Run the Test

```bash
/tmp/test_touch_q_realtime.sh
```

## What the Test Does

1. **Runs the game** for 20 seconds
2. **Captures all logs** to `/tmp/touch_q_realtime.log`
3. **Analyzes the logs** to count:
   - How many times you touched Q button
   - How many times PlayerShell lambda was called
   - How many times ActionPreviewRow was updated
4. **Identifies the failure pattern:**
   - All updates work → ✅ Fixed
   - No updates work → ❌ Still broken
   - Some work, some don't → ⚠️ Intermittent bug

## What You Need to Do

During the 20-second test window, perform these actions **5-7 times**:

1. Touch a plot to select it (checkbox appears)
2. Touch Tool 1 button if not already selected
3. **Touch Q button** (should enter plant submenu)
4. Touch Q again (should plant wheat/flour/etc)
5. Repeat steps 3-4

The script will tell us:
- If it works every time (100% success)
- If it never works (0% success)
- **If it's intermittent** (works sometimes)

## Expected Output

### If Fixed (Success)
```
✅ SUCCESS: All touch Q presses triggered UI updates!
   Touch Q: 5
   Lambda: 5
   UI updates: 5
```

### If Still Broken
```
❌ FAILURE: PlayerShell lambda NEVER called
   Signal is not reaching the connection!
```

### If Intermittent (Most Likely)
```
⚠️  PARTIAL FAILURE:
   Touch Q pressed: 5 times
   Lambda called: 3 times
   UI updated: 3 times
```

This means 2 out of 5 failed - an **intermittent issue**.

## Why This is Better

1. **Real game environment** - No mocking, no synthetic test scene
2. **Captures actual user interaction** - You perform the actions naturally
3. **Statistical analysis** - Shows success rate, not just pass/fail
4. **Identifies failure patterns** - Shows which attempts failed and why

## Next Steps After Test

**If 100% success:** Great! The fix works - we just need to understand what "stopped working" meant in your original report

**If 0% success:** The fix didn't work - we need a different approach

**If intermittent (20-80% success):** This is the most likely scenario. It means:
- The deferred call sometimes works
- There's a timing issue or race condition
- We need to add additional safeguards

## Alternative: Manual Analysis

If you'd prefer to just run the game and save logs manually:

```bash
godot --path /home/tehcr33d/ws/SpaceWheat > /tmp/manual_test.log 2>&1
```

Then save to:
```
llm_inbox/player_logs/player_logs_touch_q_analysis.txt
```

And I can analyze the same patterns manually.

## What I'm Looking For

In the logs, I need to see this pattern for **EVERY** touch Q:

```
🖱️  Action button clicked: Q (current_submenu='')
   Execution deferred to escape button signal chain
(next frame)
📞 FarmInputHandler.execute_action('Q') called
📡 Emitting submenu_changed signal...
📂 Submenu entered: [name]              ← This MUST appear
📋 ActionBarManager.update_for_submenu  ← This MUST appear
🔄 ActionPreviewRow.update_for_submenu  ← This MUST appear
```

If any step is missing, I can see where the chain breaks.

---

**Ready to test!** Just run `/tmp/test_touch_q_realtime.sh` and perform the touch Q actions during the 20-second window.
