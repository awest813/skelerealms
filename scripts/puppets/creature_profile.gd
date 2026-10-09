class_name CreatureProfile
extends Resource
## Body plan for a non-humanoid puppet, read by CreaturePuppet.
## Scenes author the mesh, eyes, and ears; the profile scales locomotion,
## collision, and senses per species. Ground bodies use the standard
## navigation pipeline (plus any movement module); flyers steer themselves
## in open air and need no navigation mesh. Swimming is a later profile.


enum MovementMode {
	GROUND, ## Walk the navmesh like any NPC (quadrupeds, crawlers).
	FLY, ## Self-steered 3D flight toward movement targets, no navmesh.
}


## Stable id, e.g. &"cliff_racer".
@export var id: StringName
## Display name for debugging and UI.
@export var display_name: String = ""
## How this body moves.
@export var movement_mode: MovementMode = MovementMode.GROUND
## Top speed in m/s.
@export var move_speed: float = 4.0
## Turn rate in rad/s (flyers) — also a hint for ground steering.
@export var turn_speed: float = 3.0
## Flyers settle inside this distance instead of orbiting the target.
@export var arrive_radius: float = 1.5
## Collision capsule radius applied to the first CollisionShape3D child.
@export var collision_radius: float = 0.4
## Collision capsule height, applied the same way.
@export var collision_height: float = 1.2
## Multipliers over scene-authored eye range and FOV (predators see far).
@export var perception_range_mult: float = 1.0
## See perception_range_mult.
@export var perception_fov_mult: float = 1.0


## Structural sanity. Returns issue dicts {type, detail}; empty means sound.
func validate() -> Array:
	var issues: Array = []
	if move_speed <= 0.0:
		issues.append({"type": "bad_speed", "detail": "Profile '%s' needs move_speed above zero." % id})
	if turn_speed <= 0.0:
		issues.append({"type": "bad_turn", "detail": "Profile '%s' needs turn_speed above zero." % id})
	if arrive_radius <= 0.0:
		issues.append({"type": "bad_arrive", "detail": "Profile '%s' needs arrive_radius above zero." % id})
	if collision_radius <= 0.0 or collision_height <= 0.0:
		issues.append({"type": "bad_collision", "detail": "Profile '%s' needs a positive collision capsule." % id})
	if perception_range_mult <= 0.0 or perception_fov_mult <= 0.0:
		issues.append({"type": "bad_senses", "detail": "Profile '%s' needs positive perception multipliers." % id})
	return issues
