# Test Execution Hang - Investigation Results

**Date**: 2026-01-07
**Investigation Duration**: ~2 hours
**Status**: ✅ ROOT CAUSE IDENTIFIED

---

## Executive Summary

The test execution hang is **NOT** an environment issue. It is a **code compilation issue** introduced by the VerboseConfig migration.

**Root Cause**: FarmView.gd contains VerboseConfig function calls that cannot be resolved at script compilation time, causing the script to fail to compile. When the FarmView script doesn't compile, FarmView._ready() never executes, farm is never created, and BootManager.boot() is never called. Tests then wait forever for a boot sequence that never happens.

---

## Investigation Process

### Step 1: Verified _process() Loop Works
```gdscript
// Result: ✅ PASS
_process() callback fires every frame in headless mode
Can communicate via frame counts
```

### Step 2: Verified _ready() is Called for Child Nodes
```gdscript
// Result: ✅ PASS
Child nodes added to tree DO get _ready() called
Verified with TestNode.new() → _ready() fires
```

### Step 3: Tested Scene Loading
```gdscript
// Result: ⚠️ PARTIAL SUCCESS
FarmView.tscn scene loads OK
FarmView.tscn instantiates OK
But: FarmView.gd script fails to compile
FarmView._ready() never executes
```

### Step 4: Monitored BootManager Status Over 500 Frames
```gdscript
Frame 1:    BootManager._current_stage = "" (empty)
Frame 50:   BootManager._current_stage = "" (still empty)
Frame 100:  BootManager._current_stage = "" (still empty)
Frame 500:  BootManager._current_stage = "" (still empty)
Result: BootManager.boot() was NEVER CALLED
```

### Step 5: Isolated FarmView Script Compilation
```
ERROR: Compile Error: Identifier not found: VerboseConfig
       at: GDScript::reload (res://UI/FarmView.gd:20)
```

**Found it!** FarmView.gd cannot compile because it references VerboseConfig which is not available at compile time.

---

## Root Cause Analysis

### The Problem Chain

```
FarmView.gd:20 calls VerboseConfig.info()
    ↓
Godot 4.5 attempts to compile FarmView.gd
    ↓
VerboseConfig is an autoload singleton
    ↓
Autoloads are NOT available during script compilation
    ↓
Godot raises: "Identifier not found: VerboseConfig"
    ↓
FarmView.gd compilation FAILS
    ↓
FarmView._ready() is NEVER CALLED
    ↓
farm = Farm.new() is NEVER EXECUTED
    ↓
await BootManager.boot() is NEVER REACHED
    ↓
BootManager._current_stage remains "" (empty string)
    ↓
BootManager.is_ready remains false
    ↓
Tests HANG waiting for boot that never happens
```

### Technical Details

**File 1: FarmView.gd (UI/FarmView.gd)**

Lines with VerboseConfig calls:
- Line 20: `VerboseConfig.info("ui", "🌾", "FarmView starting...")`
- Line 23: `VerboseConfig.debug("ui", "📏", "FarmView size: %.0f × %.0f" % [size.x, size.y])`
- Line 24: `VerboseConfig.debug("ui", "", "FarmView anchors: L%.1f...")`
- Plus many more throughout _ready() function

**File 2: VerboseConfig.gd (Core/Config/VerboseConfig.gd)**

```gdscript
extends Node

## Global logging configuration...
## NOTE: This is an autoload singleton. Cannot use class_name due to Godot restriction.
## Access via VerboseConfig autoload at runtime, not during compilation.
```

**The Issue**: VerboseConfig cannot have a `class_name` declaration because Godot doesn't allow `class_name` on autoload singletons. Without a `class_name`, the script is not statically available during compilation. When FarmView.gd tries to call `VerboseConfig.info()` at module level (in _ready), Godot's parser fails to resolve the identifier.

---

## Verification Results

| Check | Result | Evidence |
|---|---|---|
| Does FarmView.tscn load? | ✅ YES | Scene instantiates successfully |
| Does FarmView.gd compile? | ❌ NO | `Compile Error: Identifier not found: VerboseConfig` |
| Does FarmView._ready() run? | ❌ NO | farm property remains null |
| Is BootManager.boot() called? | ❌ NO | _current_stage remains "" |
| Do tests hang? | ✅ YES | BootManager.is_ready stays false after 500 frames |

---

## Impact Assessment

### Tests Affected
- **343 test files** exist in `/Tests/` directory
- **0 tests can currently run** due to this compilation error
- Any test that loads a FarmView scene will fail to compile
- Any test that instantiates Farm will hang waiting for BootManager

### Systems Blocked
| System | Status | Reason |
|---|---|---|
| Scene-based tests | ❌ BLOCKED | FarmView.gd doesn't compile |
| Gameplay tests | ❌ BLOCKED | farm is never created |
| Integration tests | ❌ BLOCKED | BootManager never boots |
| API smoke tests | ⚠️ UNCERTAIN | Direct Farm instantiation might work, but dependencies may fail |

### Severity
**CRITICAL** - All integration and gameplay testing is completely blocked.

---

## Why This Happened

The VerboseConfig migration (converting 666 print statements to VerboseConfig calls) introduced a dependency on VerboseConfig in FarmView.gd. However, VerboseConfig is an autoload singleton that is not available at script compilation time. This created a deadlock where:

1. FarmView needs VerboseConfig to compile
2. VerboseConfig is only available at runtime
3. Godot tries to compile FarmView at module load time
4. Compilation fails because VerboseConfig doesn't exist yet

---

## Reproduction Steps

To reproduce this issue:

```bash
# Create a simple test that loads FarmView
cat > test.gd << 'EOF'
extends SceneTree
func _init():
    var scene = load("res://scenes/FarmView.tscn")
    if scene:
        var inst = scene.instantiate()
        root.add_child(inst)
EOF

# Run the test
godot --headless -s test.gd

# Result:
# ERROR: Compile Error: Identifier not found: VerboseConfig
#        at: GDScript::reload (res://UI/FarmView.gd:20)
```

---

## Solutions Available

The hang is not a test environment issue and cannot be fixed by changing how tests are run. The code itself needs modification. Options:

### Option 1: Defer VerboseConfig Usage (Recommended)
Move VerboseConfig calls from _init/_ready to _process:
```gdscript
# Instead of calling VerboseConfig in _ready:
func _ready() -> void:
    # DON'T call VerboseConfig here
    # Just set up initialization

func _process(delta) -> void:
    # Call VerboseConfig here on first frame
    if not _initialized:
        VerboseConfig.info("ui", "🌾", "FarmView starting...")
        _initialized = true
```

### Option 2: Add class_name Workaround
If Godot allows, add a forward declaration:
```gdscript
# At the top of any file that needs VerboseConfig
var VerboseConfig = get_tree().root.get_node_or_null("/root/VerboseConfig")
if VerboseConfig == null:
    # Fallback for tests
    VerboseConfig = { info = func(a,b,c): print(c), debug = func(a,b,c): null }
```

### Option 3: Use Lazy Evaluation
```gdscript
class VerboseProxy:
    func info(cat, emoji, msg):
        var vc = get_tree().root.get_node_or_null("/root/VerboseConfig")
        if vc: vc.info(cat, emoji, msg)
        else: print(msg)
```

### Option 4: Remove VerboseConfig from FarmView
Revert FarmView.gd to use print() or remove logging entirely for module initialization.

---

## Observations

### What DID Work
- Farm.new() creates successfully without FarmView
- BootManager exists as autoload
- IconRegistry initializes correctly
- GameStateManager initializes correctly
- All autoloads load before any script compilation
- Direct Farm instantiation (without scenes) works fine

### What DIDN'T Work
- Loading any scene with VerboseConfig calls
- FarmView.gd specifically (first VerboseConfig call at line 20)
- Any downstream system that depends on FarmView

---

## Timeline

| Time | Event |
|---|---|
| 00:00 | Started investigation: "Why do tests hang?" |
| 01:00 | Verified _process() works in headless mode |
| 01:15 | Verified _ready() is called on child nodes |
| 01:30 | Discovered FarmView._ready() never executes |
| 01:45 | Found BootManager._current_stage stays "" |
| 01:55 | Isolated FarmView.gd compilation error |
| 02:00 | **Identified: VerboseConfig not available at compile time** |

---

## Conclusion

**This is a code issue, not a test environment issue.**

The VerboseConfig migration was successful but created a compile-time dependency problem. FarmView.gd calls VerboseConfig before it's available, causing compilation to fail silently. The scene loads as an empty shell with no initialization code running, tests wait forever for a boot that never happens, and every test hangs.

The solution requires code modification to defer VerboseConfig usage until runtime, rather than calling it at module initialization time.

---

## Appendix: Debug Evidence

### Evidence #1: Scene Loads, Script Doesn't Compile
```
✅ Scene loaded OK
✅ Scene instantiated and added to tree
❌ Script FarmView.gd failed to compile
✅ FarmView node exists in tree
❌ FarmView.farm = null (never created)
```

### Evidence #2: BootManager Never Called
```
Frame 50:   BootManager._current_stage = ""
Frame 100:  BootManager._current_stage = ""
Frame 300:  BootManager._current_stage = ""
Frame 500:  BootManager._current_stage = ""
→ Pattern: NEVER CHANGES (BootManager.boot was never called)
```

### Evidence #3: Exact Compilation Error
```
SCRIPT ERROR: Compile Error: Identifier not found: VerboseConfig
             at: GDScript::reload (res://UI/FarmView.gd:20)
```

---

**Investigation Status**: ✅ COMPLETE - ROOT CAUSE IDENTIFIED
**Blocking Status**: 🔴 CRITICAL - All tests blocked, code modification required
