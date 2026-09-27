extends Node3D

const ShipController = preload("res://ship_controller.gd")
const FlightInput = preload("res://flight_input.gd")
const FlightHUD = preload("res://hud.gd")
const CourseProgress = preload("res://course_progress.gd")
var ship: RigidBody3D
var hud: Control
var paused := false
var course := CourseProgress.new()
var camera: Camera3D
var _gate_labels: Array[Label3D] = []
var _thrusters: Array[MeshInstance3D] = []
var _pause_panel: PanelContainer
var _resume_button: Button
var _capturing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capturing = "--capture" in OS.get_cmdline_user_args()
	FlightInput.install()
	_build_environment()
	_build_course()
	_build_ship()
	hud = FlightHUD.new()
	hud.ship = ship
	hud.course = course
	hud.camera = camera
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)
	_build_pause_menu(layer)
	course.gate_passed.connect(_on_gate_passed)
	ship.reset_completed.connect(_reset_course)
	_reset_course()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _capturing:
		_capture_preview()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flight_pause"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	ship.controls_enabled = not value
	ship.clear_commands()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	hud.paused = value
	_pause_panel.visible = value
	if value:
		_resume_button.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(ship) and not _capturing:
		set_paused(true)

func _physics_process(delta: float) -> void:
	if not paused and is_instance_valid(ship):
		course.advance(ship.position, delta)

func _process(_delta: float) -> void:
	if not is_instance_valid(ship):
		return
	for plume in _thrusters:
		plume.visible = ship.thrust_command.z < -0.05 and not ship.brake_command and not paused

func _reset_course() -> void:
	course.reset()
	for i in _gate_labels.size():
		_gate_labels[i].text = "%02d" % (i + 1)
		_gate_labels[i].modulate = Color("65dacf") if i == 0 else Color("79909e")

func _on_gate_passed(index: int) -> void:
	_gate_labels[index].text = "CLEAR"
	_gate_labels[index].modulate = Color("6ee4af")
	if index + 1 < _gate_labels.size():
		_gate_labels[index + 1].modulate = Color("65dacf")

func _restart() -> void:
	ship.request_reset()
	set_paused(false)

func _build_pause_menu(layer: CanvasLayer) -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -210
	_pause_panel.offset_top = -176
	_pause_panel.offset_right = 210
	_pause_panel.offset_bottom = 176
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("0c1929")
	panel_style.border_color = Color("397770")
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(26)
	panel_style.set_corner_radius_all(8)
	_pause_panel.add_theme_stylebox_override("panel", panel_style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	_pause_panel.add_child(stack)
	var title := Label.new()
	title.text = "FLIGHT PAUSED"
	title.add_theme_font_size_override("font_size", 25)
	stack.add_child(title)
	var hint := Label.new()
	hint.text = "Take a breath. Your ship is holding position."
	hint.add_theme_font_size_override("font_size", 14)
	stack.add_child(hint)
	_resume_button = _button("Resume flight  /  ESC", func(): set_paused(false))
	stack.add_child(_resume_button)
	stack.add_child(_button("Restart course", _restart))
	stack.add_child(_button("Exit Flight Lab", func(): get_tree().quit()))
	layer.add_child(_pause_panel)
	_pause_panel.hide()

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("172d40")
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("27514f")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("68d7c9")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	return button

func _material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, collision := true) -> void:
	var body := StaticBody3D.new() if collision else Node3D.new()
	body.position = at
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _material(color)
	body.add_child(mesh)
	if collision:
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collider.shape = box
		body.add_child(collider)
	parent.add_child(body)

func _build_ship() -> void:
	ship = ShipController.new()
	ship.name = "PlayerShip"
	ship.mass = 1.0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.0, 4.0)
	collision.shape = shape
	ship.add_child(collision)
	var hull := MeshInstance3D.new()
	var hull_mesh := PrismMesh.new()
	hull_mesh.size = Vector3(2, 4, 1)
	hull.mesh = hull_mesh
	hull.rotation_degrees.x = -90
	hull.material_override = _material(Color("a3b4c3"))
	ship.add_child(hull)
	_box(ship, Vector3(0, 0.28, 0.2), Vector3(0.85, 0.45, 1.55), Color("153a50"), false)
	for side in [-1, 1]:
		var wing_collision := CollisionShape3D.new()
		var wing_shape := BoxShape3D.new()
		wing_shape.size = Vector3(1.8, 0.16, 2.1)
		wing_collision.shape = wing_shape
		wing_collision.position = Vector3(side * 1.6, -0.1, 0.6)
		ship.add_child(wing_collision)
		var wing := MeshInstance3D.new()
		var wing_mesh := PrismMesh.new()
		wing_mesh.size = Vector3(2, 2.1, 0.16)
		wing.mesh = wing_mesh
		wing.rotation_degrees.x = -90
		wing.position = Vector3(side * 1.6, -0.1, 0.6)
		wing.material_override = _material(Color("a67848"))
		ship.add_child(wing)
		_box(ship, Vector3(side * 0.7, 0, 1.55), Vector3(0.6, 0.6, 0.65), Color("223b50"), false)
		var exhaust := MeshInstance3D.new()
		var exhaust_mesh := CylinderMesh.new()
		exhaust_mesh.top_radius = 0.18
		exhaust_mesh.bottom_radius = 0.02
		exhaust_mesh.height = 1.5
		exhaust.mesh = exhaust_mesh
		exhaust.rotation_degrees.x = -90
		exhaust.position = Vector3(side * 0.7, 0, 2.65)
		exhaust.material_override = _material(Color("57c6ff"), true)
		ship.add_child(exhaust)
		_thrusters.append(exhaust)
	camera = Camera3D.new()
	camera.position = Vector3(0, 3.2, 10)
	camera.rotation_degrees.x = -4
	camera.fov = 75
	camera.far = 6000
	camera.current = true
	ship.add_child(camera)
	add_child(ship)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("030b19")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("86a6cd")
	world.environment.ambient_light_energy = 0.7
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -40, 0)
	sun.light_color = Color("ffe0b5")
	sun.light_energy = 1.5
	add_child(sun)
	var rng := RandomNumberGenerator.new()
	rng.seed = 314159
	var stars := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 1.4
	star_mesh.height = 2.8
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	multi.mesh = star_mesh
	multi.instance_count = 900
	for i in multi.instance_count:
		var direction := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, direction * 2900))
	stars.multimesh = multi
	stars.material_override = _material(Color("839bbb"), true)
	add_child(stars)
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 240
	sphere.height = 480
	planet.mesh = sphere
	planet.position = Vector3(620, 170, -1600)
	planet.material_override = _material(Color("243d64"))
	add_child(planet)

func _build_course() -> void:
	var course_root := Node3D.new()
	course_root.name = "TrainingCourse"
	add_child(course_root)
	for i in 6:
		var center := Vector3(sin(i * 0.65) * 22, sin(i * 0.9) * 12, -60 - i * 85)
		course.gates.append(center)
		var color := Color("45b9b4") if i % 2 == 0 else Color("d49b54")
		for side in [-1, 1]:
			_box(course_root, center + Vector3(side * 15, 0, 0), Vector3(1, 30, 2), color)
			_box(course_root, center + Vector3(0, side * 15, 0), Vector3(30, 1, 2), color)
		var label := Label3D.new()
		label.text = "%02d" % (i + 1)
		label.position = center + Vector3(-13, 18, 0)
		label.font_size = 36
		label.pixel_size = 0.06
		course_root.add_child(label)
		_gate_labels.append(label)
	for i in 18:
		var at := Vector3(-65 - (i % 3) * 25, (i % 4) * 10 - 15, -40 - i * 28)
		_box(course_root, at, Vector3(8, 6, 10), Color("47576b"))
	# Sparse reference grid provides motion cues without an infinite world.
	for i in range(-8, 9):
		_box(course_root, Vector3(i * 25, -30, -250), Vector3(0.12, 0.12, 600), Color("234358"), false)
		_box(course_root, Vector3(0, -30, i * 40 - 250), Vector3(400, 0.12, 0.12), Color("234358"), false)

func _capture_preview() -> void:
	for i in 8:
		await get_tree().process_frame
	var filename := "preview.png"
	if "--capture-pause" in OS.get_cmdline_user_args():
		set_paused(true)
		filename = "preview_pause.png"
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://" + filename)
	get_tree().quit()
