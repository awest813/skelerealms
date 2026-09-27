extends SceneTree
const Ship = preload("res://ship_controller.gd")
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
	print("FLIGHT CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)

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
