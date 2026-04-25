class_name SKFootstepPlayer
extends Node3D
## Surface-aware footstep audio player inspired by Cogito's Dynamic Footstep System.
##
## Attach as a child of your player puppet (or any [CharacterBody3D] / [Node3D]).
## Add [AudioStreamPlayer3D] children to this node — one per surface type — and
## name each child after the physics-body group that marks that surface. A child
## named [code]"default"[/code] is used as the fallback when no group matches.
##
## [b]Example child layout:[/b]
## [codeblock]
## SKFootstepPlayer
##   ├─ stone       (AudioStreamPlayer3D — stone footstep sounds)
##   ├─ wood        (AudioStreamPlayer3D — wood footstep sounds)
##   ├─ grass       (AudioStreamPlayer3D — grass footstep sounds)
##   └─ default     (AudioStreamPlayer3D — fallback footstep sounds)
## [/codeblock]
##
## Mark floors in your scene by adding matching groups to their [StaticBody3D]
## (or any [PhysicsBody3D]) via the Node → Groups panel in the editor, e.g. add
## the group [code]"stone"[/code] to a stone floor's physics body.
##
## Call [method play_footstep] from your puppet's movement code whenever a step
## should be heard (timed by velocity or a timer).
##
## [b]Audio setup tip:[/b] Use [AudioStreamRandomizer] on each
## [AudioStreamPlayer3D] to randomise pitch/volume and select from multiple
## sound files per surface, avoiding a repetitive single-sample loop.


## How far below the node to cast the surface-detection ray.
@export var raycast_length: float = 2.0
## Collision mask for the surface ray. Must include the layer(s) your floors
## occupy (default 1).
@export_flags_3d_physics var raycast_mask: int = 1

## Volume offset (dB) applied to footstep sounds while walking.
@export_group("Volume")
@export var walk_volume_db: float = -38.0
## Volume offset (dB) applied to footstep sounds while sprinting.
@export var sprint_volume_db: float = -30.0
## Volume offset (dB) applied to footstep sounds while crouching.
@export var crouch_volume_db: float = -60.0

## Cache: child name → AudioStreamPlayer3D
var _players: Dictionary[StringName, AudioStreamPlayer3D] = {}


func _ready() -> void:
	_rebuild_player_cache()
	child_order_changed.connect(_rebuild_player_cache)


## Play a footstep sound appropriate for the surface directly below this node.
## [param volume_db] overrides the automatic walk/sprint/crouch selection; pass
## [code]NAN[/code] (the default) to use [member walk_volume_db].
func play_footstep(volume_db: float = NAN) -> void:
	var surface_group := _detect_surface_group()
	var player := _players.get(surface_group, null)
	if not player:
		player = _players.get(&"default", null)
	if not player:
		return  # No matching or fallback audio player.

	if is_nan(volume_db):
		volume_db = walk_volume_db

	player.volume_db = volume_db
	player.play()


## Play a footstep at sprint volume.
func play_footstep_sprint() -> void:
	play_footstep(sprint_volume_db)


## Play a footstep at crouch volume.
func play_footstep_crouch() -> void:
	play_footstep(crouch_volume_db)


## Return the [StringName] of the surface group detected below this node, or
## [code]&""[/code] if nothing is found.
func _detect_surface_group() -> StringName:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var to := from + Vector3.DOWN * raycast_length
	var query := PhysicsRayQueryParameters3D.create(from, to, raycast_mask)
	query.exclude = _get_owner_rids()
	var result := space.intersect_ray(query)
	if result.is_empty():
		return &""
	var body: Object = result.get("collider")
	if not body is Node:
		return &""
	# Check each registered surface group against the collider's groups.
	for group: StringName in _players:
		if group == &"default":
			continue
		if (body as Node).is_in_group(group):
			return group
	return &""


func _rebuild_player_cache() -> void:
	_players.clear()
	for child in get_children():
		if child is AudioStreamPlayer3D:
			_players[StringName(child.name)] = child as AudioStreamPlayer3D


## Collect RIDs of all physics bodies that are ancestors of this node so the
## surface ray does not accidentally hit the player's own collision shapes.
func _get_owner_rids() -> Array[RID]:
	var rids: Array[RID] = []
	var n: Node = get_parent()
	while n:
		if n is PhysicsBody3D:
			rids.append((n as PhysicsBody3D).get_rid())
		n = n.get_parent()
	return rids
