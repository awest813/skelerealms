class_name AIPackage
extends Resource
## One daily-life behavior for an NPC: eat at the tavern, sleep in a bed,
## work the forge, patrol the walls, stand guard. Evaluated by
## PackageComponent against time windows, needs, and target reachability;
## executed by PackageMovementModule. Schedules keep handling scripted
## sequences — packages own the unscripted day.


## Unique ID within the NPC's package list.
@export var id: StringName
## Activity label for debugging and UI ("eat", "sleep", "work", "patrol", ...).
@export var activity: StringName = &"loiter"
## Base priority. Effective priority adds 100x the gated need value
## (needs run 0..1), so hungrier NPCs automatically prefer food without
## authoring per-level priorities.
@export var priority: int = 0
## Time window in game hours. start_hour == end_hour means always.
## Overnight windows wrap (22.0 → 6.0).
@export var start_hour: float = 0.0
## See start_hour.
@export var end_hour: float = 0.0
## Needs gate: only valid while this need is at least need_min.
## NPCs without a NeedsComponent skip need-gated packages entirely.
@export var need_id: StringName
## See need_id.
@export var need_min: float = 0.0
## Entity ref-ID to walk to. Empty means no entity target.
@export var target_entity: StringName
## Fixed world position when target_entity is empty. Zero with no world
## means loiter here; set target_world to target the world's origin.
@export var target_position: Vector3 = Vector3.ZERO
## World the fixed point lives in (ignored for entity targets).
@export var target_world: String = ""
## Furniture group tag to occupy on arrival (see SkeleRealmsGlobal
## find_alternative_furniture). Empty means just stand there.
@export var furniture_tag: StringName
