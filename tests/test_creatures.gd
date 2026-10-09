## Integration tests for creature body plans (WS-B non-humanoid puppets).
## Run with the GUT framework (https://github.com/bitwes/Gut).
extends GutTest


class _ManagerFixture extends SKEntityManager:
	func _ready() -> void:
		pass


class _EntityFixture extends SKEntity:
	func _process(_delta: float) -> void:
		pass

	func get_component(type: String) -> SKEntityComponent:
		return get_node_or_null(type) as SKEntityComponent


var _manager: SKEntityManager


func before_each() -> void:
	_manager = _ManagerFixture.new()
	add_child_autofree(_manager)


# ── Fixture builders ─────────────────────────────────────────────────────


func _profile(mode: CreatureProfile.MovementMode) -> CreatureProfile:
	var prof := CreatureProfile.new()
	prof.id = &"test_beast"
	prof.movement_mode = mode
	prof.move_speed = 6.0
	prof.turn_speed = 6.0
	prof.arrive_radius = 1.5
	prof.collision_radius = 0.5
	prof.collision_height = 1.0
	prof.perception_range_mult = 1.5
	prof.perception_fov_mult = 2.0
	return prof


## Full NPC stack with a creature puppet under the spawner, ticking silenced
## except the puppet itself (steering under test needs physics frames).
func _make_creature(ref: StringName, pos: Vector3, profile: CreatureProfile) -> SKEntity:
	var e := _EntityFixture.new()
	e.name = ref
	e.form_id = &"beast"
	e.world = &"w"
	e.position = pos
	e.add_child(NPCComponent.new())
	e.add_child(NavigatorComponent.new())
	var spawner := PuppetSpawnerComponent.new()
	e.add_child(spawner)
	e.add_child(InteractiveComponent.new())
	e.add_child(GOAPComponent.new())
	e.add_child(ViewDirectionComponent.new())
	var puppet := CreaturePuppet.new()
	puppet.profile = profile
	var agent := NavigationAgent3D.new()
	agent.name = "NavigationAgent3D"
	puppet.add_child(agent)
	puppet.add_child(CollisionShape3D.new())
	spawner.add_child(puppet)
	puppet.position = pos
	for c in e.get_children():
		(c as Node).set_process(false)
		(c as Node).set_physics_process(false)
	_manager._add_entity_raw(e)
	return e


func _puppet_of(ref: StringName) -> CreaturePuppet:
	var e := _manager.entities[ref] as SKEntity
	return (e.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent).puppet as CreaturePuppet


# ── Profiles ─────────────────────────────────────────────────────────────


func test_profile_validate() -> void:
	var good := _profile(CreatureProfile.MovementMode.GROUND)
	assert_eq(good.validate(), [], "Sound profiles validate clean.")
	var bad := CreatureProfile.new()
	bad.move_speed = 0.0
	bad.turn_speed = -1.0
	bad.arrive_radius = 0.0
	bad.collision_radius = 0.0
	bad.perception_range_mult = 0.0
	var issues: Array = bad.validate()
	assert_eq(issues.size(), 5, "Each defect must report.")
	var kinds := {}
	for issue in issues:
		kinds[str(issue["type"])] = true
	assert_true(kinds.has("bad_speed") and kinds.has("bad_turn") and kinds.has("bad_arrive"), "Locomotion defects must be typed.")
	assert_true(kinds.has("bad_collision") and kinds.has("bad_senses"), "Body and sense defects must be typed.")


func test_ground_profile_configures_body() -> void:
	var e := _make_creature(&"wolf", Vector3.ZERO, _profile(CreatureProfile.MovementMode.GROUND))
	var puppet := _puppet_of(&"wolf")
	assert_eq(puppet.movement_speed, 6.0, "Profile speed must apply.")
	var shape: CapsuleShape3D = null
	for child in puppet.get_children():
		if child is CollisionShape3D:
			shape = (child as CollisionShape3D).shape as CapsuleShape3D
	assert_ne(shape, null, "Profile must build a capsule.")
	assert_eq(shape.radius, 0.5, "Capsule radius must apply.")
	assert_eq(shape.height, 1.0, "Capsule height must apply.")


func test_profile_scales_senses_once() -> void:
	var puppet := CreaturePuppet.new()
	puppet.profile = _profile(CreatureProfile.MovementMode.GROUND)
	var eyes := EyesPerception.new()
	puppet.add_child(eyes)
	puppet.apply_profile()
	assert_eq(eyes.view_distance, 45.0, "Range must scale (30 x 1.5).")
	assert_eq(eyes.fov_h, 179.0, "FOV must scale and clamp (90 x 2).")
	assert_eq(eyes.fov_v, 179.0, "Vertical FOV must scale and clamp.")
	puppet.apply_profile()
	assert_eq(eyes.view_distance, 45.0, "Re-application must not compound.")
	puppet.free()


func test_target_store_skips_navmesh_for_flyers() -> void:
	var puppet := CreaturePuppet.new()
	puppet.profile = _profile(CreatureProfile.MovementMode.FLY)
	puppet.set_movement_target(Vector3(1, 2, 3))
	assert_eq(puppet.movement_target_position, Vector3(1, 2, 3), "Targets must store without a nav agent.")
	puppet.free()


# ── Flight ───────────────────────────────────────────────────────────────


func test_flyer_steers_and_climbs() -> void:
	var e := _make_creature(&"bird", Vector3.ZERO, _profile(CreatureProfile.MovementMode.FLY))
	_puppet_of(&"bird").set_movement_target(Vector3(10, 8, -20))
	for i in 90:
		await get_tree().physics_frame
	var puppet := _puppet_of(&"bird")
	assert_true(puppet.global_position.distance_to(Vector3(10, 8, -20)) < 22.0, "Flyers must close distance.")
	assert_true(puppet.global_position.y > 2.0, "Flyers must climb toward targets.")
	assert_true(absf(puppet.rotation.y) > 0.1, "Flyers must yaw toward targets.")


func test_flyer_settles_on_arrival() -> void:
	var e := _make_creature(&"bird", Vector3.ZERO, _profile(CreatureProfile.MovementMode.FLY))
	var puppet := _puppet_of(&"bird")
	puppet.set_movement_target(Vector3(0.5, 0, 0))
	for i in 30:
		await get_tree().physics_frame
	assert_true((puppet as CharacterBody3D).velocity.length() < 1.0, "Arrived flyers must settle.")
	assert_true(puppet.global_position.distance_to(Vector3.ZERO) < 3.0, "Arrived flyers must hold.")


# ── Shared movement math ──────────────────────────────────────────────────


func test_steering_velocity() -> void:
	var Movement := preload("res://addons/skelerealms/scripts/ai/Modules/default_movement.gd")
	assert_eq(Movement.steering_velocity(Vector3.ZERO, Vector3(3, 0, 4), 10.0), Vector3(6, 0, 8), "3-4-5 triangle must scale.")
	assert_eq(Movement.steering_velocity(Vector3.ZERO, Vector3.ZERO, 10.0), Vector3.ZERO, "Zero distance must hold still.")
	assert_eq(Movement.steering_velocity(Vector3.ZERO, Vector3(1, 0, 0), 0.0), Vector3.ZERO, "Zero speed must hold still.")
