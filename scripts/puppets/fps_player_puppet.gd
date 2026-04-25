class_name FPSPlayerPuppet
extends CharacterBody3D
## First-person player puppet for Skelerealms.
##
## Attach this script to a [CharacterBody3D] scene that will be used as the
## in-scene puppet for a player [SKEntity]. The scene is normally placed as a
## child of a [PuppetSpawnerComponent]; [PlayerComponent] then connects the
## [signal update_position] signal automatically so the entity stays in sync.
##
## [b]Required child nodes[/b] (configure paths via exports if names differ):
## [br]• A [Camera3D] — default path [code]Camera3D[/code]
## [br]• A [CollisionShape3D] for standing — default path [code]StandingCollisionShape[/code]
## [br]• A [CollisionShape3D] for crouching (optional) — default [code]CrouchingCollisionShape[/code]
##
## [b]Required input actions[/b] (add to your project's Input Map):
## [br]• [code]move_forward[/code], [code]move_back[/code], [code]move_left[/code], [code]move_right[/code]
## [br]• [code]jump[/code]
## [br]• [code]sprint[/code]
## [br]• [code]crouch[/code]
## [br]• [code]interact[/code]
##
## See [code]docs/user guide/fps_controller.md[/code] for full setup instructions.


## Emitted every physics frame with the puppet's world position so the entity
## position stays in sync. [PlayerComponent] connects this automatically.
signal update_position(pos: Vector3)

# ── Node paths ───────────────────────────────────────────────────────────────
@export_group("Node Paths")
## Path to the [Camera3D] used as the player's eye.
@export_node_path("Camera3D") var camera_path: NodePath = ^"Camera3D"
## Path to the standing [CollisionShape3D].
@export_node_path("CollisionShape3D") var standing_collision_path: NodePath = ^"StandingCollisionShape"
## Path to the crouching [CollisionShape3D]. Leave blank to skip.
@export_node_path("CollisionShape3D") var crouching_collision_path: NodePath = ^"CrouchingCollisionShape"
## Path to the [SKHUDShell] for interaction prompts and crosshair updates.
## Leave blank to skip HUD integration.
@export_node_path("Control") var hud_path: NodePath

# ── Movement ─────────────────────────────────────────────────────────────────
@export_group("Movement")
## Normal walking speed (m/s).
@export var walk_speed: float = 5.0
## Sprint speed (m/s). Applied while the [code]sprint[/code] action is held.
@export var sprint_speed: float = 8.0
## Crouch movement speed (m/s).
@export var crouch_speed: float = 3.0
## Impulse applied when jumping.
@export var jump_velocity: float = 4.5
## How much the camera drops when crouching (metres). Positive = down.
@export var crouch_depth: float = 0.9
## Velocity interpolation speed while grounded. Higher = snappier.
@export var lerp_speed: float = 10.0
## Velocity interpolation speed while airborne.
@export var air_lerp_speed: float = 6.0

# ── Camera ───────────────────────────────────────────────────────────────────
@export_group("Camera")
## Degrees of rotation per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.25
## If [code]true[/code], moving the mouse up pitches the camera downward.
@export var invert_y: bool = false

# ── Headbob ──────────────────────────────────────────────────────────────────
@export_group("Headbob")
@export var headbob_walk_intensity: float = 0.03
@export var headbob_walk_speed: float = 12.0
@export var headbob_sprint_intensity: float = 0.05
@export var headbob_sprint_speed: float = 16.0
@export var headbob_crouch_intensity: float = 0.08
@export var headbob_crouch_speed: float = 8.0

# ── Stamina ──────────────────────────────────────────────────────────────────
@export_group("Stamina")
## Moxie (stamina) drained per second while sprinting. Set to 0 to disable.
@export var sprint_moxie_drain: float = 5.0

# ── Interaction ──────────────────────────────────────────────────────────────
@export_group("Interaction")
## Maximum distance (metres) at which the player can interact with objects.
@export var interaction_range: float = 2.5
## Input action name for the interact button.
@export var interact_action: StringName = &"interact"

# ── Private ──────────────────────────────────────────────────────────────────
var _camera: Camera3D
var _standing_collision: CollisionShape3D
var _crouching_collision: CollisionShape3D
var _hud: Control  # SKHUDShell — kept as Control to avoid hard type dep

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _is_sprinting: bool = false
var _is_crouching: bool = false
var _wiggle_index: float = 0.0
var _camera_base_y: float = 0.0

var _vitals: VitalsComponent
var _entity: SKEntity


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	if not _camera:
		push_warning("FPSPlayerPuppet '%s': no Camera3D found at '%s'." % [name, camera_path])

	if not standing_collision_path.is_empty():
		_standing_collision = get_node_or_null(standing_collision_path) as CollisionShape3D
	if not crouching_collision_path.is_empty():
		_crouching_collision = get_node_or_null(crouching_collision_path) as CollisionShape3D

	if not hud_path.is_empty():
		_hud = get_node_or_null(hud_path)

	if _camera:
		_camera_base_y = _camera.position.y

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Resolve the parent entity (puppet → PuppetSpawnerComponent → SKEntity).
	var parent_component := get_parent()
	if parent_component and parent_component.get_parent() is SKEntity:
		_entity = parent_component.get_parent() as SKEntity
		_vitals = _entity.get_component("VitalsComponent") as VitalsComponent


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_look(event as InputEventMouseMotion)


func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	if not _camera:
		return
	var y_factor: float = -1.0 if invert_y else 1.0
	rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
	_camera.rotate_x(deg_to_rad(event.relative.y * mouse_sensitivity * y_factor))
	_camera.rotation.x = clampf(_camera.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))


func _physics_process(delta: float) -> void:
	# ── Gravity ──────────────────────────────────────────────────────────────
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# ── Jump ─────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# ── Crouch ───────────────────────────────────────────────────────────────
	var want_crouch := Input.is_action_pressed("crouch")
	if want_crouch != _is_crouching:
		_set_crouch(want_crouch)

	# ── Sprint ────────────────────────────────────────────────────────────────
	var can_sprint := not _is_crouching and (not _vitals or not _vitals.is_exhausted)
	_is_sprinting = can_sprint and Input.is_action_pressed("sprint")

	if _is_sprinting and _vitals and not is_zero_approx(sprint_moxie_drain):
		_vitals.change_moxie(-sprint_moxie_drain * delta)

	# ── Horizontal movement ───────────────────────────────────────────────────
	var current_speed: float = sprint_speed if _is_sprinting else (crouch_speed if _is_crouching else walk_speed)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var lerp_factor := lerp_speed if is_on_floor() else air_lerp_speed
	var weight: float = clampf(lerp_factor * delta, 0.0, 1.0)
	velocity.x = lerp(velocity.x, direction.x * current_speed, weight)
	velocity.z = lerp(velocity.z, direction.z * current_speed, weight)
	move_and_slide()

	# ── Headbob ───────────────────────────────────────────────────────────────
	_update_headbob(delta, direction)

	# ── Sync entity position ──────────────────────────────────────────────────
	update_position.emit(global_position)

	# ── Interaction prompt ────────────────────────────────────────────────────
	_update_interaction_prompt()


func _set_crouch(crouching: bool) -> void:
	_is_crouching = crouching
	if _standing_collision:
		_standing_collision.disabled = crouching
	if _crouching_collision:
		_crouching_collision.disabled = not crouching
	if _camera:
		var target_y := _camera_base_y - (crouch_depth if crouching else 0.0)
		var tw := create_tween()
		tw.tween_property(_camera, "position:y", target_y, 0.15)


func _update_headbob(delta: float, direction: Vector3) -> void:
	if not _camera:
		return
	if direction.is_zero_approx() or not is_on_floor():
		# Smoothly return to base position when still or airborne.
		var return_weight: float = clampf(lerp_speed * delta, 0.0, 1.0)
		_camera.position.y = lerp(_camera.position.y, _camera_base_y, return_weight)
		_camera.position.x = lerp(_camera.position.x, 0.0, return_weight)
		return

	var intensity: float
	var speed: float
	if _is_crouching:
		intensity = headbob_crouch_intensity
		speed = headbob_crouch_speed
	elif _is_sprinting:
		intensity = headbob_sprint_intensity
		speed = headbob_sprint_speed
	else:
		intensity = headbob_walk_intensity
		speed = headbob_walk_speed

	_wiggle_index += delta * speed
	_camera.position.y = _camera_base_y + sin(_wiggle_index) * intensity
	# Horizontal sway uses half the vertical frequency for a natural figure-8 motion.
	_camera.position.x = sin(_wiggle_index * 0.5) * intensity


func _update_interaction_prompt() -> void:
	if not _camera:
		return

	var space := get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from + (-_camera.global_transform.basis.z * interaction_range)
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.exclude = [get_rid()]
	var result := space.intersect_ray(ray)

	if result.is_empty():
		_hide_prompt()
		_set_crosshair(&"default")
		return

	var collider: Object = result["collider"]

	# ── InteractiveObject (world object) ──────────────────────────────────────
	var io := _find_interactive_object(collider as Node)
	if io and io.interactible:
		_show_prompt("%s %s" % [io.interact_verb, io.object_name], interact_action)
		_set_crosshair(&"interactive")
		if Input.is_action_just_pressed(interact_action):
			io.interact(_entity.name if _entity else "")
		return

	# ── SKEntity with InteractiveComponent ────────────────────────────────────
	var ic := _find_interactive_component(collider as Node)
	if ic and ic.interactible:
		_show_prompt("%s %s" % [ic.interact_verb, ic.interact_name], interact_action)
		_set_crosshair(&"interactive")
		if Input.is_action_just_pressed(interact_action):
			ic.interact_by_player()
		return

	_hide_prompt()
	_set_crosshair(&"default")


## Walk the scene tree from [param node] upward looking for an [InteractiveObject].
func _find_interactive_object(node: Node) -> InteractiveObject:
	var n := node
	while n:
		if n is InteractiveObject:
			return n as InteractiveObject
		n = n.get_parent()
	return null


## Walk the scene tree from [param node] upward to find an [SKEntity] that has
## an [InteractiveComponent].
func _find_interactive_component(node: Node) -> InteractiveComponent:
	var n := node
	while n:
		if n is SKEntity:
			return (n as SKEntity).get_component("InteractiveComponent") as InteractiveComponent
		n = n.get_parent()
	return null


func _show_prompt(text: String, action: StringName) -> void:
	if _hud and _hud.has_method("show_interaction_prompt"):
		_hud.call("show_interaction_prompt", text, action)


func _hide_prompt() -> void:
	if _hud and _hud.has_method("hide_interaction_prompt"):
		_hud.call("hide_interaction_prompt")


func _set_crosshair(state: StringName) -> void:
	if _hud and _hud.has_method("set_crosshair_state"):
		_hud.call("set_crosshair_state", state)
