# Migration Tooling

> Status: introduced in Phase 9 — Architecture Hardening.

Skelerealms has **two** migration surfaces. A plugin upgrade can affect
either, and it is the framework's responsibility to make both upgrades
happen without the consumer writing bespoke one-off code.

| Surface | Purpose | Lives in |
|---|---|---|
| Save-file migrations | Upgrade a player's save across schema changes. | `SaveSystem._migrations`, callbacks registered via `SaveSystem.register_migration(from_version, fn)` |
| Plugin migrations | Upgrade the consumer's **project** (settings keys, renamed resources, deprecated defaults) when the plugin itself is bumped in place. | `PluginMigrationRegistry` in `scripts/system/plugin_migration_registry.gd`, invoked once on editor start from the plugin's `_enter_tree`. |

Neither surface handles the other. Save-file migrations do not rewrite
`ProjectSettings`; plugin migrations do not touch the user's save files.

---

## Save-file migrations

Already documented in [`docs/user guide/save_system.md`](../user%20guide/save_system.md).
A short recap:

- Every save has a `schema_version` integer field.
- `SAVE_SCHEMA_VERSION` is the latest version Skelerealms writes.
- On load, `SaveSystem._apply_migrations(data)` walks from the save's stored
  version up to `SAVE_SCHEMA_VERSION`, applying each registered migration
  in order.

Register a migration:

```gdscript
# Usually in a project's own autoload, not in the framework itself.
func _ready() -> void:
    SaveSystem.register_migration(2, func(data: Dictionary) -> Dictionary:
        # Rename an old key, add a default, drop a field, etc.
        return data)
```

---

## Plugin migrations

`PluginMigrationRegistry` runs at editor-session start (from the plugin's
`_enter_tree`) and upgrades *project* state. The installed plugin version
is stored under the hidden project-setting `skelerealms/__installed_version`,
and each migration advances the installed version by exactly one step.

### When to write one

Write a plugin migration when a new plugin release:

- Renames or deletes a `ProjectSettings` key under `skelerealms/*`.
- Changes a default value that the previous release wrote into
  `project.godot`.
- Adds a new required folder or default path.
- Breaks a resource schema for a resource the consumer stores on disk.

Do **not** write a plugin migration for runtime state — that is what save
migrations are for.

### How to write one

In `skelerealms.gd`'s `_run_plugin_migrations()`:

```gdscript
registry.register("beta 0.8", func() -> void:
    # Example: we renamed skelerealms/foo_path to skelerealms/bar_path in 0.9.
    var old = ProjectSettings.get_setting("skelerealms/foo_path")
    if old != null:
        ProjectSettings.set_setting("skelerealms/bar_path", old)
        ProjectSettings.set_setting("skelerealms/foo_path", null)
        ProjectSettings.save()
)
```

A few rules to follow:

1. **Idempotent by construction.** A migration can be re-run if the editor
   crashes mid-upgrade. Guard every write behind a "still needs doing" check.
2. **No scene-tree access.** The plugin `_enter_tree` fires before
   autoloads are wired. Touch `ProjectSettings`, `ResourceLoader`, and
   `DirAccess` only.
3. **No user-save access.** Use save migrations for that.
4. **Call `ProjectSettings.save()`** if you change a setting, otherwise the
   change won't persist to `project.godot`.
5. Keep one chain link per version bump. Don't write one monolithic
   "upgrade everything" function — that reproduces the DFS-vs-BFS quest
   planning bug (see `CAMELOT_ROADMAP.md` Phase 2A) in documentation form.

### How it runs

1. Plugin `_enter_tree` is invoked by the editor.
2. `_run_plugin_migrations()` constructs a registry whose target version is
   `PLUGIN_VERSION`.
3. Every registered migration is added in order by FROM-version.
4. `registry.run()`:
   - Reads `skelerealms/__installed_version`.
   - If empty: fresh install — stamp the current version, skip everything.
   - If equal to the target: no-op.
   - Otherwise: walk the chain, firing every callback whose FROM-version
     matches the advancing cursor, until the cursor reaches the target.
5. Persists the new `skelerealms/__installed_version` back to
   `project.godot`.

### Fresh install vs. upgrade

A fresh install (empty setting) is treated as "already at the current
version" so migrations aren't applied to a freshly-enabled plugin. The
first time a consumer bumps the plugin, we write whatever the current
version is, and real chain-walking only happens on subsequent upgrades.

That behaviour is tested in `tests/test_plugin_migration_registry.gd`.

---

## Version strings

Skelerealms currently uses the human-readable `beta 0.X` format. Migration
keys match those strings literally — there is no semver comparator yet. At
1.0 the format becomes semver (`1.0.0`, `1.0.1`, …) and the registry can
switch to range-based comparison without changing its public surface.

Until then, register migrations with the exact `beta 0.X` string the
consumer upgraded from.

---

## Reference

- `scripts/system/plugin_migration_registry.gd` — the registry class.
- `skelerealms.gd:_run_plugin_migrations()` — the entry point.
- `tests/test_plugin_migration_registry.gd` — unit tests for the run loop.
- `docs/user guide/save_system.md` — save-file migration docs.
- `docs/user guide/migrating.md` — end-user release notes per version.

---

## Migration history

### beta 0.7 → beta 0.8

No project-level schema changes. Phase 8 (debug overlays) and Phase 9 (architecture docs, crash-safe saves, `@rpc` annotations) did not change ProjectSettings keys or resource schemas.

### beta 0.8 → beta 0.9

Godot 4.4 modernization. No project-level schema changes — typed dictionaries and `store_*` return-value handling are code-only changes with no effect on ProjectSettings keys or resource schemas. The migration stub is registered in `skelerealms.gd:_run_plugin_migrations()` as a no-op for chain continuity.
