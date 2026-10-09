# AI Packages

Packages give civilian NPCs a daily life: eat at the tavern, sleep in a bed,
work the forge, patrol the walls. A `PackageComponent` evaluates an ordered
package stack against time windows, needs, and target reachability, and
`PackageMovementModule` steers the winner's puppet and sits them in tagged
furniture. Schedules keep handling scripted sequences — packages own the
unscripted day.

Precedence, highest first: combat/busy > companion-follow > packages >
schedules. The movement module writes puppet targets every tick while its
package is active; when nothing is valid it goes quiet and schedules flow
again.

## Defining a package

Each `AIPackage` resource on the component:

| Property | Type | Description |
|---|---|---|
| `id` / `activity` | `StringName` | Unique id; activity label for debugging/UI. |
| `priority` | `int` | Base priority. Effective priority adds 100× the gated need value (needs run 0..1), so hungrier NPCs prefer food automatically. |
| `start_hour` / `end_hour` | `float` | Time window in game hours. Equal means always; overnight windows wrap. |
| `need_id` / `need_min` | `StringName` / `float` | Only valid while this need reads ≥ min. NPCs without a `NeedsComponent` skip need-gated packages. |
| `target_entity` | `StringName` | Entity ref to walk to. Must exist in the same world (streamed-out targets heal on later ticks). |
| `target_position` / `target_world` | `Vector3` / `String` | Fixed-point fallback. Blank means "right here". |
| `furniture_tag` | `StringName` | Scene group tag to occupy on arrival. Only seats within reach count. |

Evaluation re-runs every game minute, on need updates, and on demand via
`evaluate()`, which returns the active package (or null when idling).
`package_changed` fires only on changes. Validate lists with `validate()`
(duplicate ids). The active package id persists in saves.

## Furniture

`PackageMovementModule` finds seats with
`SkeleRealmsGlobal.find_alternative_furniture(tag)` — any `Furniture` node in
that scene group with room. Tag your chairs, beds, and workstations, and the
module occupies on arrival and releases on switches.
