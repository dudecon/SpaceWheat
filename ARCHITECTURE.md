# SpaceWheat Architecture Guide

## GDScript Compilation-Safe Patterns

This document outlines architectural patterns that prevent compilation errors in GDScript, particularly around autoloads and class initialization.

### Background: The Compilation Order Problem

GDScript compiles files before the scene tree exists. This creates constraints:

1. **Autoloads compile in order** - defined in `project.godot` `[autoload]` section
2. **Type hints must reference already-compiled classes** - forward references fail
3. **Static methods execute during class initialization** - can't self-reference
4. **class_name creates global types** - but only after compilation completes

**Key Insight:** Compilation time ≠ Runtime. Many patterns that work at runtime fail at compile time.

---

## Pattern 1: Autoload Function Signatures

### ❌ WRONG - Type Hints for Non-Autoload Classes

```gdscript
# BootManager.gd (autoload)
extends Node

func boot(farm: Farm, shell: PlayerShell) -> void:
    # FAILS: Farm and PlayerShell aren't loaded when BootManager compiles!
    pass
```

**Error:**
```
SCRIPT ERROR: Parse Error: Could not find type "Farm" in the current scope.
```

### ✅ CORRECT - Generic Node Type with Runtime Checks

```gdscript
# BootManager.gd (autoload)
extends Node

func boot(farm: Node, shell: Node) -> void:
    # Runtime validation instead of compile-time type hints
    assert(farm.has_method("get_grid"), "farm must have get_grid() method")
    assert(shell.has_method("mount_ui"), "shell must have mount_ui() method")

    # Can use type casting for IDE hints (no compile-time check)
    var typed_farm = farm as Farm  # Works at runtime
    pass
```

**Why This Works:**
- `Node` is always available (built-in Godot type)
- Runtime checks provide same safety without compilation dependency
- Type casting (`as`) happens at runtime after classes are loaded

---

## Pattern 2: Static Factory Methods

### ❌ WRONG - Direct Class Reference During Definition

```gdscript
class_name Complex
extends RefCounted

# Static method defined inside the class it references
static func zero():
    return Complex.new(0.0, 0.0)  # FAILS: Complex not fully initialized!
```

**Error:**
```
SCRIPT ERROR: Compile Error: Identifier not found: Complex
```

**Why It Fails:**
When GDScript loads `Complex.gd`, it:
1. Starts initializing the `Complex` class
2. Encounters `static func zero()`
3. Tries to resolve `Complex.new()` - but `Complex` isn't finished initializing yet!
4. Circular dependency → compilation error

### ✅ CORRECT - Lazy Singleton Pattern

```gdscript
class_name Complex
extends RefCounted

# Cache instances to avoid repeated loads
static var _zero_instance = null

static func zero():
    if _zero_instance == null:
        # Explicit script load defers resolution until runtime
        var script = load("res://Core/QuantumSubstrate/Complex.gd")
        _zero_instance = script.new(0.0, 0.0)
    return _zero_instance
```

**Why This Works:**
- `load()` happens at runtime, after class is fully initialized
- Caching improves performance (singleton pattern)
- First call pays load cost, subsequent calls are instant

**When to Use:**
- Static factory methods (like `zero()`, `one()`, constructors)
- Utility functions that create instances
- Registry/lookup patterns

---

## Pattern 3: Autoload Self-Reference

### ❌ WRONG - Reference Autoload Name in Static Method

```gdscript
# VerboseConfig.gd (autoload)
extends Node

static func safe_is_verbose(subsystem: String = "") -> bool:
    # FAILS: VerboseConfig autoload doesn't exist at compile time!
    if not is_instance_valid(VerboseConfig):
        return false
    return VerboseConfig.is_verbose(subsystem)
```

**Error:**
```
SCRIPT ERROR: Compile Error: Identifier not found: VerboseConfig
```

### ✅ CORRECT - Use Node Path Lookup

```gdscript
# VerboseConfig.gd (autoload)
extends Node

static func safe_is_verbose(subsystem: String = "") -> bool:
    # Runtime lookup via scene tree
    var config = Engine.get_main_loop().root.get_node_or_null("/root/VerboseConfig") if Engine.get_main_loop() else null

    if not is_instance_valid(config):
        return false

    if not config.is_node_ready():
        return false

    return config.is_verbose(subsystem)
```

**Why This Works:**
- `Engine.get_main_loop()` accesses runtime scene tree
- `get_node_or_null()` safely returns null if node doesn't exist
- No compile-time dependency on VerboseConfig class name

---

## Pattern 4: Type Hints in Faction/Icon Systems

### ❌ WRONG - Typed Arrays Cause Resolution Issues

```gdscript
# AllFactions.gd
class_name AllFactions

static func get_all() -> Array[Faction]:
    # FAILS: Faction might not be compiled yet when AllFactions compiles
    var factions: Array[Faction] = []
    return factions
```

**Error:**
```
SCRIPT ERROR: Parse Error: Could not find type "Faction" in the current scope.
```

### ✅ CORRECT - Untyped Array with Runtime Checks

```gdscript
# AllFactions.gd
class_name AllFactions

static func get_all() -> Array:
    var factions: Array = []  # Untyped array

    # Can add type hints in comments for IDE/documentation
    # Returns: Array of Faction objects

    for f in CoreFactions.get_all():
        factions.append(f)  # Runtime knows f is a Faction

    return factions
```

**Alternative - Explicit Preload:**
```gdscript
# If you absolutely need type safety
const FactionScript = preload("res://Core/Factions/Faction.gd")

static func get_all() -> Array:
    var factions: Array = []

    var f = FactionScript.new()  # Explicitly typed via preload
    factions.append(f)

    return factions
```

**Why This Works:**
- Untyped arrays compile without resolving element types
- `preload()` creates explicit dependency, loaded at compile time
- Runtime behavior identical to typed version

---

## Pattern 5: Instance Methods with get_script()

### ✅ RECOMMENDED - Deferred Class Resolution

```gdscript
class_name Complex
extends RefCounted

# Instance methods can use get_script().new()
func conjugate():
    # get_script() returns the script this instance was created from
    return get_script().new(re, -im)

func add(other: Complex):
    return get_script().new(re + other.re, im + other.im)
```

**Why This Works:**
- `get_script()` is a runtime call on an existing instance
- By the time an instance exists, the class is fully initialized
- Avoids circular dependency because resolution is deferred

**When to Use:**
- Instance methods that return new instances of same type
- Operations that create copies (add, subtract, multiply, etc.)

---

## Pattern 6: Class Name Conflicts

### ❌ WRONG - Duplicate class_name Declarations

```gdscript
# Core/Factions/Faction.gd (new system)
class_name Faction
extends RefCounted

# Core/GameMechanics/Faction.gd (old system)
class_name Faction  # FAILS: Duplicate class_name!
extends Resource
```

**Error:**
```
SCRIPT ERROR: Parse Error: Class 'Faction' hides a global script class.
```

### ✅ CORRECT - One class_name Per Type

```gdscript
# Core/Factions/Faction.gd (active system)
class_name Faction
extends RefCounted

# Core/GameMechanics/Faction.gd (deprecated, remove class_name)
extends Resource
# No class_name - just a regular script

# Or rename if still needed
class_name OldFaction
extends Resource
```

**Why This Matters:**
- `class_name` registers globally in Godot's script cache
- Only ONE class can claim a given name
- Deprecated classes should remove `class_name` or rename

---

## Autoload Initialization Order

From `project.godot`:
```ini
[autoload]
VerboseConfig="*res://Core/Config/VerboseConfig.gd"      # First
BootManager="*res://Core/Boot/BootManager.gd"            # Second
IconRegistry="*res://Core/QuantumSubstrate/IconRegistry.gd"  # Third
GameStateManager="*res://Core/GameState/GameStateManager.gd" # Fourth
TouchInputManager="*res://UI/Input/TouchInputManager.gd"     # Fifth
```

**Rules:**
1. Each autoload can reference ONLY autoloads loaded BEFORE it
2. VerboseConfig can't reference any other autoloads (it's first)
3. BootManager can reference VerboseConfig
4. IconRegistry can reference VerboseConfig + BootManager
5. etc.

**Tip:** Order autoloads by dependency. Most fundamental = first.

---

## Debugging Compilation Errors

### Step 1: Check Autoload Order
```bash
grep "\[autoload\]" -A 10 project.godot
```

If `FileA` references `FileB`, ensure `FileB` comes first in autoload list.

### Step 2: Find Type Hint Violations
```bash
# Search for type hints in autoload files
grep "func.*:.*->" Core/Boot/*.gd Core/Config/*.gd
```

Look for type hints referencing non-built-in types.

### Step 3: Find Static Self-References
```bash
# Find static functions that might self-reference
grep -A 5 "^static func" Core/**/*.gd | grep "ClassName.new()"
```

### Step 4: Test Isolated Compilation
```gdscript
# test_compile.gd
extends SceneTree
func _init():
    var MyClass = load("res://path/to/MyClass.gd")
    if MyClass:
        print("✓ MyClass compiles")
    else:
        print("✗ MyClass failed")
    quit()
```

```bash
godot --headless --script test_compile.gd
```

---

## Quick Reference Checklist

When adding new code, ask:

- [ ] **Autoload?** → No type hints for classes that come later
- [ ] **Static method?** → Can't reference own class with `.new()`
- [ ] **Factory method?** → Use lazy singleton pattern
- [ ] **Type hint?** → Built-in types only (Node, int, String, etc.)
- [ ] **class_name?** → Must be unique globally
- [ ] **Array type?** → Use `Array`, not `Array[CustomType]`

---

## Real-World Examples from SpaceWheat

### Example 1: BootManager
```gdscript
# Before (broken)
func boot(farm: Farm, shell: PlayerShell) -> void:

# After (works)
func boot(farm: Node, shell: Node) -> void:
    assert(farm.has_method("get_grid"))
```

### Example 2: Complex.zero()
```gdscript
# Before (broken)
static func zero():
    return Complex.new(0.0, 0.0)

# After (works)
static var _zero_instance = null
static func zero():
    if _zero_instance == null:
        var script = load("res://Core/QuantumSubstrate/Complex.gd")
        _zero_instance = script.new(0.0, 0.0)
    return _zero_instance
```

### Example 3: AllFactions
```gdscript
# Before (broken)
static func get_all() -> Array[Faction]:

# After (works)
static func get_all() -> Array:
    # Returns Array of Faction objects
```

---

## When to Break These Rules

**Never.** These aren't style preferences - they're hard constraints of GDScript's compilation model.

If a pattern seems to violate these rules but works, it's probably:
1. Using a built-in type (Node, Resource, RefCounted)
2. Using preload() which resolves at compile time
3. Working by accident (will break if files are reordered)

---

## Further Reading

- [GDScript Class Reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)
- [Godot Autoloads](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)
- [GitHub Issue #52035](https://github.com/godotengine/godot/issues/52035) - Static method self-reference

---

## Changelog

- **2026-01-08**: Initial version documenting patterns from SpaceWheat boot fix
- Created during resolution of commit 2082850 compilation failures
