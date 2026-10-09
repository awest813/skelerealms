# World Streaming

Exteriors stream; interiors load. A `WorldspaceDefinition` cuts an outdoor
area into a grid of `CellDefinition` squares that mount and unmount around
the player through the hardened `SKChunkManager` pipeline (radii, workers,
retries, LRU). Interiors stay door-loaded through `WorldLoader` — the cell
source skips interior cells and wilderness gaps mount as no-ops.

## Authoring cells

Each cell names a scene and a grid position. With cell size S, grid `(x, y)`
covers `[x*S, (x+1)*S)` by `[y*S, (y+1)*S)` on the XZ plane. **Author cell
content around the cell center** — the adapter places it at
`((x+0.5)*S, 0, (y+0.5)*S)` automatically. Keep cells small enough to
instantiate without hitches; the manager preloads ahead within
`preload_radius`.

```gdscript
var streamer := CellStreamer.new()
add_child(streamer)
streamer.start(preload("res://worlds/tundra.tres"))
await streamer.update_origin(player.global_position)  # call as the player moves
streamer.stop()  # disposes the grid, restores fade policy
```

Entering a worldspace applies its `actor_fade_distance` (and refreshes every
entity's cached value); leaving restores the previous one. Neighboring cells
load ahead inside the preload radius; only the active radius mounts.

Payload contract, for custom sources: the manager treats `null` as load
**error** (retried, then reported). Return `{}` for intentional emptiness.

## Verify world

`WorldValidator` runs the Creation-Kit-style checks headless — editor
tooling and content tests drive the same calls:

- `validate_doors(root, worlds)`: every `Door` needs a destination world
  present in the worlds map (same shape as `WorldLoader.world_paths`).
- `validate_cells(worldspace)` / `WorldspaceDefinition.validate()`:
  duplicate ids, grid collisions, missing scenes, bad entry/radii/sizes.
- `check_budgets(root, {max_meshes, max_lights})`: content counts vs limits.
- `validate_world(...)`: all three suites at once.
