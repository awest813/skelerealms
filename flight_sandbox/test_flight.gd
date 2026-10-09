extends SceneTree
const Ship = preload("res://ship_controller.gd")
const Laser = preload("res://laser_cannon.gd")
const Brain = preload("res://drone_brain.gd")
const ShipState = preload("res://ship_state.gd")
const Market = preload("res://market_service.gd")
const Missions = preload("res://mission_service.gd")
const Audio = preload("res://audio_manager.gd")
const Dialogue = preload("res://dialogue_service.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	var ship := Ship.new()
	ship.read_player_input = false
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	ship.add_child(collision)
	root.add_child(ship)
	await ticks(3)
	ship.thrust_command = Vector3.FORWARD
	await ticks(60)
	check(ship.position.z < -5 and ship.linear_velocity.z < -15, "Forward thrust must travel along -Z.")
	ship.thrust_command = Vector3.ZERO
	ship.assist_enabled = false
	await ticks(3) # Allow the previous physics tick's force to finish.
	var drift_speed := ship.linear_velocity.length()
	await ticks(30)
	check(absf(ship.linear_velocity.length() - drift_speed) < 0.1, "Unassisted ship should coast.")
	ship.brake_command = true
	ship.thrust_command = Vector3.FORWARD
	await ticks(90)
	check(ship.linear_velocity.length() < 0.01, "Brake must stop fully even with thrust held.")
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		ship.request_reset()
		await ticks(3)
		ship.thrust_command = axis
		await ticks(20)
		check(ship.linear_velocity.dot(axis) > 3, "Thrust failed on axis %s" % axis)
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		ship.request_reset()
		await ticks(3)
		ship.rotation_command = axis
		await ticks(20)
		check(ship.angular_velocity.dot(axis) > 0.2, "Rotation failed on axis %s" % axis)
	ship.request_reset()
	await ticks(3)
	check(ship.transform.is_equal_approx(Transform3D.IDENTITY), "Reset must restore position and orientation.")
	check(ship.linear_velocity.is_zero_approx() and ship.angular_velocity.is_zero_approx(), "Reset must clear both velocities.")
	ship.thrust_command = Vector3.FORWARD
	await ticks(20)
	paused = true
	var pose := ship.transform
	await ticks(10)
	check(ship.transform.is_equal_approx(pose), "Paused ship must not integrate physics.")
	paused = false
	ship.request_reset()
	await ticks(3)
	ship.assist_enabled = true
	ship.thrust_command = Vector3.RIGHT
	await ticks(20)
	ship.thrust_command = Vector3.ZERO
	await ticks(90)
	check(ship.linear_velocity.length() < 0.1, "Flight assist should arrest uncommanded drift.")
	ship.request_reset()
	await ticks(3)
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 0, -12)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 1)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	root.add_child(wall)
	ship.thrust_command = Vector3.FORWARD
	await ticks(90)
	check(ship.position.z > -12, "Ship must collide with course obstacles.")
	wall.queue_free()
	ship.request_reset()
	await ticks(3)
	ship.maximum_speed = 10
	ship.thrust_command = Vector3.FORWARD
	await ticks(90)
	check(ship.linear_velocity.length() < 10.5, "Speed governor must bound continuous thrust.")
	ship.zone_radius = 1
	await ticks(10)
	check(ship.boundary_resets > 0, "Crossing the compact zone boundary must recover the ship.")
	ship.queue_free()
	await process_frame
	_test_course()
	await _test_sandbox_pause()
	await _test_combat()
	await _test_travel()
	await _test_economy()
	await _test_polish()
	await _test_systems()
	await _test_factions()
	await _test_bethesda()
	await _test_routes()
	print("FLIGHT CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)


func _test_travel() -> void:
	var game := preload("res://main.tscn").instantiate()
	root.add_child(game)
	await ticks(5)
	check(game.current_system == &"sector_alpha", "Sandbox must start in the alpha system.")
	check(game.systems.size() == 4, "Jump network must hold two systems and two landing sites.")
	check(game.systems[&"sector_alpha"].links.has(&"outer_reach"), "Alpha must link to the reach.")
	check(game.systems[&"outer_reach"].links.has(&"sector_alpha"), "Reach must link back to alpha.")
	# Invalid destinations are rejected without side effects.
	var zone_before: Node = game.zone
	check(not game.jump_to(&"nowhere"), "Unknown destinations must be rejected.")
	check(game.current_system == &"sector_alpha", "Failed jumps must keep the current zone.")
	check(game.zone == zone_before, "Failed jumps must not rebuild the zone.")
	# Linked jump commits: durability persists, coordinates reset, old zone freed.
	game.ship.take_damage(20.0)
	var old_zone: WeakRef = weakref(game.zone)
	var old_drone: WeakRef = weakref(game.drone)
	check(game.jump_to(&"outer_reach"), "Linked jump must start.")
	check(game.current_system == &"outer_reach", "Jump must commit the destination system.")
	check(old_zone.get_ref() == null, "Replaced zone must be freed, not orphaned.")
	check(old_drone.get_ref() == null, "Old zone drone must be freed.")
	check(is_equal_approx(game.ship.shield, 30.0), "Durability must survive the jump.")
	check(game.ship.position.is_equal_approx(Vector3.ZERO), "Arrival must reset coordinates.")
	check(game.hud.system_name == "OUTER REACH", "HUD must track the current system.")
	check(game.course.next_gate == 0, "Arrival must reset course progress.")
	# Duplicate input during the travel lock is rejected.
	check(not game.jump_to(&"sector_alpha"), "Duplicate jump input must be rejected while traveling.")
	await ticks(60)
	check(game.jump_to(&"sector_alpha"), "Jump must work after the travel lock clears.")
	# Cross-zone save/load: the snapshot carries its system.
	game.ship.take_damage(10.0)
	game.save_ship()
	await ticks(60)
	check(game.jump_to(&"outer_reach"), "Return jump must start.")
	await ticks(60)
	game.load_ship()
	check(game.current_system == &"sector_alpha", "Loading an alpha save from the reach must restore alpha.")
	check(is_equal_approx(game.ship.shield, 20.0), "Loading must restore snapshot durability.")
	game.queue_free()
	await process_frame

func _test_course() -> void:
	var progress := preload("res://course_progress.gd").new()
	progress.gates = [Vector3(0, 0, -10), Vector3(0, 0, -20)]
	progress.advance(Vector3(30, 0, -15), 0.5)
	check(progress.next_gate == 0, "Flying outside a gate must not count.")
	progress.advance(Vector3(0, 0, 0), 0.5)
	check(progress.next_gate == 0, "Crossing backwards must not count.")
	progress.advance(Vector3(0, 0, -30), 0.5)
	check(progress.finished and progress.next_gate == 2, "Swept movement must detect ordered gates even across a long tick.")
	var finish_time := progress.elapsed
	progress.advance(Vector3.ZERO, 5)
	check(progress.elapsed == finish_time, "Completion must stop the timer.")
	progress.reset()
	check(progress.next_gate == 0 and progress.elapsed == 0 and not progress.finished, "Restart must clear progress.")
	progress.advance(Vector3(0, 0, -1), 0.5)
	progress.advance(Vector3(0, 0, -1), 0.5)
	check(progress.elapsed == 1.0, "Once started, course time includes stationary flight.")
	progress.reset()
	progress.advance(Vector3(0, 0, -30), 3.0)
	check(is_equal_approx(progress.elapsed, 2.0), "Finish time must interpolate the final gate crossing.")
	progress.reset()
	progress.advance(Vector3(0, 0, -10), 1.0)
	progress.advance(Vector3(0, 0, -20), 1.0)
	check(is_equal_approx(progress.elapsed, 2.0), "Finish time must agree across different tick sizes.")
	progress.reset()
	for i in range(1, 5):
		progress.advance(Vector3(0, 0, -0.0005 * i), 0.1)
	check(progress.started, "Slow cumulative movement must start the timer.")

func _combat_ship(at := Vector3.ZERO, groups: Array = []) -> RigidBody3D:
	var body := Ship.new()
	body.read_player_input = false
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	for group in groups:
		body.add_to_group(group)
	body.position = at
	root.add_child(body)
	return body


func _test_combat() -> void:
	# ── Laser hits, cooldown, shield-first damage ─────────────────────
	var shooter := _combat_ship()
	var cannon := Laser.new()
	cannon.target_group = &"hostile_drone"
	shooter.add_child(cannon)
	var target := _combat_ship(Vector3(0, 0, -40), [&"hostile_drone"])
	await ticks(3)
	check(cannon.fire() == Laser.FireResult.FIRED_HIT, "Laser must hit a drone dead ahead.")
	check(is_equal_approx(target.shield, 38.0), "Shields must absorb damage before hull.")
	check(is_equal_approx(target.hull, 100.0), "Hull must be untouched while shields hold.")
	check(cannon.fire() == Laser.FireResult.COOLDOWN, "Laser must respect its cooldown.")
	await ticks(20)
	check(cannon.fire() == Laser.FireResult.FIRED_HIT, "Laser must fire again after cooldown.")
	target.take_damage(30.0)
	check(is_equal_approx(target.shield, 0.0), "Overflow must deplete shields.")
	check(is_equal_approx(target.hull, 96.0), "Overflow damage must reach the hull.")
	# ── Faction filter and self-exclusion ─────────────────────────────
	var friendly := _combat_ship(Vector3(0, 300, 0), [&"player_ship"])
	target.position = Vector3(0, 300, 0)
	target.linear_velocity = Vector3.ZERO
	friendly.position = Vector3(0, 0, -30)
	friendly.linear_velocity = Vector3.ZERO
	await ticks(20)
	check(cannon.fire() == Laser.FireResult.FIRED_MISS, "Laser must not damage ships outside its target group.")
	check(is_equal_approx(friendly.hull, 100.0), "Friendly hull must be untouched.")
	friendly.position = Vector3(0, 300, 0)
	friendly.linear_velocity = Vector3.ZERO
	shooter.look_at(Vector3(500, 200, 500))
	await ticks(20)
	check(cannon.fire() == Laser.FireResult.FIRED_MISS, "Laser must miss empty space.")
	check(is_equal_approx(shooter.hull, 100.0), "Shooter must never damage itself.")
	# ── Destroyed exactly once ────────────────────────────────────────
	var destroyed_count := [0]
	target.connect("destroyed", func(): destroyed_count[0] += 1)
	target.take_damage(999.0)
	check(target.destroyed_flag, "Hull at zero must mark the ship destroyed.")
	check(destroyed_count[0] == 1, "Destruction must be reported exactly once.")
	target.take_damage(50.0)
	check(destroyed_count[0] == 1, "Post-destruction damage must be ignored.")
	var hulk := _combat_ship(Vector3(0, 500, 0))
	hulk.take_damage(9999.0)
	var hulk_cannon := Laser.new()
	hulk.add_child(hulk_cannon)
	check(hulk_cannon.fire() == Laser.FireResult.NO_SHOT, "A destroyed ship must not fire.")
	# ── Shield regen delay ────────────────────────────────────────────
	shooter.take_damage(10.0)
	shooter.shield_regen_delay = 0.5
	await ticks(5)
	check(is_equal_approx(shooter.shield, 40.0), "Regen must wait out its delay.")
	await ticks(40)
	check(shooter.shield > 40.0, "Shields must regenerate after the delay.")
	# ── Drone approach / attack / evade ───────────────────────────────
	var player := _combat_ship(Vector3(0, 100, 0), [&"player_ship"])
	var hunter := _combat_ship(Vector3(100, 0, 50), [&"hostile_drone"])
	var hunter_cannon := Laser.new()
	hunter_cannon.target_group = &"player_ship"
	hunter_cannon.cooldown = 0.2
	hunter_cannon.fire_action = &""
	hunter.add_child(hunter_cannon)
	var brain := Brain.new()
	brain.player = player
	brain.laser = hunter_cannon
	hunter.add_child(brain)
	await ticks(3)
	player.position = Vector3.ZERO
	player.linear_velocity = Vector3.ZERO
	hunter.position = Vector3(0, 0, 80)
	hunter.linear_velocity = Vector3.ZERO
	hunter.angular_velocity = Vector3.ZERO
	hunter.look_at(player.position)
	await ticks(60)
	check(hunter.position.distance_to(player.position) < 80.0, "Drone must close distance in APPROACH.")
	hunter.position = Vector3(0, 0, 40)
	hunter.linear_velocity = Vector3.ZERO
	hunter.angular_velocity = Vector3.ZERO
	hunter.look_at(player.position)
	await ticks(30)
	check(brain.state == Brain.State.ATTACK, "Drone must switch to ATTACK in range.")
	check(player.shield < 50.0, "Drone must land hits while attacking.")
	hunter.take_damage(120.0)
	await ticks(5)
	check(brain.state == Brain.State.EVADE, "Drone must EVADE after heavy damage.")
	# ── ShipState snapshot / save / restore ───────────────────────────
	var veteran := _combat_ship(Vector3(200, 0, 0))
	await ticks(3)
	veteran.take_damage(40.0)
	veteran.take_damage(30.0)
	veteran.transform = Transform3D(Basis(Quaternion(Vector3.UP, 0.9)), Vector3(10, -4, -60))
	veteran.linear_velocity = Vector3(5, 0, -9)
	var snap = ShipState.snapshot(veteran)
	veteran.repair_full()
	veteran.transform = Transform3D.IDENTITY
	veteran.linear_velocity = Vector3.ZERO
	check(is_equal_approx(veteran.hull, 100.0), "Repair must restore full hull.")
	check(snap.save_to("user://test_ship_state.json"), "ShipState must save to disk.")
	var loaded = ShipState.load_from("user://test_ship_state.json")
	check(loaded != null, "ShipState must load from disk.")
	loaded.apply_to(veteran)
	check(is_equal_approx(veteran.hull, 80.0), "Restored hull must match the snapshot.")
	check(is_equal_approx(veteran.shield, 0.0), "Restored shields must match the snapshot.")
	check(veteran.position.is_equal_approx(Vector3(10, -4, -60)), "Restored position must match.")
	var restored_angle: float = veteran.transform.basis.get_rotation_quaternion().normalized().angle_to(Quaternion(Vector3.UP, 0.9).normalized())
	check(restored_angle < 0.01, "Restored rotation must match.")
	check(veteran.linear_velocity.is_equal_approx(Vector3(5, 0, -9)), "Restored velocity must match.")
	check(ShipState.load_from("user://missing_ship_state.json") == null, "Missing saves must load as null.")
	check(ShipState.from_dict({"format_version": 999}) == null, "Future save versions must be rejected.")
	DirAccess.remove_absolute("user://test_ship_state.json")
	for body in [shooter, target, friendly, hulk, player, hunter, veteran]:
		body.queue_free()
	await process_frame


func _test_economy() -> void:
	# ── MarketService: commit together or not at all ───────────────────
	var market = Market.with_offers([&"water", &"ore"], [10, 5], [8, 28])
	var wallet := {&"credits": 100}
	var hold := {}
	check(market.buy(&"ore", 2, wallet, hold, 20) == Market.TradeResult.OK, "Affordable in-stock buy must succeed.")
	check(int(wallet[&"credits"]) == 44, "Buy must debit the wallet.")
	check(int(hold.get(&"ore", 0)) == 2, "Buy must fill the hold.")
	check(market.stock_of(&"ore") == 3, "Buy must deplete station stock.")
	var rich := {&"credits": 1000}
	var empty := {}
	check(market.buy(&"ore", 4, rich, empty, 20) == Market.TradeResult.NO_STOCK, "Oversized buys must be rejected.")
	check(rich == {&"credits": 1000} and empty.is_empty(), "Stock rejection must not touch funds or cargo.")
	check(market.buy(&"water", 20, wallet, hold, 20) == Market.TradeResult.NO_FUNDS, "Unaffordable buys must be rejected.")
	check(market.buy(&"water", 0, wallet, hold, 20) == Market.TradeResult.BAD_QUANTITY, "Non-positive quantities must be rejected.")
	check(market.buy(&"spice", 1, wallet, hold, 20) == Market.TradeResult.UNKNOWN_GOOD, "Unknown goods must be rejected.")
	check(wallet == {&"credits": 44} and hold == {&"ore": 2}, "Rejected trades must leave balances unchanged.")
	check(market.stock_of(&"ore") == 3, "Rejected trades must leave stock unchanged.")
	var big = Market.with_offers([&"water"], [100], [8])
	var tycoon := {&"credits": 1000}
	var full := {&"ore": 18}
	check(big.buy(&"water", 5, tycoon, full, 20) == Market.TradeResult.NO_SPACE, "Over-capacity buys must be rejected.")
	check(tycoon == {&"credits": 1000} and full == {&"ore": 18}, "Capacity rejection must not touch funds or cargo.")
	check(market.sell(&"ore", 1, wallet, hold) == Market.TradeResult.OK, "Selling held goods must succeed.")
	check(int(wallet[&"credits"]) == 72, "Sell must pay the wallet.")
	check(int(hold.get(&"ore", 0)) == 1, "Sell must drain the hold.")
	check(market.sell(&"ore", 5, wallet, hold) == Market.TradeResult.NO_CARGO, "Selling unheld goods must be rejected.")
	# ── MissionService: bounded instances, paid exactly once ────────────
	var board = Missions.new()
	check(board.accept(Missions.delivery_mission("d1", "ore", 6, "outer_reach", "Outer Reach", 250)), "Delivery must be accepted.")
	check(not board.accept(Missions.delivery_mission("d1", "ore", 6, "outer_reach", "Outer Reach", 250)), "Duplicate mission ids must be rejected.")
	var hauler := {&"ore": 6}
	check(board.on_dock("sector_alpha", hauler).is_empty(), "Wrong-system docking must not complete delivery.")
	check(board.on_dock("outer_reach", hauler) == ["d1"], "Right-system docking with cargo must complete delivery.")
	check(int(hauler.get(&"ore", 0)) == 0, "Delivery must consume the goods.")
	var purse := {&"credits": 0}
	check(board.claim("d1", purse) == Missions.ClaimResult.OK, "Completed missions must pay.")
	check(int(purse[&"credits"]) == 250, "Delivery reward must land in the wallet.")
	check(board.claim("d1", purse) == Missions.ClaimResult.ALREADY_CLAIMED, "Second claims must be rejected.")
	check(board.claim("missing", purse) == Missions.ClaimResult.UNKNOWN, "Unknown missions must be rejected.")
	check(board.accept(Missions.bounty_mission("b1", "Hostile drone", 2, 300)), "Bounty must be accepted.")
	check(board.claim("b1", purse) == Missions.ClaimResult.NOT_COMPLETE, "Incomplete missions must not pay.")
	check(board.on_kill().is_empty(), "First kill must not complete a two-kill bounty.")
	check(board.on_kill() == ["b1"], "Second kill must complete the bounty.")
	check(board.claim("b1", purse) == Missions.ClaimResult.OK, "Completed bounties must pay.")
	check(int(purse[&"credits"]) == 550, "Bounty reward must accumulate exactly once.")
	# ── Docking, station services, and v2 saves ─────────────────────────
	var game := preload("res://main.tscn").instantiate()
	root.add_child(game)
	await ticks(5)
	game.ship.position = Vector3(90, 5, -220)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(game.hud.dock_prompt != "", "Slow approach to the station must offer docking.")
	check(game.dock(), "Docking inside the envelope must succeed.")
	check(not game.ship.controls_enabled, "Docking must lock flight controls.")
	check(game.drone.get_node_or_null("Brain").get("player_docked") == true, "Docking must stand the drone down.")
	check(game.buy_commodity(&"water", 10) == Market.TradeResult.OK, "Station buy must succeed.")
	check(int(game.wallet[&"credits"]) == 40, "Station buy must debit credits.")
	check(int(game.cargo.get(&"water", 0)) == 10, "Station buy must fill the hold.")
	check(game.sell_commodity(&"water", 4) == Market.TradeResult.OK, "Station sell must succeed.")
	check(int(game.wallet[&"credits"]) == 72, "Station sell must pay credits.")
	game.wallet[&"credits"] = 500
	check(game.buy_upgrade("shield_booster"), "Affordable upgrade must apply.")
	check(is_equal_approx(game.ship.max_shield, 75.0), "Shield booster must raise max shields.")
	check(not game.buy_upgrade("shield_booster"), "Owned upgrades cannot be bought twice.")
	check(not game.buy_upgrade("cargo_expansion"), "Unaffordable upgrades must be rejected.")
	check(game.accept_delivery(), "Delivery mission must be accepted.")
	check(game.accept_bounty(), "Bounty mission must be accepted.")
	game.undock()
	check(game.ship.controls_enabled, "Undocking must restore controls.")
	check(game.drone.get_node_or_null("Brain").get("player_docked") == false, "Undocking must release the drone.")
	game.ship.position = Vector3.ZERO
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(not game.dock(), "Docking outside the envelope must fail.")
	game.save_ship()
	game.wallet[&"credits"] = 0
	game.cargo.clear()
	game.missions.missions.clear()
	game.load_ship()
	check(int(game.wallet[&"credits"]) == 100, "Credits must survive save/load.")
	check(game.cargo.has(&"water"), "Cargo keys must survive JSON as usable ids.")
	check(int(game.cargo.get(&"water", 0)) == 6, "Cargo quantities must survive save/load.")
	check(not game.missions.get_mission("delivery_ore").is_empty(), "Missions must survive save/load.")
	check(game.upgrades.has("shield_booster"), "Owned upgrades must survive save/load.")
	var legacy = ShipState.from_dict({"format_version": 1, "hull": 60.0, "shield": 10.0})
	check(legacy != null and is_equal_approx(legacy.hull, 60.0), "v1 saves must still load.")
	check(int(legacy.credits) == 0 and (legacy.cargo as Dictionary).is_empty(), "v1 saves must default new economy fields.")
	game.queue_free()
	await process_frame


func _test_polish() -> void:
	# ── Shield bubble + impact spark ────────────────────────────────────
	var duelist := _combat_ship()
	duelist.shield_bubble = MeshInstance3D.new()
	duelist.take_damage(5.0)
	check(duelist.shield_bubble.visible, "Hits must flash the shield bubble.")
	await ticks(30)
	check(not duelist.shield_bubble.visible, "Bubble flash must fade out.")
	duelist.shield_bubble.free()
	var gunner := _combat_ship()
	var gun := Laser.new()
	gun.target_group = &"hostile_drone"
	gunner.add_child(gun)
	var dummy := _combat_ship(Vector3(0, 0, -30), [&"hostile_drone"])
	await ticks(3)
	check(gun.fire() == Laser.FireResult.FIRED_HIT, "Setup shot must land.")
	check(gun._spark.visible, "Impacts must spark.")
	await ticks(15)
	check(not gun._spark.visible, "Impact sparks must fade.")
	duelist.queue_free()
	gunner.queue_free()
	dummy.queue_free()
	await process_frame
	# ── Procedural audio ────────────────────────────────────────────────
	var audio := Audio.new()
	root.add_child(audio)
	check(audio._sfx.size() == 5, "All five sounds must synthesize.")
	check((audio._sfx[&"laser"] as AudioStreamWAV).data.size() == int(0.12 * 22050) * 2, "Laser buffer must match its duration.")
	audio.set_throttle(1.5)
	check(is_equal_approx(audio._throttle, 1.0), "Throttle must clamp high.")
	audio.set_throttle(-1.0)
	check(is_equal_approx(audio._throttle, 0.0), "Throttle must clamp low.")
	var players_before := audio.get_child_count()
	audio.play_sfx(&"nope")
	check(audio.get_child_count() == players_before, "Unknown sounds must be ignored.")
	audio.play_sfx(&"coin")
	check(audio.get_child_count() == players_before + 1, "One-shots must spawn a player.")
	audio.queue_free()
	await process_frame
	# ── Hulls, map, explosions, landing (integration) ───────────────────
	var game := preload("res://main.tscn").instantiate()
	root.add_child(game)
	await ticks(5)
	var kids_before: int = game.get_child_count()
	game.drone.take_damage(999.0)
	check(game.get_child_count() == kids_before + 1, "Kills must spawn an explosion.")
	await ticks(45)
	check(game.get_child_count() == kids_before, "Explosions must free themselves.")
	game.wallet[&"credits"] = 1000
	check(game.buy_hull("mule"), "Affordable hull must be bought.")
	check(game.owned_hulls.has("mule") and int(game.wallet[&"credits"]) == 200, "Hull purchase must debit credits.")
	check(not game.buy_hull("mule"), "Owned hulls cannot be bought twice.")
	check(not game.buy_hull("sparrow"), "Pre-owned hulls cannot be bought twice.")
	check(not game.buy_hull("ghost"), "Unknown hulls must be rejected.")
	check(game.equip_hull("mule"), "Owned hulls must equip.")
	check(is_equal_approx(game.ship.maximum_speed, 85.0), "Mule tuning must apply.")
	check(is_equal_approx(game.ship.max_hull, 150.0), "Mule durability must apply.")
	check(game.cargo_capacity == 40, "Mule bonus must raise capacity.")
	check(game.hud.ship == game.ship, "HUD must follow the hull swap.")
	check(game.ship.get_node("Laser").fire() != Laser.FireResult.NO_SHOT, "Rewired laser must fire.")
	check(game.equip_hull("sparrow"), "Swapping back must work.")
	check(game.cargo_capacity == 20, "Capacity must lose the bonus on swap.")
	check(not game.equip_hull("ghost"), "Unknown hulls cannot equip.")
	game.open_map()
	check(game.map_open and game._map_panel.visible, "Starmap must open.")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Map must free the cursor.")
	game.select_system("outer_reach")
	game.plot_course()
	check(game.nav_route == [&"outer_reach"], "Linked plot must set one hop.")
	await ticks(2)
	check(game.hud.plot_label != "", "Plot must mark the HUD.")
	game.close_map()
	# Headless has no cursor to capture, so assert panel state, not mouse mode.
	check(not game.map_open and not game._map_panel.visible, "Closing must hide the map.")
	check(game.jump_to(&"outer_reach"), "Plotted jump must start.")
	check(game.nav_route.is_empty(), "Arrival must clear the plot.")
	await ticks(60)
	check(game.jump_to(&"sector_alpha"), "Return must work.")
	game.equip_hull("mule")
	game.save_ship()
	game.equip_hull("sparrow")
	game.load_ship()
	check(game.active_hull == &"mule", "Save must restore the active hull.")
	check(is_equal_approx(game.ship.maximum_speed, 85.0), "Restored hull tuning must apply.")
	await ticks(60)
	game.ship.position = Vector3(200, 40, -690)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(game.hud.land_prompt != "", "Beacon approach must offer landing.")
	check(game.land(), "Landing must commit the surface zone.")
	check(game.current_system == &"meridian_flats", "Landing must arrive at the flats.")
	check(game.course.gates.is_empty(), "Surface zone flies free of gates.")
	check(game.ship.position.is_equal_approx(Vector3(0, 25, 80)), "Landing arrival must place the ship.")
	await ticks(60)
	game.ship.position = Vector3(0, 5, 30)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(game.dock(), "Spaceport docking must work.")
	check(game.buy_commodity(&"ore", 2) == Market.TradeResult.OK, "Surface market must trade.")
	game.undock()
	await ticks(60)
	check(game.jump_to(&"sector_alpha"), "Surface return gate must work.")
	check(game.current_system == &"sector_alpha", "Return must restore orbit.")
	game.queue_free()
	await process_frame


func _test_systems() -> void:
	# ── Drift, restock, generator, dialogue (unit) ───────────────────────
	var m = Market.with_offers([&"ore"], [20], [100])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	m.stock[&"ore"] = 4
	m.restock(rng)
	check(int(m.stock[&"ore"]) > 4 and int(m.stock[&"ore"]) <= 20, "Restock must replenish toward max.")
	m.drift(rng, 0.1)
	check(int(m.prices[&"ore"]) >= 90 and int(m.prices[&"ore"]) <= 110, "Drift must stay in band.")
	var links := [&"outer_reach", &"meridian_flats"]
	var names := {"outer_reach": "OUTER REACH", "meridian_flats": "MERIDIAN FLATS"}
	var goods := ["water", "ore", "medicine"]
	var bases := {"water": 10.0, "ore": 30.0, "medicine": 70.0}
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var offers = Missions.generate(r1, links, names, goods, bases)
	check(offers.size() == 2, "Generator must offer one delivery and one bounty.")
	var gen_d: Dictionary = offers[0]
	check(int(gen_d["reward"]) == 50 + int(round(int(gen_d["qty"]) * float(bases[gen_d["commodity"]]) * 1.5)), "Delivery reward must scale with quantity and base price.")
	check(str(gen_d["dest"]) == "outer_reach" or str(gen_d["dest"]) == "meridian_flats", "Delivery must target a linked system.")
	var gen_b: Dictionary = offers[1]
	check(int(gen_b["reward"]) == 120 * int(gen_b["qty"]) + 50, "Bounty reward must scale with kills.")
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	check(JSON.stringify(Missions.generate(r2, links, names, goods, bases)) == JSON.stringify(offers), "Generator must be deterministic per seed.")
	check(Missions.generate(rng, [], names, goods, bases).is_empty(), "Generator needs links.")
	var svc = Dialogue.new()
	svc.add_definition("t", Dialogue.make_definition("hello", [
		{"id": "hello", "speaker": "T", "text": "Ore goes for {ore_price}cr here.", "choices": [
			{"text": "Rumor?", "to": "rumor", "do": ""},
			{"text": "Work?", "to": "job", "do": "accept:bounty_drones"}]},
		{"id": "rumor", "speaker": "T", "text": "Watch the skies.", "choices": []},
		{"id": "job", "speaker": "T", "text": "Done deal.", "choices": []},
	]))
	svc.context = {"ore_price": 28}
	check(str(svc.start("t").get("text", "")).contains("28cr"), "Dialogue must substitute live context.")
	check(svc.start("missing").is_empty(), "Unknown trees must start empty.")
	svc.start("t")
	var picked: Dictionary = svc.choose(0)
	check(str(picked.get("effect", "")) == "", "Rumor choices carry no effect.")
	check(str((picked["node"] as Dictionary).get("id", "")) == "rumor", "Choices must follow their goto.")
	svc.start("t")
	check(str(svc.choose(1).get("effect", "")) == "accept:bounty_drones", "Work choices must carry their effect.")
	svc.start("t")
	check(str(svc.choose(9).get("effect", "")) == "" and str(svc.current().get("id", "")) == "hello", "Bad choice indexes must hold position.")
	# ── Customs, contracts, contacts, v4 saves (integration) ────────────
	var game := preload("res://main.tscn").instantiate()
	root.add_child(game)
	await ticks(5)
	game.cargo[&"spike"] = 5
	game.wallet[&"credits"] = 1000
	game.ship.position = Vector3(90, 5, -220)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(game.dock(), "Docking with contraband must still succeed.")
	check(not game.cargo.has(&"spike"), "Customs must confiscate banned goods.")
	check(int(game.wallet[&"credits"]) == 650, "Customs fine must debit the wallet.")
	game._show_station_tab(&"contacts")
	var rows: int = game._contacts_tab.get_child_count()
	check(rows == 3, "Alpha must list three contacts.")
	game._open_dialogue("rook")
	game._choose_dialogue(1)
	check(str(game.dialogue.current().get("id", "")) == "rumor", "Contact rumors must advance the tree.")
	check(str(game.dialogue.current().get("text", "")).contains("cr"), "Rumors must quote live prices.")
	game._open_dialogue("sable")
	game._choose_dialogue(0)
	check(not game.missions.get_mission("delivery_ore").is_empty(), "Dialogue missions must be accepted.")
	check(game.mission_offers.size() == 2, "Docking must seed the contracts board.")
	var offer_id := str(game.mission_offers[0].get("id", ""))
	check(game.accept_offer(offer_id), "Board offers must be accepted.")
	check(game.mission_offers.size() == 1, "Accepted offers must leave the board.")
	check(not game.accept_offer(offer_id), "Accepted offers cannot be taken twice.")
	game.mission_offers.clear()
	for i in 4:
		game.missions.missions.append({"id": "gen_x_%d" % i, "kind": "bounty", "qty": 1, "kills": 0, "reward": 1, "complete": false, "claimed": false})
	game._refresh_contracts()
	check(game.mission_offers.is_empty(), "Full boards must not generate more work.")
	for i in range(game.missions.missions.size() - 1, -1, -1):
		if str(game.missions.missions[i].get("id", "")).begins_with("gen_x_"):
			game.missions.missions.remove_at(i)
	game._refresh_contracts()
	check(game.mission_offers.size() == 2, "Cleared boards must regenerate.")
	game.undock()
	game.wallet[&"credits"] = 10000
	check(game.buy_commodity(&"water", 10) == Market.TradeResult.OK, "Setup buy must succeed.")
	check(game.jump_to(&"outer_reach"), "Travel must start.")
	await ticks(60)
	check(game.jump_to(&"sector_alpha"), "Return must start.")
	await ticks(60)
	check(int(game.markets[&"sector_alpha"].stock_of(&"water")) > 20, "Travel must restock depleted shelves.")
	var drifted: int = game.markets[&"sector_alpha"].quote(&"water")
	check(drifted >= 6 and drifted <= 10, "Travel must drift prices in band.")
	game.save_ship()
	game.markets[&"sector_alpha"].prices[&"water"] = 999
	game.mission_offers.clear()
	game.load_ship()
	check(int(game.markets[&"sector_alpha"].quote(&"water")) == drifted, "Market state must survive save/load.")
	check(game.mission_offers.size() == 2, "Board offers must survive save/load.")
	game.queue_free()
	await process_frame


func _test_factions() -> void:
	# ── Favor multipliers (unit) ────────────────────────────────────────
	var mm = Market.with_offers([&"water"], [10], [100])
	var w := {&"credits": 1000}
	var h := {}
	check(mm.buy(&"water", 1, w, h, 20, 0.9) == Market.TradeResult.OK, "Discounted buys must succeed.")
	check(w == {&"credits": 910}, "Favor must cut buy cost.")
	check(mm.sell(&"water", 1, w, h, 1.1) == Market.TradeResult.OK, "Favored sells must succeed.")
	check(w == {&"credits": 1020}, "Favor must raise sell payout.")
	# ── Standing flow, chains, blind eye, insurance (integration) ───────
	var game := preload("res://main.tscn").instantiate()
	root.add_child(game)
	await ticks(5)
	game.wallet[&"credits"] = 1000
	game.add_standing(&"meridian", 50)
	check(game.buy_commodity(&"water", 10) == Market.TradeResult.OK, "Standing discount must apply.")
	check(int(game.wallet[&"credits"]) == 930, "Discount math must hold.")
	check(game.sell_commodity(&"water", 10) == Market.TradeResult.OK, "Standing bonus must apply.")
	check(int(game.wallet[&"credits"]) == 1020, "Bonus math must hold.")
	game.add_standing(&"meridian", 500)
	check(int(game.standings[&"meridian"]) == 100, "Standing must clamp.")
	game.wallet[&"credits"] = 100
	check(game.buy_commodity(&"water", 1) == Market.TradeResult.OK, "Clamped favor must still trade.")
	check(int(game.wallet[&"credits"]) == 94, "Favor floor must hold.")
	check(game.accept_delivery(), "Setup delivery must be accepted.")
	game.cargo[&"ore"] = 6
	check(game.jump_to(&"outer_reach"), "Travel must start.")
	await ticks(60)
	game.ship.position = Vector3(-90, -5, -220)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(game.dock(), "Setup dock must succeed.")
	check(game.claim_mission("delivery_ore") == Missions.ClaimResult.OK, "Delivery must pay.")
	check(int(game.standings[&"reach"]) == 8, "Delivery claims must raise destination standing.")
	check(not game.missions.get_mission("ore_route_ambush").is_empty(), "Claiming must pin the follow-up contract.")
	game.missions.on_kill()
	game.missions.on_kill()
	check(game.claim_mission("ore_route_ambush") == Missions.ClaimResult.OK, "Follow-up bounty must pay.")
	check(int(game.standings[&"reach"]) == 20, "Bounty claims must raise local standing.")
	check(Missions.follow_up("ore_route_ambush").is_empty(), "Chains must terminate.")
	game.undock()
	game.cargo[&"medicine"] = 5
	await ticks(60)
	check(game.jump_to(&"sector_alpha"), "Return must start.")
	await ticks(60)
	check(int(game.cargo.get(&"medicine", 0)) == 4, "Travel must spoil one medi-gel.")
	game.wallet[&"credits"] = 1000
	check(game.buy_blind_eye(), "Blind eye must be bought.")
	check(not game.buy_blind_eye(), "Blind eye cannot stack.")
	game.cargo[&"spike"] = 5
	game.ship.position = Vector3(90, 5, -220)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(game.dock(), "Smuggler dock must succeed.")
	check(int(game.cargo.get(&"spike", 0)) == 5, "Blind eye must beat customs.")
	check(game.customs_pass == false, "Blind eye must be single-use.")
	check(int(game.wallet[&"credits"]) == 700, "Blind eye must cost its price.")
	check(game.sell_commodity(&"spike", 5) == Market.TradeResult.OK, "Fenced spike must sell at the Alpha quote.")
	game.standings[&"meridian"] = 0
	var cash_before_bust := int(game.wallet[&"credits"])
	game.undock()
	game.cargo[&"spike"] = 3
	game.ship.position = Vector3(90, 5, -220)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(game.dock(), "Second dock must succeed.")
	check(not game.cargo.has(&"spike"), "Customs must seize without cover.")
	check(int(game.wallet[&"credits"]) == cash_before_bust - 250, "Customs fine must debit.")
	check(int(game.standings[&"meridian"]) == -15, "Busts must hurt local standing.")
	game._open_dialogue("vex")
	game.wallet[&"credits"] = 0
	game._choose_dialogue(0)
	check(str(game.dialogue.current().get("id", "")) == "hello", "Broke fence deals must hold position.")
	game.wallet[&"credits"] = 1000
	game._choose_dialogue(0)
	check(game.customs_pass, "Funded fence deals must set the flag.")
	check(str(game.dialogue.current().get("id", "")) == "sold", "Paid deals must advance the tree.")
	game.undock()
	game.cargo[&"water"] = 5
	game.ship.take_damage(9999.0)
	check(game.cargo.is_empty(), "Wrecks must lose uninsured cargo.")
	game.ship.repair_full()
	check(game.buy_upgrade("insurance"), "Insurance must be bought.")
	game.cargo[&"water"] = 5
	game.ship.take_damage(9999.0)
	check(int(game.cargo.get(&"water", 0)) == 5, "Insurance must cover the cargo.")
	check(not game.upgrades.has("insurance"), "Policies must be single-wreck.")
	game.save_ship()
	game.standings[&"reach"] = 0
	game.customs_pass = false
	game.load_ship()
	check(int(game.standings[&"reach"]) == 20, "Standings must survive save/load.")
	check(int(game.standings[&"meridian"]) == -15, "Negative standings must survive save/load.")
	check(game.customs_pass, "Blind-eye flags must survive save/load.")
	check(game._system_brief(&"sector_alpha").contains("Standing"), "Starmap must show standing.")
	game.queue_free()
	await process_frame


func _test_bethesda() -> void:
	var game := preload("res://main.tscn").instantiate()
	root.add_child(game)
	await ticks(5)
	# ── Skills ────────────────────────────────────────────────────────
	check(game.skill_rank("piloting") == 0, "Skills start at Novice.")
	check(game.gain_xp("trade", 60), "60 trade XP must rank up.")
	check(game.skill_rank("trade") == 1 and game.skill_title("trade") == "Apprentice", "Rank titles must advance.")
	check(not game.gain_xp("trade", 10), "Same-rank XP must not report rank-up.")
	check(not game.gain_xp("alchemy", 50), "Unknown skills must be rejected.")
	game.gain_xp("piloting", 60)
	check(is_equal_approx(game.ship.maximum_speed, 124.8), "Piloting bonus must apply.")
	game.cargo[&"medicine"] = 1
	game.wallet[&"credits"] = 0
	check(game.sell_commodity(&"medicine", 1) == Market.TradeResult.OK, "Setup sale must succeed.")
	check(int(game.wallet[&"credits"]) == 97, "Mercantile rank must raise sell prices.")
	# ── Persuasion, disposition, bribes ────────────────────────────────
	check(is_equal_approx(game.persuade_chance(30, "rook"), 20.0), "Base chance math must hold.")
	game.social_rigged = 0.0
	game._open_dialogue("jeb")
	game._choose_dialogue(1)
	check(str(game.dialogue.current().get("id", "")) == "flattered", "Rigged success must advance.")
	check(game.disp_of("jeb") == 60, "Success must raise disposition.")
	game.social_rigged = 99.0
	game._open_dialogue("jeb")
	game._choose_dialogue(1)
	check(str(game.dialogue.current().get("id", "")) == "bristled", "Rigged failure must redirect.")
	check(game.disp_of("jeb") == 55, "Failure must lower disposition.")
	game.wallet[&"credits"] = 500
	game._open_dialogue("sable")
	game._choose_dialogue(3)
	check(int(game.wallet[&"credits"]) == 400, "Bribes must cost.")
	check(game.disp_of("sable") == 65, "Bribes must raise disposition.")
	check(str(game.dialogue.current().get("id", "")) == "hello", "Bribes must hold the node.")
	game.wallet[&"credits"] = 0
	game._choose_dialogue(3)
	check(int(game.wallet[&"credits"]) == 0, "Broke bribes must hold funds and position.")
	check(game.disp_of("sable") == 65, "Broke bribes must not move disposition.")
	# ── Pardon, freebie, discount, friend price ────────────────────────
	game.heat[&"meridian"] = 40
	game.social_rigged = 0.0
	game._open_dialogue("rook")
	game._choose_dialogue(2)
	check(int(game.heat[&"meridian"]) == 20, "Pardons must cut heat.")
	check(str(game.dialogue.current().get("id", "")) == "pardon_ok", "Pardons must advance.")
	game.social_rigged = 0.0
	game._open_dialogue("sable")
	game._choose_dialogue(2)
	check(int(game.cargo.get(&"water", 0)) == 2, "Freebies must grant goods.")
	check(str(game.dialogue.current().get("id", "")) == "treat_ok", "Freebies must advance.")
	game.disposition["sable"] = 50
	game.social_rigged = 0.0
	game._open_dialogue("ilsa")
	game._choose_dialogue(2)
	check(float(game.discounts.get(&"medicine", 0.0)) == 0.8, "Deals must token a discount.")
	game.wallet[&"credits"] = 1000
	check(game.buy_commodity(&"medicine", 1) == Market.TradeResult.OK, "Discounted buys must succeed.")
	check(int(game.wallet[&"credits"]) == 924, "Discount token must cut the price.")
	check(not game.discounts.has(&"medicine"), "Discounts must be single-use.")
	game.social_rigged = 0.0
	game._open_dialogue("vex")
	game._choose_dialogue(2)
	check(game.blind_discount, "Friend prices must flag the discount.")
	game.wallet[&"credits"] = 1000
	check(game.buy_blind_eye(), "Discounted blind eyes must sell.")
	check(int(game.wallet[&"credits"]) == 800, "Friend price must hold.")
	# ── Radiant contracts from dialogue ───────────────────────────────
	game._open_dialogue("rook")
	var board_before: int = game.mission_offers.size()
	game._choose_dialogue(3)
	check(game.mission_offers.size() == board_before + 1, "Contract talk must pin an offer.")
	for i in 3:
		game.mission_offers.append(game.mission_offers[0].duplicate())
	game._open_dialogue("rook")
	game._choose_dialogue(3)
	check(game.mission_offers.size() == 4, "Full boards must refuse contracts.")
	# ── Heat, reparations, hunters ─────────────────────────────────────
	game.heat[&"meridian"] = 60
	game.wallet[&"credits"] = 500
	check(game.pay_reparations(), "Reparations must clear heat.")
	check(int(game.heat[&"meridian"]) == 10, "Reparations must relieve 50.")
	check(int(game.wallet[&"credits"]) == 350, "Reparations must cost.")
	check(game.pay_reparations(), "Remainders must clear too.")
	check(not game.pay_reparations(), "Clean records need no payment.")
	game.wallet[&"credits"] = 0
	game.heat[&"meridian"] = 30
	check(not game.pay_reparations(), "Broke reparations must fail.")
	check(int(game.heat[&"meridian"]) == 30, "Failed payments must hold heat.")
	check(game.rank_title(60) == "Ally", "Ally threshold must hold.")
	check(game.rank_title(25) == "Friend", "Friend threshold must hold.")
	check(game.rank_title(0) == "Neutral", "Neutral band must hold.")
	check(game.rank_title(-25) == "Hostile", "Hostile threshold must hold.")
	check(game.rank_title(-60) == "Nemesis", "Nemesis floor must hold.")
	game.standings[&"reach"] = -50
	check(game.jump_to(&"outer_reach"), "Travel must start.")
	check(is_instance_valid(game.hunter), "Low standing must send a hunter.")
	check(game.hunter.is_in_group("hostile_drone"), "Hunters must be hostile.")
	check(is_equal_approx(game.hunter.max_hull, 80.0), "Hunters must be tougher.")
	check(game.hud.hunter == game.hunter, "HUD must track the hunter.")
	await ticks(60)
	game.hunter.take_damage(999.0)
	check(game.hunter == null, "Dead hunters must clear.")
	check(int(game.heat[&"reach"]) == 10, "Hunter kills must raise heat.")
	# ── Repairs, shield top-up, terminal, v6 saves ────────────────────
	game.ship.set("shield", 0.0)
	game.ship.take_damage(40.0)
	check(game.repair_cost() == 160, "Repair cost must scale with damage.")
	game.wallet[&"credits"] = 500
	check(game.repair_ship(), "Affordable repairs must apply.")
	check(is_equal_approx(game.ship.hull, 100.0), "Repairs must restore hull.")
	check(int(game.wallet[&"credits"]) == 340, "Repairs must debit.")
	check(not game.repair_ship(), "Intact hulls need no repair.")
	game.ship.set("shield", 0.0)
	game.ship.take_damage(40.0)
	game.wallet[&"credits"] = 0
	check(not game.repair_ship(), "Broke repairs must fail.")
	check(is_equal_approx(game.ship.hull, 60.0), "Failed repairs must hold hull.")
	game.standings[&"reach"] = 60
	game.wallet[&"credits"] = 200
	check(game.repair_cost() == 120, "Allies must get repair discounts.")
	check(game.repair_ship(), "Discounted repairs must apply.")
	check(int(game.wallet[&"credits"]) == 80, "Discount math must hold.")
	game.ship.take_damage(30.0)
	game.ship.position = Vector3(-90, -5, -220)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(game.dock(), "Setup dock must succeed.")
	check(is_equal_approx(game.ship.shield, game.ship.max_shield), "Docking must top up shields.")
	game._show_station_tab(&"terminal")
	check(game._lore_tab.get_child_count() == 4, "Terminal must carry four entries.")
	game.heat[&"flats"] = 33
	var trade_xp: int = int(game.skills["trade"])
	var sable_disp: int = game.disp_of("sable")
	game.save_ship()
	game.heat[&"flats"] = 0
	game.skills["trade"] = 0
	game.disposition.clear()
	game.load_ship()
	check(int(game.heat[&"flats"]) == 33, "Heat must survive save/load.")
	check(int(game.skills["trade"]) == trade_xp, "Skill XP must survive save/load.")
	check(game.disp_of("sable") == sable_disp, "Disposition must survive save/load.")
	game.queue_free()
	await process_frame


func _test_routes() -> void:
	var game := preload("res://main.tscn").instantiate()
	root.add_child(game)
	await ticks(5)
	# ── BFS over the jump network ───────────────────────────────────────
	check(game.find_route(&"sector_alpha", &"cinder_docks") == [&"sector_alpha", &"outer_reach", &"cinder_docks"], "Alpha must route through the Reach.")
	check(game.find_route(&"cinder_docks", &"meridian_flats").is_empty(), "Surface sites need beacons, not jumps.")
	check(game.systems[&"sector_alpha"].landing_target == &"meridian_flats", "Alpha beacon must lead to the flats.")
	check(game.find_route(&"sector_alpha", &"sector_alpha").is_empty(), "Self routes must be empty.")
	check(game.find_route(&"sector_alpha", &"nowhere").is_empty(), "Unknown destinations must not route.")
	# ── Multi-hop plot, advance, arrive ─────────────────────────────────
	game.open_map()
	game.select_system("cinder_docks")
	game.plot_course()
	check(game.nav_route == [&"outer_reach", &"cinder_docks"], "Plotting must span both hops.")
	await ticks(2)
	check(str(game.hud.plot_label).contains("CINDER"), "Plot marker must name the final stop.")
	game.close_map()
	check(game.jump_to(&"outer_reach"), "First hop must start.")
	await ticks(60)
	check(game.nav_route == [&"cinder_docks"], "Arrival must advance the route.")
	game.ship.position = Vector3(120, 0, -390)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(str(game.hud.jump_prompt).contains("CINDER"), "Second ring must offer Cinder.")
	game._try_jump_from_gate()
	check(game.current_system == &"cinder_docks", "Ring jump must commit Cinder.")
	check(game.nav_route.is_empty(), "Final arrival must clear the route.")
	await ticks(60)
	# ── Cinder spaceport: Combine faction, market, contact ─────────────
	game.ship.position = Vector3(0, 5, 30)
	game.ship.linear_velocity = Vector3.ZERO
	await ticks(2)
	check(game.dock(), "Cinder dock must succeed.")
	game.wallet[&"credits"] = 500
	var water_q: int = game.markets[&"cinder_docks"].quote(&"water")
	check(game.buy_commodity(&"water", 1) == Market.TradeResult.OK, "Cinder market must trade.")
	check(int(game.wallet[&"credits"]) == 500 - water_q, "Cinder prices must apply.")
	game.cargo[&"spike"] = 2
	var spike_q: int = game.markets[&"cinder_docks"].quote(&"spike")
	var cash_before: int = int(game.wallet[&"credits"])
	check(game.sell_commodity(&"spike", 2) == Market.TradeResult.OK, "Cinder must fence spike.")
	check(int(game.wallet[&"credits"]) == cash_before + 2 * spike_q, "Fence payout must hold.")
	game._show_station_tab(&"contacts")
	check(game._contacts_tab.get_child_count() == 1, "Cinder must list one contact.")
	game.social_rigged = 0.0
	game._open_dialogue("kass")
	game._choose_dialogue(1)
	check(str(game.dialogue.current().get("id", "")) == "praised", "Kass must respond to admiration.")
	check(game.disp_of("kass") == 60, "Admiration must raise disposition.")
	check(game.accept_bounty(), "Setup bounty must be accepted.")
	game.missions.on_kill()
	game.missions.on_kill()
	var purse_before: int = int(game.wallet[&"credits"])
	check(game.claim_mission("bounty_drones") == Missions.ClaimResult.OK, "Cinder bounty must pay.")
	check(int(game.wallet[&"credits"]) == purse_before + 300, "Bounty payout must hold.")
	check(int(game.standings[&"cinder"]) == 12, "Claims must raise Combine standing.")
	game.undock()
	game.save_ship()
	await ticks(60)
	check(game.jump_to(&"outer_reach"), "Return hop must start.")
	await ticks(60)
	game.load_ship()
	check(game.current_system == &"cinder_docks", "Loading a Cinder save must restore Cinder.")
	check(int(game.standings[&"cinder"]) == 12, "Combine standing must survive save/load.")
	game.queue_free()
	await process_frame


func _test_sandbox_pause() -> void:
	var game := preload("res://main.tscn").instantiate()
	root.add_child(game)
	await ticks(3)
	game.ship.thrust_command = Vector3.FORWARD
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and game._pause_panel.visible, "Losing focus must pause and show the menu.")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause must release the cursor.")
	var pose: Transform3D = game.ship.transform
	await ticks(5)
	check(game.ship.transform.is_equal_approx(pose), "Pause menu must hold the ship still.")
	game._restart()
	await ticks(3)
	check(not paused and not game._pause_panel.visible, "Restart button must resume and close the menu.")
	check(game.course.next_gate == 0, "Restart button must reset the course.")
	game.queue_free()
	await process_frame
