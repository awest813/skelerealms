# Baseline repairs and flight sandbox

Implemented against Godot 4.4.1 and GUT 9.4.0. The earlier readiness audit records the original findings; this document describes the resulting changes.

## Run the flight sandbox

Open `flight_sandbox/project.godot` and run it. This is a standalone, dependency-free handling prototype with six-axis flight, linear assistance/drift, braking, pause, reset, a speed HUD, physical course obstacles, and a bounded local zone. See `flight_sandbox/README.md` for controls.

It does not yet connect the ship to Skelerealms entities, missions, trading, combat, or saves. The framework repairs below make that next integration easier to test.

## Prepare the RPG example and tests

The tracked example addon entry is a repository symlink that some Windows checkouts materialize as text. The preparation script builds a disposable host under `.local/example` using selected files, without following that link or copying the repository recursively.

```powershell
./tools/prepare_example.ps1
godot --headless --path .local/example --editor --import
godot --path .local/example
```

For tests, obtain GUT 9.4.0 and pass its `addons/gut` directory:

```powershell
./tools/prepare_example.ps1 -GutPath '<GUT checkout>/addons/gut'
godot --headless --path .local/example --editor --import
godot --headless --path .local/example -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
godot --headless --path .local/example res://smoke_test.tscn
godot --headless --path flight_sandbox -s res://test_flight.gd
```

Re-run preparation after changing framework sources. Edit the tracked source, not `.local/example`. The copy is disposable but the script does not delete files, so remove stale generated files deliberately if renaming source assets. The preparation script adjusts test preload paths and renames GUT's private CLI `Option` symbol inside the generated copy to avoid colliding with Skelerealms' public `Option` class. Original GUT files are untouched.

For this workspace, downloaded executables and dependencies live under `.local/godot` and `.local/gut`; they are not committed. On this restricted Windows runner, validation sets `APPDATA` to `.local/appdata` so engine user data remains writable. Normal desktop use does not require this override.

## Framework changes

- World loading rejects overlapping requests, keeps the old scene alive during preparation, pauses simulation while loading, commits one destination, frees the replaced scene, and restores prior pause state. Failure retains the original world. Progress is a float from 0 to 1.
- Player travel applies arrival only after success. Puppet hookups can reconnect after respawn, orientation is restored, and the player becomes the distance-query center without culling itself.
- Hitscan explicitly detects Area3D hurtboxes while retaining obstacle blocking and caller-supplied exclusions.
- Save loading reports read/parse failure correctly. Complete component snapshots survive consecutive saves; unloaded entities are retained from the current session snapshot instead of a different newest slot. JSON dictionary conversion is explicit and checksum generation matches the loaded representation. Saves are blocked during world transitions. The example prepares the destination before restoring its in-memory snapshot and player pose; failed preparation leaves current game data unchanged.
- Corrected advertised-4.4 compatibility failures: nested typed collections, an NPC setter's indentation, invalid engine API calls, coroutine joining, type inference, resource serialization, and singleton/global-class naming conflicts.
- Corrected test doubles to inherit the types they exercise. Tests now follow the existing synchronous sequence/selector semantics. Partial quest progress emits an affected-quest result as documented.

## API notes

Autoload names remain `SKUIManager` and `SpawnTrackerManager`. Their instantiable script class names are now **`SKUIService`** and **`SKSpawnTrackerManager`**, respectively, to avoid Godot's name collision. Update explicit class types, inheritance, and `.new()` calls in consuming projects.

`SKBlackboard.value_changed(key)` replaces the invalid custom `changed(key)` declaration. The inherited Resource `changed()` signal still exists and is emitted for set/erase operations.

`WorldLoader.load_world()` now returns whether a request started; use `world_loading_ready` for successful completion and `world_loading_failed` for rejection/failure. Failure no longer emits success signals. `load_scene_progess_updated` keeps its existing spelling but now carries a float. `IdlePoint.occupy()` returns a boolean compatible with `Furniture.occupy()`.

`SaveSystem.load_game()`/`load_slot()` report data restoration success, not completion of an asynchronous world transition. `restore_snapshot()` accepts already prepared data. The consuming game's coordinator must handle scene preparation; the example's `request_load_slot()` does this and returns whether the request began. The example's text configuration is now correctly named `sk_config.tres`.

## Validation and remaining limits

See [the follow-up audit and polish report](flight_polish_audit.md) for the latest changes and results. The figures below describe the initial baseline repair pass.

Observed results on 2026-09-24:

- Final framework import: no GDScript parse/compile errors.
- GUT: **293 tests passed, 749 assertions**, no script runtime errors. Deliberate invalid-input tests produce their expected diagnostics.
- Standalone flight physics: **16 checks passed**, process exit 0.
- Actual example travel/save/reload smoke: **0 failures**, process exit 0.
- Rendered the sandbox and inspected `flight_sandbox/preview.png` for course visibility, ship framing, and readable controls/HUD.

The framework editor import and final GUT process reported resource leaks and stalled during shutdown in this environment; those validation processes were stopped after a timeout. Passing test assertions are therefore **not** a clean framework shutdown result. The standalone sandbox exits normally. Framework teardown cleanup remains an open baseline issue.

The baseline suite includes regression checks for repeated scene replacement, request overlap, rollback, prior pause state, hitscan and obstacle filtering, repeated saves, checksums, and puppet orientation. The example smoke scene exercises real door travel A → B, save, B → A, then loading B and its wallet from disk.

The original example scenes do not contain baked navigation data; successful startup is not a claim that NPC navigation is production-ready. Existing test-suite teardown still reports retained resources/orphan objects, separate from the regression that proves replaced world scenes are freed. The restricted Windows environment also reports a certificate-store access error; neither sandbox nor tests require network access at runtime.

Next work: playtest flight feel, add a persistent ship state/entity adapter, then one weapon, shield/hull damage, and one pursuing drone. No combat, economy, jump map, or planetary system is included in this handling milestone.
