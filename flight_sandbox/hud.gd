extends Control
var ship: RigidBody3D
var drone: RigidBody3D
var hunter: RigidBody3D
var course: RefCounted
var camera: Camera3D
var paused := false
var kills := 0
var system_name := "TRAINING SECTOR"
var system_sub := "LOCAL SPACE"
var jump_prompt := ""
var dock_prompt := ""
var land_prompt := ""
var travel_active := false
var credits := 0
var cargo_used := 0
var cargo_capacity := 20
var mission_text := ""
var plot_label := ""
var plot_pos := Vector3.ZERO
var _flash := 0.0
var _notice := ""
var _notice_left := 0.0

func flash_damage(_amount: float) -> void:
	_flash = 1.0

func notice(text: String) -> void:
	_notice = text
	_notice_left = 3.0
var _font: Font
var _background: StyleBoxFlat
const CYAN := Color("65dacf")
const MUTED := Color("8ba4bb")
const AMBER := Color("e8b16b")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_background = StyleBoxFlat.new()
	_background.bg_color = Color(0.02, 0.05, 0.09, 0.88)
	_background.set_corner_radius_all(5)

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice = ""
	queue_redraw()

func _text(at: Vector2, text: String, color := Color("d4e1ed"), font_size := 16) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _panel(rect: Rect2, accent := CYAN) -> void:
	draw_style_box(_background, rect)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), accent, 2)

func _draw() -> void:
	if not is_instance_valid(ship):
		return
	var scale_factor := minf(size.x / 1280.0, size.y / 800.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * scale_factor)
	var viewport_size := size / scale_factor
	var w := viewport_size.x
	var h := viewport_size.y
	_panel(Rect2(28, 28, 322, 95))
	_text(Vector2(46, 55), "SKELEREALMS  /  FLIGHT LAB", CYAN, 14)
	_text(Vector2(46, 85), "Flight proficiency course", Color.WHITE, 23)
	_text(Vector2(46, 109), "%s  •  %s" % [system_name, system_sub], MUTED, 12)
	_panel(Rect2(w - 276, 28, 248, 330))
	var speed := ship.linear_velocity.length()
	var shield_frac := clampf(ship.shield / maxf(ship.max_shield, 0.01), 0.0, 1.0)
	var hull_frac := clampf(ship.hull / maxf(ship.max_hull, 0.01), 0.0, 1.0)
	_text(Vector2(w - 256, 53), "RELATIVE VELOCITY", CYAN, 12)
	_text(Vector2(w - 256, 93), "%05.1f" % speed, Color.WHITE, 35)
	_text(Vector2(w - 140, 93), "m/s", MUTED, 17)
	draw_rect(Rect2(w - 256, 109, 206, 3), Color("284052"))
	draw_rect(Rect2(w - 256, 109, 206 * clampf(speed / ship.maximum_speed, 0, 1), 3), CYAN)
	_text(Vector2(w - 256, 137), "ASSIST  " + ("ON" if ship.assist_enabled else "OFF / DRIFT"), CYAN if ship.assist_enabled else AMBER, 14)
	_text(Vector2(w - 256, 160), "STOPPING DISTANCE   %03.0f m" % (speed * speed / (2 * maxf(ship.brake_acceleration, 0.01))), MUTED, 12)
	_text(Vector2(w - 256, 185), "ZONE  %04.0f / %04.0f m" % [ship.position.length(), ship.zone_radius], MUTED, 12)
	var shield_color := CYAN if ship.shield > 0.0 else AMBER
	_text(Vector2(w - 256, 210), "SHIELD  %03.0f / %03.0f" % [ship.shield, ship.max_shield], shield_color, 14)
	draw_rect(Rect2(w - 256, 218, 206, 5), Color("284052"))
	draw_rect(Rect2(w - 256, 218, 206 * shield_frac, 5), shield_color)
	var hull_color := Color.WHITE if hull_frac > 0.3 else Color("e05a4e")
	_text(Vector2(w - 256, 243), "HULL  %03.0f / %03.0f" % [ship.hull, ship.max_hull], hull_color, 14)
	draw_rect(Rect2(w - 256, 251, 206, 5), Color("284052"))
	draw_rect(Rect2(w - 256, 251, 206 * hull_frac, 5), hull_color)
	_text(Vector2(w - 256, 276), "KILLS  %d" % kills, AMBER, 14)
	_text(Vector2(w - 256, 298), "CREDITS  %d" % credits, Color("9fe6a0"), 14)
	_text(Vector2(w - 256, 320), "CARGO  %d / %d" % [cargo_used, cargo_capacity], MUTED, 13)
	if not mission_text.is_empty():
		_text(Vector2(w - 256, 342), mission_text, AMBER, 12)

	if camera:
		var aim := camera.unproject_position(ship.global_position - ship.global_basis.z * 100) / scale_factor
		draw_arc(aim, 7, 0, TAU, 24, Color(0.4, 0.8, 0.8, 0.75), 1)
		draw_line(aim - Vector2(16, 0), aim - Vector2(10, 0), CYAN)
		draw_line(aim + Vector2(10, 0), aim + Vector2(16, 0), CYAN)
		if course and not course.gates.is_empty() and not course.finished:
			_draw_guidance(viewport_size, scale_factor)
		_mark_contact(drone, "HOSTILE", Color("e05a4e"), viewport_size, scale_factor)
		_mark_contact(hunter, "HUNTER", AMBER, viewport_size, scale_factor)
		_draw_plot(viewport_size, scale_factor)

	_panel(Rect2(28, h - 208, 330, 91), Color("437a85"))
	if course and not course.gates.is_empty():
		var title := "COURSE COMPLETE" if course.finished else "NEXT  /  GATE %02d" % (course.next_gate + 1)
		_text(Vector2(46, h - 182), title, CYAN, 14)
		_text(Vector2(46, h - 154), "%d / %d cleared     %05.1f s" % [course.next_gate, course.gates.size(), course.elapsed], Color.WHITE, 20)
		_text(Vector2(46, h - 132), "Press R to fly again" if course.finished else "Fly through each gate in order", MUTED, 13)
	_panel(Rect2(28, h - 95, w - 56, 67), Color("2b5262"))
	_text(Vector2(46, h - 69), "W S  Thrust    A D  Strafe    SPACE CTRL  Vertical    Q E  Roll    MOUSE / ARROWS  Steer    LMB  Fire", Color.WHITE, 14)
	_text(Vector2(46, h - 45), "SHIFT  Brake    F  Assist    R  Restart    J  Jump    X  Dock    L  Land    M  Map    ESC  Pause", MUTED, 14)
	if ship.destroyed_flag:
		_text(Vector2(w / 2 - 150, h - 133), "SHIP LOST  —  PRESS R", Color("e05a4e"), 20)
	elif travel_active:
		_text(Vector2(w / 2 - 60, h - 133), "JUMPING", CYAN, 20)
	elif not _notice.is_empty():
		_text(Vector2(w / 2 - 130, h - 133), _notice.to_upper(), AMBER, 17)
	elif not dock_prompt.is_empty():
		_text(Vector2(w / 2 - 150, h - 133), dock_prompt, Color("9fe6a0"), 17)
	elif not land_prompt.is_empty():
		_text(Vector2(w / 2 - 150, h - 133), land_prompt, Color("e8b16b"), 17)
	elif not jump_prompt.is_empty():
		_text(Vector2(w / 2 - 150, h - 133), jump_prompt, CYAN, 17)
	if ship.brake_command:
		_text(Vector2(w / 2 - 40, h - 133), "BRAKING", CYAN, 17)
	elif ship.position.length() > ship.zone_radius * 0.85:
		_text(Vector2(w / 2 - 145, h - 133), "ZONE LIMIT — TURN BACK", AMBER, 17)
	if ship.boundary_resets > 0:
		_text(Vector2(46, 149), "Returned to course start: zone limit", AMBER, 13)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.8, 0.1, 0.1, _flash * 0.22))
	if travel_active:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.7, 0.95, 1.0, 0.18))
	if paused:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.01, 0.02, 0.04, 0.8))

func _draw_guidance(viewport_size: Vector2, scale_factor: float) -> void:
	var target: Vector3 = course.gates[course.next_gate]
	var center := viewport_size * 0.5
	var behind := camera.is_position_behind(target)
	var point := camera.unproject_position(target) / scale_factor if not behind else center
	var safe := Rect2(Vector2(90, 230), viewport_size - Vector2(180, 480))
	if not behind and safe.has_point(point):
		for x in [-1, 1]:
			for y in [-1, 1]:
				var corner := point + Vector2(x, y) * 22
				draw_line(corner, corner - Vector2(x * 9, 0), CYAN, 2)
				draw_line(corner, corner - Vector2(0, y * 9), CYAN, 2)
		_text(point + Vector2(-23, 47), "%03.0f m" % ship.position.distance_to(target), CYAN, 14)
	else:
		var local := camera.to_local(target)
		var direction := Vector2(local.x, -local.y).normalized() if behind else (point - center).normalized()
		if direction.is_zero_approx():
			direction = Vector2.DOWN
		var arrow := center + direction * minf(viewport_size.x * 0.3, viewport_size.y * 0.23)
		var tangent := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([arrow + direction * 12, arrow - direction * 8 + tangent * 7, arrow - direction * 8 - tangent * 7]), AMBER)
		_text(arrow + Vector2(-48, 30), "NEXT GATE", AMBER, 12)

func _draw_plot(viewport_size: Vector2, scale_factor: float) -> void:
	if plot_label.is_empty():
		return
	var center := viewport_size * 0.5
	var behind := camera.is_position_behind(plot_pos)
	var point := camera.unproject_position(plot_pos) / scale_factor if not behind else center
	var safe := Rect2(Vector2(90, 230), viewport_size - Vector2(180, 480))
	if not behind and safe.has_point(point):
		var corners := PackedVector2Array([
			point + Vector2(-11, 0), point + Vector2(0, -16),
			point + Vector2(11, 0), point + Vector2(0, 16),
			point + Vector2(-11, 0),
		])
		draw_polyline(corners, CYAN, 2)
		_text(point + Vector2(-48, 38), plot_label, CYAN, 13)
	else:
		var local: Vector3 = camera.to_local(plot_pos)
		var direction := Vector2(local.x, -local.y).normalized() if behind else (point - center).normalized()
		if direction.is_zero_approx():
			direction = Vector2.DOWN
		var arrow := center + direction * minf(viewport_size.x * 0.3, viewport_size.y * 0.23)
		var tangent := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([arrow + direction * 12, arrow - direction * 8 + tangent * 7, arrow - direction * 8 - tangent * 7]), CYAN)
		_text(arrow + Vector2(-48, 30), plot_label, CYAN, 12)


func _mark_contact(body: RigidBody3D, label: String, color: Color, viewport_size: Vector2, scale_factor: float) -> void:
	if not is_instance_valid(body) or not body.visible or body.destroyed_flag:
		return
	var target: Vector3 = body.global_position
	var center := viewport_size * 0.5
	var behind := camera.is_position_behind(target)
	var point := camera.unproject_position(target) / scale_factor if not behind else center
	var safe := Rect2(Vector2(90, 230), viewport_size - Vector2(180, 480))
	if not behind and safe.has_point(point):
		var corners := PackedVector2Array([
			point + Vector2(0, -13), point + Vector2(13, 0),
			point + Vector2(0, 13), point + Vector2(-13, 0),
			point + Vector2(0, -13),
		])
		draw_polyline(corners, color, 2)
		_text(point + Vector2(-42, 34), "%s %03.0f m" % [label, ship.position.distance_to(target)], color, 13)
	else:
		var local: Vector3 = camera.to_local(target)
		var direction := Vector2(local.x, -local.y).normalized() if behind else (point - center).normalized()
		if direction.is_zero_approx():
			direction = Vector2.DOWN
		var arrow := center + direction * minf(viewport_size.x * 0.3, viewport_size.y * 0.23)
		var tangent := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([arrow + direction * 12, arrow - direction * 8 + tangent * 7, arrow - direction * 8 - tangent * 7]), color)
		_text(arrow + Vector2(-40, 30), label, color, 12)
