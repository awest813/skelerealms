class_name CompanionComponent
extends SKEntityComponent
## Marks an NPC as recruitable companion material and holds their
## companion state: recruitment, follow orders, affinity, home, and
## carry capacity. Inert unless recruited. Pair with a follow steering
## module (see CompanionFollowModule) and drive it via CompanionSystem.
##
## All state persists through the standard entity save/load.


## Whether this NPC currently travels with the player.
var recruited: bool = false
## Whether a recruited companion actively follows (false = waiting).
var following: bool = true
## Relationship score, -100..100. Milestones live in CompanionSystem.
var affinity: int = 0
## Where dismissed companions return. Captured at recruitment when empty.
var home_world: String = ""
## See home_world.
var home_position: Vector3 = Vector3.ZERO
## Max item count in the companion's InventoryComponent for trade/give flows.
var carry_capacity: int = 30
## Game-defined perk id granted at high affinity. Applied by the game
## (e.g. via EffectsComponent) when CompanionSystem reports the milestone.
var affinity_perk_id: StringName
## Desired trailing distance in metres.
var follow_distance: float = 3.0
## Beyond this distance the companion catches up by teleport instead of walking.
var catchup_distance: float = 60.0


func _init() -> void:
	name = "CompanionComponent"


## Items currently held, or 0 without an InventoryComponent.
func cargo_count() -> int:
	if parent_entity == null or not parent_entity.has_component("InventoryComponent"):
		return 0
	var inv := parent_entity.get_component("InventoryComponent") as InventoryComponent
	if inv == null:
		return 0
	return (inv.inventory as PackedStringArray).size()


## Whether n more items fit under carry_capacity.
func can_carry(extra: int = 1) -> bool:
	return cargo_count() + extra <= carry_capacity


func save() -> Dictionary:
	return {
		"recruited": recruited,
		"following": following,
		"affinity": affinity,
		"home_world": home_world,
		"home_position": [home_position.x, home_position.y, home_position.z],
		"carry_capacity": carry_capacity,
		"affinity_perk_id": str(affinity_perk_id),
		"follow_distance": follow_distance,
		"catchup_distance": catchup_distance,
	}


func load_data(data: Dictionary) -> void:
	recruited = bool(data.get("recruited", false))
	following = bool(data.get("following", true))
	affinity = clampi(int(data.get("affinity", 0)), -100, 100)
	home_world = str(data.get("home_world", ""))
	var pos: Array = data.get("home_position", [])
	if pos.size() >= 3:
		home_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	carry_capacity = maxi(0, int(data.get("carry_capacity", 30)))
	affinity_perk_id = StringName(str(data.get("affinity_perk_id", "")))
	follow_distance = maxf(0.0, float(data.get("follow_distance", 3.0)))
	catchup_distance = maxf(follow_distance, float(data.get("catchup_distance", 60.0)))
