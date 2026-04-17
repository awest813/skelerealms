# Mods

Skelerealms has a manifest-driven mod system that lets you add covens, quests, and dialogues without modifying the base game files.

## Overview

A **mod** is a folder containing a `ModManifest` resource (`.tres` or `.res`). At game start, `ModLoader` scans the directory configured by `skelerealms/mods_path` (default `res://mods`) and automatically applies every manifest it finds.

## Creating a Mod Manifest

Create a `ModManifest` resource in your mod folder and fill in its properties:

| Property | Type | Description |
|---|---|---|
| `mod_id` | `StringName` | Unique identifier — must not be empty. Duplicate IDs are silently skipped. |
| `mod_name` | `String` | Human-readable name shown in debug output. |
| `covens` | `Array[Coven]` | New `Coven` resources to register with `CovenSystem`. |
| `coven_opinion_overrides` | `Array[CovenOpinionOverride]` | Opinion deltas applied between existing and/or new covens. |
| `quests` | `Array[QuestDefinition]` | New quest definitions registered with `QuestSystem`. |
| `dialogues` | `Array[DialogueDefinition]` | New dialogue trees registered with `DialogueSystem`. |

### Example Folder Layout

```
res://mods/
  my_mod/
    my_mod_manifest.tres       ← ModManifest resource
    quests/
      rescue_the_cat.tres      ← QuestDefinition
    dialogues/
      innkeeper_greeting.tres  ← DialogueDefinition
    covens/
      thieves_guild.tres       ← Coven resource
```

In `my_mod_manifest.tres`:
- `mod_id = &"my_mod"`
- `mod_name = "My Mod"`
- `quests = [preload("quests/rescue_the_cat.tres")]`
- `dialogues = [preload("dialogues/innkeeper_greeting.tres")]`
- `covens = [preload("covens/thieves_guild.tres")]`

## Opinion Overrides

`CovenOpinionOverride` lets your mod adjust how existing covens feel about each other (or about new covens your mod adds):

| Property | Type | Description |
|---|---|---|
| `coven_id` | `StringName` | The coven whose opinion is being changed. |
| `target_coven_id` | `StringName` | The coven being opined about. |
| `delta` | `int` | How much to add (positive) or subtract (negative) from the current opinion. |

## Changing the Mods Path

The default scan directory is `res://mods`. Change it via **Project Settings → Skelerealms → Mods Path** or by calling:

```gdscript
ProjectSettings.set_setting("skelerealms/mods_path", "res://my_mods_folder")
```

Subdirectories are scanned recursively, so you can organise mods in subfolders.

## Loading a Mod Programmatically

You can also load a mod at runtime without placing it in the mods directory:

```gdscript
var manifest: ModManifest = preload("res://dlc/expansion_one.tres")
ModLoader.load_mod(manifest)
```

`load_mod` is idempotent — calling it twice with the same `mod_id` has no effect.

## Signals

| Signal | Description |
|---|---|
| `mod_loaded(mod_id, mod_name)` | Emitted after a mod has been fully applied. |

```gdscript
ModLoader.mod_loaded.connect(func(id, name): print("Loaded mod: ", name))
```

## Checking Loaded Mods

```gdscript
var loaded: Array[StringName] = ModLoader.loaded_mods
if loaded.has(&"my_mod"):
    print("my_mod is active")
```
