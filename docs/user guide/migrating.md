# Migrating from 0.5 to 0.6

This will not be easy. Sorry in advance.

## Instance data

This will be spotty at best, but a button will appear above `InstanceData`-derived classes that, when pressed, will create a roughly-equivalent Entity, and save it under the same directory. AI-related things and Loot boxes will not be conserved.

## GOAP

Luckily, this is easy. Simply change your existing GOAPBehaviors to GOAPActions. Instead of being a property, however, prerequisites and effects have moved into functions to override.

## Loot tables, schedules

You will have to remake these from scratch. Sorry.

---

# Migrating from beta 0.8 to beta 0.9 (Godot 4.4)

## Godot version requirement

**Skelerealms beta 0.9 requires Godot 4.4 or later.** Update your engine before updating the plugin.

## What changed

### Typed Dictionaries

Core framework dictionaries now use `Dictionary[KeyType, ValueType]` syntax (a Godot 4.4 feature). This improves type safety, editor Inspector display, and autocompletion.

If you subclass or extend any of the following, update your overrides to match the new typed signatures:

- `SKConfig.skills` → `Dictionary[StringName, int]`
- `SKConfig.attributes` → `Dictionary[StringName, int]`
- `CombatantComponent.resistances` → `Dictionary[StringName, float]`
- `CombatAction.base_damage` → `Dictionary[StringName, float]`
- `PlayerComponent.damage_modifiers` → `Dictionary[StringName, float]`

If you have `@export var` declarations that pass dictionaries to these fields, the editor will now enforce the correct key/value types.

### FileAccess `store_*` return values

In Godot 4.4, `FileAccess.store_string()`, `store_line()`, and related methods return `Error` instead of `void`. The save system now checks `flush()` for errors. If you have custom save code that calls `store_*` methods, update it to check the return value.

### `@export_file` paths

Godot 4.4 changed `@export_file` to store `uid://` paths instead of `res://` paths. If you have resources or scenes with `@export_file` fields:

1. Re-save them in the Godot 4.4 editor — the paths will be updated automatically.
2. No code changes are needed; Godot resolves `uid://` paths transparently at runtime.

Skelerealms itself does not use `@export_file` in its scripts, so no framework resources are affected.

### 3D Physics Interpolation

Godot 4.4 adds opt-in 3D physics interpolation. You can enable it in Project Settings → Physics → 3D → `physics_interpolation`. This can improve NPC puppet movement smoothness when their positions are updated in `_physics_process`. This is not enabled by default.

### Jolt Physics

Godot 4.4 bundles the Jolt physics engine as an alternative backend. Skelerealms is compatible with both Godot Physics and Jolt — all raycasting and collision detection uses the standard API.

## Plugin migration

The `beta 0.8 → beta 0.9` plugin migration is a no-op. There are no ProjectSettings key changes or resource schema changes. The migration stub is registered for chain continuity.

## Action required

1. Update Godot to **4.4+**.
2. Replace the `addons/skelerealms` folder with the `beta 0.9` release.
3. Re-open your project in the Godot 4.4 editor.
4. If you have subclassed framework components with `@export` dictionaries, update them to use typed dictionary syntax.
5. Re-save any resources that use `@export_file` annotations.
