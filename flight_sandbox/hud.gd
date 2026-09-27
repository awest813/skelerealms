extends Control
var ship: RigidBody3D
var course: RefCounted
var camera: Camera3D
var paused := false
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

func _process(_delta: float) -> void:
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
	_text(Vector2(46, 109), "TRAINING SECTOR  •  LOCAL SPACE", MUTED, 12)
	_panel(Rect2(w - 276, 28, 248, 178))
	var speed := ship.linear_velocity.length()
	_text(Vector2(w - 256, 53), "RELATIVE VELOCITY", CYAN, 12)
	_text(Vector2(w - 256, 93), "%05.1f" % speed, Color.WHITE, 35)
	_text(Vector2(w - 140, 93), "m/s", MUTED, 17)
	draw_rect(Rect2(w - 256, 109, 206, 3), Color("284052"))
	draw_rect(Rect2(w - 256, 109, 206 * clampf(speed / ship.maximum_speed, 0, 1), 3), CYAN)
	_text(Vector2(w - 256, 137), "ASSIST  " + ("ON" if ship.assist_enabled else "OFF / DRIFT"), CYAN if ship.assist_enabled else AMBER, 14)
	_text(Vector2(w - 256, 160), "STOPPING DISTANCE   %03.0f m" % (speed * speed / (2 * maxf(ship.brake_acceleration, 0.01))), MUTED, 12)
	_text(Vector2(w - 256, 185), "ZONE  %04.0f / %04.0f m" % [ship.position.length(), ship.zone_radius], MUTED, 12)

	if camera:
		var aim := camera.unproject_position(ship.global_position - ship.global_basis.z * 100) / scale_factor
		draw_arc(aim, 7, 0, TAU, 24, Color(0.4, 0.8, 0.8, 0.75), 1)
		draw_line(aim - Vector2(16, 0), aim - Vector2(10, 0), CYAN)
		draw_line(aim + Vector2(10, 0), aim + Vector2(16, 0), CYAN)
		if course and not course.finished:
			_draw_guidance(viewport_size, scale_factor)

	_panel(Rect2(28, h - 208, 330, 91), Color("437a85"))
	if course:
		var title := "COURSE COMPLETE" if course.finished else "NEXT  /  GATE %02d" % (course.next_gate + 1)
		_text(Vector2(46, h - 182), title, CYAN, 14)
		_text(Vector2(46, h - 154), "%d / %d cleared     %05.1f s" % [course.next_gate, course.gates.size(), course.elapsed], Color.WHITE, 20)
		_text(Vector2(46, h - 132), "Press R to fly again" if course.finished else "Fly through each gate in order", MUTED, 13)
	_panel(Rect2(28, h - 95, w - 56, 67), Color("2b5262"))
	_text(Vector2(46, h - 69), "W S  Thrust    A D  Strafe    SPACE CTRL  Vertical    Q E  Roll    MOUSE / ARROWS  Steer", Color.WHITE, 14)
	_text(Vector2(46, h - 45), "SHIFT  Brake    F  Flight assist    R  Restart course    ESC  Pause", MUTED, 14)
	if ship.brake_command:
		_text(Vector2(w / 2 - 40, h - 133), "BRAKING", CYAN, 17)
	elif ship.position.length() > ship.zone_radius * 0.85:
		_text(Vector2(w / 2 - 145, h - 133), "ZONE LIMIT — TURN BACK", AMBER, 17)
	if ship.boundary_resets > 0:
		_text(Vector2(46, 149), "Returned to course start: zone limit", AMBER, 13)
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
