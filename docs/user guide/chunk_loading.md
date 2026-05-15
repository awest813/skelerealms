# Chunk Loading

Skelerealms includes a generic, engine-agnostic chunk loading system under
`scripts/chunks/`.  It manages a grid of independently loadable world tiles
(chunks) around one or more origins (e.g. the player), with async loading,
LRU eviction, and cancellation support.

---

## Class overview

| Class | File | Role |
|---|---|---|
| `SKChunkManager` | `sk_chunk_manager.gd` | Central manager. Tracks active and preloaded chunks, drives load/unload lifecycle. |
| `SKChunk` | `sk_chunk.gd` | Data class representing a single chunk (coordinates, state, loaded data). |
| `SKChunkSource` | `sk_chunk_source.gd` | **Abstract.** Override to load chunk data for a given coordinate. |
| `SKChunkAdapter` | `sk_chunk_adapter.gd` | **Abstract.** Override to mount/unmount a loaded chunk into the scene. |
| `SKChunkUtils` | `sk_chunk_utils.gd` | Coordinate helpers (world-to-chunk, distance, neighbour enumeration). |
| `SKCancelToken` | `sk_cancel_token.gd` | Cooperative cancellation token for async loads. |
| `SKChunkDebugDraw` | `sk_chunk_debug_draw.gd` | `ImmediateMesh` visualiser for active/preload radii (editor & runtime). |
| `ExampleChunkSource` | `example_chunk_source.gd` | Reference implementation showing how to implement `SKChunkSource`. |
| `ExampleChunkAdapter` | `example_chunk_adapter.gd` | Reference implementation showing how to implement `SKChunkAdapter`. |

---

## Concepts

### Coordinates

Chunks are addressed by integer 2-D grid coordinates (`Vector2i`).  World
positions are converted to chunk coordinates with `SKChunkUtils.world_to_chunk`.

### Active and preload radii

- **Active radius** — chunks within this distance are fully loaded and mounted.
- **Preload radius** — chunks between active and preload radius are loaded but
  not yet mounted, so they are ready to snap into the scene instantly.

### LRU eviction

The manager maintains an LRU cache.  When the cache exceeds its capacity, the
least recently used non-active chunk is unloaded.

### Multi-origin

Call `update_multi(origins)` to support split-screen or co-op, where multiple
players each pull chunks into the active radius.

---

## Implementing a chunk source

```gdscript
class_name MyChunkSource
extends SKChunkSource

func load_chunk(coord: Vector2i, token: SKCancelToken) -> Variant:
    # Load from disk, generate procedurally, etc.
    # Check token.is_cancelled() periodically for long operations.
    if token.is_cancelled():
        return null
    var scene_path := "res://chunks/chunk_%d_%d.tscn" % [coord.x, coord.y]
    if not ResourceLoader.exists(scene_path):
        return null
    return ResourceLoader.load(scene_path)
```

---

## Implementing a chunk adapter

```gdscript
class_name MyChunkAdapter
extends SKChunkAdapter

func mount(coord: Vector2i, data: Variant, scene_root: Node) -> void:
    if not data is PackedScene:
        return
    var instance := (data as PackedScene).instantiate()
    instance.position = SKChunkUtils.chunk_to_world(coord, chunk_size)
    scene_root.add_child(instance)


func unmount(coord: Vector2i, scene_root: Node) -> void:
    # Find and free the mounted instance
    for child in scene_root.get_children():
        if child.get_meta("chunk_coord", Vector2i.MAX) == coord:
            child.queue_free()
            break
```

---

## Wiring up the manager

```gdscript
@onready var chunk_manager: SKChunkManager = $SKChunkManager

func _ready() -> void:
    chunk_manager.chunk_size = 64.0        # world units per chunk
    chunk_manager.active_radius = 2         # chunks in each direction
    chunk_manager.preload_radius = 3
    chunk_manager.max_concurrent_loads = 4
    chunk_manager.max_load_retries = 2
    chunk_manager.use_circular_radius = true
    chunk_manager.source = MyChunkSource.new()
    chunk_manager.adapter = MyChunkAdapter.new()
    chunk_manager.scene_root = get_tree().current_scene
    chunk_manager.update(player.global_position)  # first tick
```

Call `update(origin)` or `update_multi(origins)` each frame (or whenever the
origin moves more than a chunk):

```gdscript
func _process(_delta: float) -> void:
    chunk_manager.update(player.global_position)
```

---

## Debug visualiser

Add an `SKChunkDebugDraw` node as a child of the chunk manager to see active
and preload radii drawn with `ImmediateMesh` in the viewport:

```gdscript
var debug := SKChunkDebugDraw.new()
chunk_manager.add_child(debug)
```

Configure `active_color` and `preload_color` for distinct visual feedback.

---

## Load lifecycle signals

`SKChunkManager` emits the following signals:

| Signal | When |
|---|---|
| `chunk_loaded(coord)` | A chunk's data has finished loading. |
| `chunk_mounted(coord)` | A chunk has been mounted into the scene. |
| `chunk_unloaded(coord)` | A chunk's data has been freed from memory. |
| `chunk_unmounted(coord)` | A chunk has been removed from the scene. |
| `load_failed(coord, attempt)` | A load attempt failed; `attempt` is the retry count. |

---

## GUT tests

See `tests/test_chunk_manager.gd` for unit tests covering async loading, active
radius clamping, LRU eviction, cancellation, and multi-origin updates.
