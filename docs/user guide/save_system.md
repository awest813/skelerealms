# Save System

Skelerealms includes a save system that persists all entity and game state to `user://saves/`. It uses a hybrid snapshot-with-delta strategy so off-screen entities are never lost.

## Overview

Every save file is a **complete snapshot**. When saving, the new data is merged on top of the most recent save so that entities not currently loaded still retain their last-known state. Each file is a JSON document with the following top-level keys:

| Key | Description |
|---|---|
| `schema_version` | Integer. Used to detect when migrations are needed. |
| `game_info` | Global state: world time, continuity flags, quest state, dialogue state, etc. |
| `entity_data` | Per-entity state, keyed by ref-ID. |
| `other_data` | Anything else, e.g. spawn-tracker state and navigation connections. |
| `checksum` | FNV-1a 32-bit integrity hash written last. |

## Saving

```gdscript
# Autosave / datetime filename
SaveSystem.save()

# Named slot
SaveSystem.save("quicksave")
SaveSystem.save("slot_1")
```

The file is written to `user://saves/<slot_name>.dat` (or a datetime string if no name is given).

## Loading

```gdscript
# Load the most recently modified save file
SaveSystem.load_most_recent()

# Load by slot name
SaveSystem.load_slot("quicksave")

# Load by full path
SaveSystem.load_game("user://saves/slot_1.dat")
```

`load_slot` returns `false` if the file does not exist. `load_most_recent` does nothing if no saves exist yet.

## Listing Saves

```gdscript
var files: Array[String] = SaveSystem.list_saves()
# Returns filenames without the path prefix, e.g. ["slot_1.dat", "quicksave.dat"]
```

## Signals

| Signal | When |
|---|---|
| `save_complete` | Emitted after a save file is written. |
| `load_complete` | Emitted after all data has been loaded. |

Use these to freeze the UI, trigger screen fades, or clean up stale entities:

```gdscript
SaveSystem.save_complete.connect(func(): $LoadingScreen.hide())
SaveSystem.load_complete.connect(func(): SKEntityManager.instance.cleanup_stale())
```

## Making a Component Saveable

Implement `save()`, `load_data(data)`, and `reset_data()` on your component, then add it to the appropriate group in `_ready()`:

```gdscript
func _ready() -> void:
    add_to_group("savegame_entity")   # or "savegame_gameinfo" or "savegame_other"

func save() -> Dictionary:
    return { "my_value": my_value }

func load_data(data: Dictionary) -> void:
    my_value = data.get("my_value", default_value)

func reset_data() -> void:
    my_value = default_value
```

| Group | Used for |
|---|---|
| `savegame_entity` | Per-entity components (inventory, equipment, vitals, etc.). |
| `savegame_gameinfo` | Global singletons (GameInfo, QuestSystem, DialogueSystem). |
| `savegame_other` | Other persistent state (NavMaster, SpawnTrackerManager). |

## Schema Versioning and Migrations

The current schema version is stored in `SaveSystem.SAVE_SCHEMA_VERSION`. When the save format changes, increment this constant and register a migration:

```gdscript
func _ready() -> void:
    SaveSystem.register_migration(2, _migrate_v2_to_v3)

func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
    # Transform data from v2 format to v3
    var entity_data: Dictionary = data.get("entity_data", {})
    for id in entity_data:
        # ...
    return data
```

Migrations run in order. A save at version 1 will run both the v1→v2 and v2→v3 migrations before being used. The built-in v1→v2 migration handles the position/rotation format change from the original Skelerealms format.

## Corruption Detection

Every save file includes a FNV-1a 32-bit checksum. On load, the checksum is recomputed and compared. If they differ, a warning is pushed but loading continues. You can hook this by checking `push_warning` output or by overriding `_apply_migrations` in a subclass.

## Checking Whether an Entity Has Save Data

```gdscript
var option := SaveSystem.entity_in_save("my_entity_ref_id")
if option.some():
    var blob: Dictionary = option.unwrap()
```

Use sparingly — this reads and parses the entire most-recent save file.
