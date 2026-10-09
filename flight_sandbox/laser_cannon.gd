extends Node3D
## Hitscan laser cannon. Attach as a child of a ship body (the shooter) at
## the muzzle position; shots travel along the node's local -Z.
##
## Hits only bodies in [member target_group] that expose
## [code]take_damage(amount)[/code]. The shooter's own body is always
## excluded, so self-hits are impossible. Keeps the sandbox dependency-free:
## no framework classes are referenced.

enum FireResult { FIRED_HIT, FIRED_MISS, COOLDOWN, NO_SHOT }

## Damage dealt on a landed hit. Shields absorb before hull (see ship_controller).
@export var damage := 12.0
## Maximum ray length in metres.
@export var weapon_range := 300.0
## Seconds between shots.
@export var cooldown := 0.25
## Bodies outside this group are treated as terrain: the beam stops but no
## damage is dealt.
@export var target_group := &"hostile_drone"
## Input action that requests fire. Leave empty for AI/test-driven weapons.
@export var fire_action := &"flight_fire"

## Emitted after every resolved shot. True when damage was dealt.
signal fired(hit: bool)

var shooter: RigidBody3D
var _cooldown_left := 0.0
var _fire_requested := false
var _beam: MeshInstance3D
var _beam_mesh: ImmediateMesh
var _beam_left := 0.0
var _spark: MeshInstance3D
var _spark_left := 0.0
const BEAM_LIFETIME := 0.07
const SPARK_LIFETIME := 0.15


func _ready() -> void:
	shooter = get_parent() as RigidBody3D
	_beam_mesh = ImmediateMesh.new()
	_beam = MeshInstance3D.new()
	_beam.mesh = _beam_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("7df0ff")
	_beam.material_override = material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)
	_spark = MeshInstance3D.new()
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.35
	spark_mesh.height = 0.7
	_spark.mesh = spark_mesh
	_spark.material_override = material
	_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spark.visible = false
	_spark.top_level = true
	add_child(_spark)


func _unhandled_input(event: InputEvent) -> void:
	if fire_action != &"" and event.is_action_pressed(fire_action):
		_fire_requested = true


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _beam_left > 0.0:
		_beam_left -= delta
		if _beam_left <= 0.0:
			_beam.visible = false
	if _spark_left > 0.0:
		_spark_left -= delta
		var f := clampf(_spark_left / SPARK_LIFETIME, 0.0, 1.0)
		_spark.scale = Vector3.ONE * (0.5 + f)
		if _spark_left <= 0.0:
			_spark.visible = false
	if _fire_requested:
		_fire_requested = false
		fire()


## Resolve one shot immediately. Safe to call from AI or tests; input
## handling only sets a request flag so the ray runs inside physics.
func fire() -> int:
	if _cooldown_left > 0.0:
		return FireResult.COOLDOWN
	if shooter == null or not is_instance_valid(shooter):
		return FireResult.NO_SHOT
	if bool(shooter.get("destroyed_flag")):
		return FireResult.NO_SHOT
	if not bool(shooter.get("controls_enabled")):
		return FireResult.NO_SHOT
	_cooldown_left = cooldown
	var from := global_position
	var direction := -global_transform.basis.z.normalized()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * weapon_range)
	query.exclude = [shooter.get_rid()]
	var result := space.intersect_ray(query)
	if result.is_empty():
		_draw_beam(to_local(from + direction * weapon_range))
		fired.emit(false)
		return FireResult.FIRED_MISS
	var end_point: Vector3 = result["position"]
	_draw_beam(to_local(end_point))
	_spark.global_position = end_point
	_spark.scale = Vector3.ONE * 1.5
	_spark.visible = true
	_spark_left = SPARK_LIFETIME
	var collider: Object = result["collider"]
	var hit := false
	if collider != shooter and collider is Node and (collider as Node).is_in_group(target_group) and collider.has_method("take_damage"):
		(collider as Node).call("take_damage", damage)
		hit = true
	fired.emit(hit)
	return FireResult.FIRED_HIT if hit else FireResult.FIRED_MISS


func _draw_beam(local_end: Vector3) -> void:
	_beam_mesh.clear_surfaces()
	_beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_beam_mesh.surface_add_vertex(Vector3.ZERO)
	_beam_mesh.surface_add_vertex(local_end)
	_beam_mesh.surface_end()
	_beam.visible = true
	_beam_left = BEAM_LIFETIME
