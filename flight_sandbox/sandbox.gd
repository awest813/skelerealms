extends Node3D

const ShipController = preload("res://ship_controller.gd")
const FlightInput = preload("res://flight_input.gd")
const FlightHUD = preload("res://hud.gd")
const CourseProgress = preload("res://course_progress.gd")
const LaserCannon = preload("res://laser_cannon.gd")
const DroneBrain = preload("res://drone_brain.gd")
const ShipState = preload("res://ship_state.gd")
const SystemDefinition = preload("res://system_definition.gd")
const CommodityDefinition = preload("res://commodity_definition.gd")
const MarketService = preload("res://market_service.gd")
const MissionService = preload("res://mission_service.gd")
const AudioManager = preload("res://audio_manager.gd")
const HullDefinition = preload("res://hull_definition.gd")
const DialogueService = preload("res://dialogue_service.gd")
const SAVE_PATH := "user://flight_ship_save.json"
const DRONE_RESPAWN_DELAY := 5.0
const TRAVEL_LOCK_TIME := 0.6
const JUMP_PROMPT_RANGE := 45.0
const DOCK_RANGE := 35.0
const DOCK_MAX_SPEED := 15.0
const START_CREDITS := 120
const START_CARGO_CAPACITY := 20
## System id → commodity ids confiscated by customs on docking.
const BANNED := {&"sector_alpha": [&"spike"]}
const ECON_SEED := 4242
const MAX_GENERATED_ACTIVE := 4
const BLIND_EYE_COST := 300
const FACTION_NAMES := {&"meridian": "Meridian Authority", &"reach": "Reach Collective", &"flats": "Flats Union", &"cinder": "Cinder Combine"}
const SYSTEM_FACTION := {&"sector_alpha": &"meridian", &"outer_reach": &"reach", &"meridian_flats": &"flats", &"cinder_docks": &"cinder"}
const STATION_MERCHANT := {&"sector_alpha": "sable", &"outer_reach": "ilsa", &"meridian_flats": "jeb", &"cinder_docks": "kass"}
var ship: RigidBody3D
var drone: RigidBody3D
var zone: Node3D
var hud: Control
var paused := false
var course := CourseProgress.new()
var camera: Camera3D
var kills := 0
var systems: Dictionary = {}
var current_system := &""
var wallet := {&"credits": START_CREDITS}
var cargo := {}
var cargo_capacity := START_CARGO_CAPACITY
var upgrades: Array = []
var markets: Dictionary = {}
var commodities: Array = []
var missions: RefCounted
var docked := false
var audio: Node
var econ_rng := RandomNumberGenerator.new()
var dialogue: RefCounted
var contacts := {}
var mission_offers: Array = []
var standings := {&"meridian": 0, &"reach": 0, &"flats": 0, &"cinder": 0}
var customs_pass := false
## Faction id → heat 0..100. Busts and hunter kills raise it; pardons,
## reparations, and travel cool it. At 50+, hunters come calling.
var heat := {&"meridian": 0, &"reach": 0, &"flats": 0, &"cinder": 0}
var hunter: RigidBody3D
const HUNTER_STANDING := -25
const HUNTER_HEAT := 50
const HEAT_BUST := 25
const HEAT_HUNTER_KILL := 10
const REPARATION_COST := 150
const REPARATION_RELIEF := 50
## NPC id → disposition 0..100 (50 neutral). Raised by bribes, admiration,
## and successful persuasion; prices and checks follow it.
var disposition := {}
var discounts := {}
var blind_discount := false
var social_rng := RandomNumberGenerator.new()
const SOCIAL_SEED := 777
## Test hook: when >= 0, persuasion rolls use this value instead of RNG.
var social_rigged := -1.0
var _dialogue_session := {}
var hulls: Dictionary = {}
var owned_hulls: Array = [&"sparrow"]
var active_hull := &"sparrow"
var _respawn_left := 0.0
var _travel_lock := false
## Remaining hops of the plotted course (system ids, next first). Empty = none.
var nav_route: Array = []
var map_open := false
var _map_panel: PanelContainer
var _map_detail: Label
var _map_rows: VBoxContainer
var _station_panel: PanelContainer
var _station_title: Label
var _market_tab: VBoxContainer
var _outfit_tab: VBoxContainer
var _ship_tab: VBoxContainer
var _mission_tab: VBoxContainer
var _contacts_tab: VBoxContainer
var _lore_tab: VBoxContainer
var _gate_labels: Array[Label3D] = []
var _thrusters: Array[MeshInstance3D] = []
var _pause_panel: PanelContainer
var _resume_button: Button
var _pause_info: Label
var _capturing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capturing = "--capture" in OS.get_cmdline_user_args()
	FlightInput.install()
	_build_systems()
	_build_commodities()
	missions = MissionService.new()
	econ_rng.seed = ECON_SEED
	dialogue = DialogueService.new()
	_build_dialogues()
	_build_contacts()
	social_rng.seed = SOCIAL_SEED
	audio = AudioManager.new()
	add_child(audio)
	_build_hulls()
	_build_ship()
	hud = FlightHUD.new()
	hud.ship = ship
	hud.course = course
	hud.camera = camera
	hud.kills = kills
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)
	_switch_zone(&"sector_alpha")
	ship.connect("damaged", Callable(hud, "flash_damage"))
	ship.connect("destroyed", _on_player_destroyed)
	_build_pause_menu(layer)
	_build_station_menu(layer)
	_build_map(layer)
	course.gate_passed.connect(_on_gate_passed)
	ship.reset_completed.connect(_reset_course)
	_reset_course()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _capturing:
		_capture_preview()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flight_pause"):
		if map_open:
			close_map()
		elif docked:
			undock()
		else:
			set_paused(not paused)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("flight_map"):
		if map_open:
			close_map()
		elif not paused and not docked:
			open_map()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("flight_dock"):
		if docked:
			undock()
		elif not paused:
			dock()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("flight_land"):
		_try_land_from_beacon()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("flight_jump"):
		_try_jump_from_gate()
		get_viewport().set_input_as_handled()


## Proximity-gated jump input: the ship must be near this zone's jump ring.
## Range is a cockpit convenience; jump_to() itself validates links/lock.
## Nearest linked gate in range, or &"" when none qualifies.
func _gate_in_range() -> StringName:
	var def = systems.get(current_system)
	if def == null:
		return &""
	var best := &""
	var best_dist := JUMP_PROMPT_RANGE
	for link in (def.links as Array):
		var dest := StringName(link)
		if not systems.has(dest):
			continue
		var dist := ship.position.distance_to(gate_pos_for(def, dest))
		if dist <= best_dist:
			best = dest
			best_dist = dist
	return best


func _try_jump_from_gate() -> void:
	if paused or _travel_lock or not is_instance_valid(ship):
		return
	var dest := _gate_in_range()
	if dest != &"":
		jump_to(dest)


## Atmospheric entry: like jump_to but from a landing beacon to its surface
## zone. Uses the same travel lock and commit path.
func land() -> bool:
	if _travel_lock:
		return false
	if not is_instance_valid(ship) or ship.destroyed_flag:
		return false
	var def = systems.get(current_system)
	if def == null or def.landing_target == &"":
		return false
	if not systems.has(def.landing_target):
		return false
	if ship.position.distance_to(def.landing_beacon) > JUMP_PROMPT_RANGE:
		return false
	_travel_lock = true
	hud.travel_active = true
	if is_instance_valid(audio):
		audio.play_sfx(&"jump")
	_pass_time()
	gain_xp("piloting", 10)
	_switch_zone(def.landing_target)
	hud.notice("Landing — %s" % systems[def.landing_target].display_name)
	get_tree().create_timer(TRAVEL_LOCK_TIME).timeout.connect(_unlock_travel)
	return true


func _try_land_from_beacon() -> void:
	if paused or _travel_lock or docked or not is_instance_valid(ship):
		return
	land()


## Travel coordinator: validate → lock → commit new zone → restore input.
## Returns true when a transition started. Invalid destinations, a destroyed
## ship, and duplicate input during the lock are rejected without side effects.
func jump_to(destination: StringName) -> bool:
	if _travel_lock:
		return false
	if not is_instance_valid(ship) or ship.destroyed_flag:
		return false
	var def = systems.get(current_system)
	if def == null or not (destination in def.links):
		return false
	if not systems.has(destination):
		return false
	_travel_lock = true
	hud.travel_active = true
	if is_instance_valid(audio):
		audio.play_sfx(&"jump")
	_pass_time()
	gain_xp("piloting", 10)
	_switch_zone(destination)
	hud.notice("Jump complete — %s" % systems[destination].display_name)
	get_tree().create_timer(TRAVEL_LOCK_TIME).timeout.connect(_unlock_travel)
	return true


func _unlock_travel() -> void:
	_travel_lock = false
	if is_instance_valid(hud):
		hud.travel_active = false


## Commit point: the old zone and its drone are freed and the destination is
## built with the player placed at its arrival marker. Player-level state
## (durability, kills) persists because the ship node is never rebuilt.
func _switch_zone(id: StringName) -> void:
	var def = systems[id]
	if is_instance_valid(zone):
		zone.free()
	if is_instance_valid(drone):
		drone.free()
	if is_instance_valid(hunter):
		hunter.free()
		hunter = null
	zone = Node3D.new()
	zone.name = "Zone_%s" % id
	add_child(zone)
	current_system = id
	if def.is_surface:
		_build_surface(def, zone)
	else:
		_build_environment(def, zone)
	_build_course(def, zone)
	_build_jump_gate(def, zone)
	_build_station(def, zone)
	if def.landing_target != &"" and systems.has(def.landing_target):
		_build_landing_beacon(def, zone)
	ship.position = def.arrival_position
	ship.rotation = Vector3(0, deg_to_rad(def.arrival_yaw_deg), 0)
	ship.linear_velocity = Vector3.ZERO
	ship.angular_velocity = Vector3.ZERO
	_build_drone()
	_maybe_spawn_hunter()
	_reset_course()
	_respawn_left = 0.0
	if not nav_route.is_empty() and StringName(nav_route[0]) == id:
		nav_route.pop_front()
	if hud:
		hud.system_name = def.display_name
		hud.system_sub = def.sub_name
		hud.drone = drone
		hud.hunter = hunter

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	ship.controls_enabled = not value
	ship.clear_commands()
	if is_instance_valid(drone):
		drone.controls_enabled = not value
		drone.clear_commands()
	if is_instance_valid(hunter):
		hunter.controls_enabled = not value
		hunter.clear_commands()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	hud.paused = value
	_pause_panel.visible = value
	if value:
		_pause_info.text = "Piloting %s (%d)   Mercantile %s (%d)   Speechcraft %s (%d)\n%s   %s\n%s   %s" % [
			skill_title("piloting"), int(skills["piloting"]),
			skill_title("trade"), int(skills["trade"]),
			skill_title("speech"), int(skills["speech"]),
			faction_title(&"meridian"), faction_title(&"reach"),
			faction_title(&"flats"), faction_title(&"cinder")]
		_resume_button.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(ship) and not _capturing:
		set_paused(true)

func _physics_process(delta: float) -> void:
	if paused:
		return
	if is_instance_valid(ship):
		course.advance(ship.position, delta)
	if is_instance_valid(audio):
		var throttle := 0.0
		if not paused and is_instance_valid(ship):
			throttle = clampf((ship.get("thrust_command") as Vector3).length(), 0.0, 1.0)
		audio.set_throttle(throttle)
	_update_jump_prompt()
	_update_dock_prompt()
	_update_land_prompt()
	_update_economy_hud()
	_update_plot()
	if _respawn_left > 0.0 and is_instance_valid(drone):
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_respawn_drone()


func _update_jump_prompt() -> void:
	if not is_instance_valid(hud):
		return
	if _travel_lock or ship.destroyed_flag:
		hud.jump_prompt = ""
		return
	var dest := _gate_in_range()
	if dest == &"":
		hud.jump_prompt = ""
	else:
		hud.jump_prompt = "Press J — jump to %s" % systems[dest].display_name


func _update_dock_prompt() -> void:
	if not is_instance_valid(hud):
		return
	if docked or _travel_lock or ship.destroyed_flag:
		hud.dock_prompt = ""
	elif dock_envelope_ok():
		hud.dock_prompt = "Press X — dock at %s" % _station_name()
	else:
		hud.dock_prompt = ""


## Ring position for a link, falling back to the legacy single gate.
func gate_pos_for(def, dest: StringName) -> Vector3:
	var gates: Dictionary = def.link_gates
	if gates.has(dest):
		return gates[dest]
	if gates.has(str(dest)):
		return gates[str(dest)]
	return def.jump_gate_position


func _update_plot() -> void:
	if not is_instance_valid(hud):
		return
	var def = systems.get(current_system)
	while not nav_route.is_empty():
		var hopping := StringName(nav_route[0])
		if def != null and hopping in (def.links as Array) and systems.has(hopping):
			break
		nav_route.pop_front()
	if nav_route.is_empty():
		hud.plot_label = ""
		return
	var final: StringName = nav_route[nav_route.size() - 1]
	hud.plot_label = "PLOT: %s (%d)" % [systems[final].display_name, nav_route.size()]
	hud.plot_pos = gate_pos_for(def, StringName(nav_route[0]))


func _update_land_prompt() -> void:
	if not is_instance_valid(hud):
		return
	var def = systems.get(current_system)
	if def == null or _travel_lock or docked or ship.destroyed_flag:
		hud.land_prompt = ""
		return
	if def.landing_target != &"" and systems.has(def.landing_target):
		if ship.position.distance_to(def.landing_beacon) <= JUMP_PROMPT_RANGE:
			hud.land_prompt = "Press L — land at %s" % systems[def.landing_target].display_name
			return
	hud.land_prompt = ""


func _update_economy_hud() -> void:
	if not is_instance_valid(hud):
		return
	hud.credits = int(wallet.get(&"credits", 0))
	var used := 0
	for good in cargo:
		used += int(cargo[good])
	hud.cargo_used = used
	hud.cargo_capacity = cargo_capacity
	hud.mission_text = missions.tracker_text()


func _build_commodities() -> void:
	var water := CommodityDefinition.new()
	water.id = &"water"
	water.display_name = "Water Ice"
	water.base_price = 10
	water.description = "Reaction mass and life support staple."
	var ore := CommodityDefinition.new()
	ore.id = &"ore"
	ore.display_name = "Titanium Ore"
	ore.base_price = 30
	ore.description = "Hull-grade ore, cheap where mined."
	var medicine := CommodityDefinition.new()
	medicine.id = &"medicine"
	medicine.display_name = "Medi-gel"
	medicine.base_price = 70
	medicine.description = "Always worth more where it is scarce."
	var spike := CommodityDefinition.new()
	spike.id = &"spike"
	spike.display_name = "Dreamspike"
	spike.base_price = 60
	spike.description = "Banned in Alpha. Lucrative where it lands."
	commodities = [water, ore, medicine, spike]


func _market():
	return markets.get(current_system)


func _build_dialogues() -> void:
	dialogue.add_definition("rook", DialogueService.make_definition("hello", [
		{"id": "hello", "speaker": "Rook, Fixer", "text": "Word is the Reach can't get enough medi-gel — {med_reach}cr a unit and climbing. Shame about the trip.",
			"choices": [
				{"text": "Got work?", "to": "work", "do": ""},
				{"text": "Tell me more.", "to": "rumor", "do": ""},
				{"text": "Make my heat go away?", "to": "pardon_ok", "do": "pardon", "check": "speech", "dc": 40, "fail_to": "pardon_no"},
				{"text": "Anything paying?", "to": "hello", "do": "contract"},
				{"text": "Later.", "to": "bye", "do": "leave"}]},
		{"id": "work", "speaker": "Rook, Fixer", "text": "Drones are chewing up couriers. Two confirmed kills, 300 credits. Interested?",
			"choices": [
				{"text": "I'll hunt them.", "to": "accepted", "do": "accept:bounty_drones"},
				{"text": "Not now.", "to": "hello", "do": ""}]},
		{"id": "accepted", "speaker": "Rook, Fixer", "text": "Good hunting. Bring me transponders, get paid.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "rumor", "speaker": "Rook, Fixer", "text": "Alpha pays {ore_alpha}cr for ore all day. The Reach practically gives it away at {ore_reach}cr.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "pardon_ok", "speaker": "Rook, Fixer", "text": "Consider it handled. Meridian owes me favors.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "pardon_no", "speaker": "Rook, Fixer", "text": "Meridian doesn't forget. Come back with leverage.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "bye", "speaker": "Rook, Fixer", "text": "Watch the skies.", "choices": []},
	]))
	dialogue.add_definition("sable", DialogueService.make_definition("hello", [
		{"id": "hello", "speaker": "Sable, Bartender", "text": "New faces mean new freight. Haul 6 ore out to the Reach and there's 250 in it.",
			"choices": [
				{"text": "I'll haul it.", "to": "accepted", "do": "accept:delivery_ore"},
				{"text": "Any rumors?", "to": "rumor", "do": ""},
				{"text": "Anything on the house?", "to": "treat_ok", "do": "freebie", "check": "speech", "dc": 25, "fail_to": "sober_no"},
				{"text": "Here's 100 for your trouble.", "to": "hello", "do": "bribe:100"},
				{"text": "Anything paying?", "to": "hello", "do": "contract"},
				{"text": "Just passing through.", "to": "bye", "do": "leave"}]},
		{"id": "accepted", "speaker": "Sable, Bartender", "text": "The Anchorage pays on delivery. Don't drink the cargo.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "rumor", "speaker": "Sable, Bartender", "text": "Water's {water_alpha}cr here, {water_reach}cr out there. Thirsty work, hauling.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "treat_ok", "speaker": "Sable, Bartender", "text": "Coolant flush, on the house. +2 water, +15 hull. Don't tell the till.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "sober_no", "speaker": "Sable, Bartender", "text": "The house is dry for strangers.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "bye", "speaker": "Sable, Bartender", "text": "Mind the airlock.", "choices": []},
	]))
	dialogue.add_definition("ilsa", DialogueService.make_definition("hello", [
		{"id": "hello", "speaker": "Doc Ilsa", "text": "We're drowning in spike and short on sense. Haul 4 medi-gel up to Alpha, 300 credits.",
			"choices": [
				{"text": "I'll carry it.", "to": "accepted", "do": "accept:delivery_meds"},
				{"text": "What pays out here?", "to": "rumor", "do": ""},
				{"text": "Cut me a deal on medi-gel?", "to": "deal_ok", "do": "discount:medicine", "check": "speech", "dc": 30, "fail_to": "deal_no"},
				{"text": "Anything paying?", "to": "hello", "do": "contract"},
				{"text": "Another time.", "to": "bye", "do": "leave"}]},
		{"id": "accepted", "speaker": "Doc Ilsa", "text": "Alpha General pays on arrival. Keep it cool.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "rumor", "speaker": "Doc Ilsa", "text": "Spike goes for {spike_reach}cr here. Meridian would pay {spike_alpha}cr — if customs didn't eat first.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "deal_ok", "speaker": "Doc Ilsa", "text": "Fine — 20% off medi-gel, one purchase. Professional courtesy.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "deal_no", "speaker": "Doc Ilsa", "text": "List price. The clinic doesn't haggle.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "bye", "speaker": "Doc Ilsa", "text": "Don't bleed on the deck.", "choices": []},
	]))
	dialogue.add_definition("jeb", DialogueService.make_definition("hello", [
		{"id": "hello", "speaker": "Prospector Jeb", "text": "Flats pay {spike_flats}cr for spike, no questions. Hell of a view, too.",
			"choices": [
				{"text": "Why no questions?", "to": "rumor", "do": ""},
				{"text": "Nice rig.", "to": "flattered", "do": "admire", "check": "speech", "dc": 15, "fail_to": "bristled"},
				{"text": "Anything paying?", "to": "hello", "do": "contract"},
				{"text": "I'll be going.", "to": "bye", "do": "leave"}]},
		{"id": "rumor", "speaker": "Prospector Jeb", "text": "Mountains hide the stills. Buy low in the Reach, sell here or up there. You didn't hear it from Jeb.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "flattered", "speaker": "Prospector Jeb", "text": "She's a good rig! Dug half these flats with her.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "bristled", "speaker": "Prospector Jeb", "text": "Flattery'll get you dust.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "bye", "speaker": "Prospector Jeb", "text": "Dust keeps.", "choices": []},
	]))
	dialogue.add_definition("vex", DialogueService.make_definition("hello", [
		{"id": "hello", "speaker": "Vex, Fence", "text": "Customs in Meridian has eyes everywhere. For {blindeye_cost}, I can make them blink.",
			"choices": [
				{"text": "Blind eye, {blindeye_cost}cr.", "to": "sold", "do": "blindeye"},
				{"text": "What moves?", "to": "rumor", "do": ""},
				{"text": "Friend price on the blind eye?", "to": "deal_ok", "do": "blind200", "check": "speech", "dc": 35, "fail_to": "deal_no"},
				{"text": "Here's 150 for your trouble.", "to": "hello", "do": "bribe:150"},
				{"text": "Walk away.", "to": "bye", "do": "leave"}]},
		{"id": "sold", "speaker": "Vex, Fence", "text": "One docking. Don't waste it.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "rumor", "speaker": "Vex, Fence", "text": "Spike lands at {spike_alpha}cr up here when it lands at all. Buy at {spike_reach}cr downwell.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "deal_ok", "speaker": "Vex, Fence", "text": "Two hundred, for old times. Don't tell the others.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "deal_no", "speaker": "Vex, Fence", "text": "List price. Friendship is expensive.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "bye", "speaker": "Vex, Fence", "text": "We never spoke.", "choices": []},
	]))
	dialogue.add_definition("kass", DialogueService.make_definition("hello", [
		{"id": "hello", "speaker": "Foreman Kass", "text": "Cinder runs hot and pays hotter. Spike moves at {spike_cinder}cr, no customs, no questions.",
			"choices": [
				{"text": "Why no customs?", "to": "rumor", "do": ""},
				{"text": "Impressive operation.", "to": "praised", "do": "admire", "check": "speech", "dc": 15, "fail_to": "bristled"},
				{"text": "Anything paying?", "to": "hello", "do": "contract"},
				{"text": "Back to work.", "to": "bye", "do": "leave"}]},
		{"id": "rumor", "speaker": "Foreman Kass", "text": "The Combine pays its tithe in ore and silence. Meridian can't find us; the Reach won't look.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "praised", "speaker": "Foreman Kass", "text": "Built it myself from a wreck and a wager.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "bristled", "speaker": "Foreman Kass", "text": "Flattery buys nothing here.",
			"choices": [{"text": "Back.", "to": "hello", "do": ""}]},
		{"id": "bye", "speaker": "Foreman Kass", "text": "Mind the heat.", "choices": []},
	]))


func _build_contacts() -> void:
	contacts = {
		&"sector_alpha": [
			{"name": "Rook", "role": "Fixer", "dlg": "rook"},
			{"name": "Sable", "role": "Bartender", "dlg": "sable"},
			{"name": "Vex", "role": "Fence", "dlg": "vex"},
		],
		&"outer_reach": [
			{"name": "Doc Ilsa", "role": "Physician", "dlg": "ilsa"},
		],
		&"meridian_flats": [
			{"name": "Prospector Jeb", "role": "Miner", "dlg": "jeb"},
		],
		&"cinder_docks": [
			{"name": "Foreman Kass", "role": "Combine Boss", "dlg": "kass"},
		],
	}


## Refresh template values (live prices) before showing dialogue.
func _update_dialogue_context() -> void:
	var alpha = markets.get(&"sector_alpha")
	var reach = markets.get(&"outer_reach")
	var flats = markets.get(&"meridian_flats")
	if alpha == null or reach == null or flats == null:
		return
	dialogue.context = {
		"ore_alpha": alpha.quote(&"ore"), "ore_reach": reach.quote(&"ore"),
		"water_alpha": alpha.quote(&"water"), "water_reach": reach.quote(&"water"),
		"med_reach": reach.quote(&"medicine"),
		"spike_alpha": alpha.quote(&"spike"), "spike_reach": reach.quote(&"spike"),
		"spike_flats": flats.quote(&"spike"), "blindeye_cost": _blind_eye_cost(),
	}
	var cinder = markets.get(&"cinder_docks")
	if cinder != null:
		dialogue.context["spike_cinder"] = cinder.quote(&"spike")


func accept_dialogue_mission(id: String) -> bool:
	var ok := false
	match id:
		"delivery_ore":
			ok = accept_delivery()
		"bounty_drones":
			ok = accept_bounty()
		"delivery_meds":
			ok = accept_meds()
	if ok:
		_refresh_station_menu()
	return ok


func accept_meds() -> bool:
	var ok: bool = missions.accept(MissionService.delivery_mission("delivery_meds", "medicine", 4, "sector_alpha", "Training Sector", 300))
	if ok:
		_refresh_station_menu()
	return ok


## Regenerate the contracts board when empty, bounded by active generated
## missions so rewards stay finite.
func _refresh_contracts() -> void:
	if not mission_offers.is_empty():
		return
	var active_generated := 0
	for m in (missions.missions as Array):
		if str(m.get("id", "")).begins_with("gen_") and not bool(m.get("claimed", false)):
			active_generated += 1
	if active_generated >= MAX_GENERATED_ACTIVE:
		return
	var def = systems.get(current_system)
	if def == null:
		return
	var names := {}
	for id in systems:
		names[str(id)] = systems[id].display_name
	var bases := {}
	for good in commodities:
		if good.id != &"spike":
			bases[str(good.id)] = good.base_price
	mission_offers = MissionService.generate(econ_rng, def.links, names, bases.keys(), bases)


func accept_offer(id: String) -> bool:
	for i in mission_offers.size():
		if str(mission_offers[i].get("id", "")) == id:
			var ok: bool = missions.accept(mission_offers[i])
			if ok:
				mission_offers.remove_at(i)
				_refresh_station_menu()
			return ok
	return false


func _offer_text(offer: Dictionary) -> String:
	if str(offer.get("kind", "")) == "delivery":
		return "CONTRACT: Deliver %d %s to %s — %d cr" % [int(offer.get("qty", 0)), str(offer.get("commodity", "")), str(offer.get("dest_name", "")), int(offer.get("reward", 0))]
	return "CONTRACT: Destroy %d drones — %d cr" % [int(offer.get("qty", 0)), int(offer.get("reward", 0))]


## Dialogue-called radiant contract: one fresh offer straight to the board.
func _effect_contract() -> void:
	if mission_offers.size() >= 4:
		hud.notice("The board is full")
		return
	var def = systems.get(current_system)
	if def == null:
		return
	var names := {}
	for id in systems:
		names[str(id)] = systems[id].display_name
	var bases := {}
	for good in commodities:
		if good.id != &"spike":
			bases[str(good.id)] = good.base_price
	var made: Array = MissionService.generate(econ_rng, def.links, names, bases.keys(), bases)
	if made.is_empty():
		return
	mission_offers.append(made[econ_rng.randi_range(0, made.size() - 1)])
	hud.notice("Contract offered — check Missions")
	_refresh_station_menu()


func _build_systems() -> void:
	var alpha := SystemDefinition.new()
	alpha.id = &"sector_alpha"
	alpha.display_name = "TRAINING SECTOR"
	alpha.sub_name = "LOCAL SPACE"
	alpha.links = [&"outer_reach"] as Array[StringName]
	alpha.station_name = "PORT MERIDIAN"
	alpha.landing_target = &"meridian_flats"
	alpha.link_gates = {"outer_reach": Vector3(0, 10, -560)}
	systems[alpha.id] = alpha
	markets[alpha.id] = MarketService.with_offers(
		[&"water", &"ore", &"medicine", &"spike"], [30, 15, 4, 0], [8, 28, 95, 120])
	var flats := SystemDefinition.new()
	flats.id = &"meridian_flats"
	flats.display_name = "MERIDIAN FLATS"
	flats.sub_name = "SURFACE — DAY SIDE"
	flats.links = [&"sector_alpha"] as Array[StringName]
	flats.is_surface = true
	flats.gate_count = 0
	flats.station_name = "FLATS SPACEPORT"
	flats.station_position = Vector3(0, 5, 0)
	flats.jump_gate_position = Vector3(0, 40, -200)
	flats.link_gates = {"sector_alpha": Vector3(0, 40, -200)}
	flats.arrival_position = Vector3(0, 25, 80)
	flats.accent_a = Color("65dacf")
	flats.accent_b = Color("e8b16b")
	flats.obstacle_color = Color("5e4a3a")
	systems[flats.id] = flats
	markets[flats.id] = MarketService.with_offers(
		[&"water", &"ore", &"medicine", &"spike"], [20, 25, 8, 3], [12, 22, 70, 75])
	var cinder := SystemDefinition.new()
	cinder.id = &"cinder_docks"
	cinder.display_name = "CINDER DOCKS"
	cinder.sub_name = "SURFACE — NIGHT SIDE"
	cinder.links = [&"outer_reach"] as Array[StringName]
	cinder.is_surface = true
	cinder.gate_count = 0
	cinder.surface_sky = Color("3a1620")
	cinder.ground_color = Color("2e2a28")
	cinder.station_name = "CINDER DOCKS"
	cinder.station_position = Vector3(0, 5, 0)
	cinder.jump_gate_position = Vector3(0, 40, -200)
	cinder.link_gates = {"outer_reach": Vector3(0, 40, -200)}
	cinder.arrival_position = Vector3(0, 25, 80)
	cinder.accent_a = Color("e07b39")
	cinder.accent_b = Color("c86ab4")
	cinder.obstacle_color = Color("3a3230")
	systems[cinder.id] = cinder
	markets[cinder.id] = MarketService.with_offers(
		[&"water", &"ore", &"medicine", &"spike"], [15, 30, 6, 10], [16, 24, 80, 90])
	var beta := SystemDefinition.new()
	beta.id = &"outer_reach"
	beta.display_name = "OUTER REACH"
	beta.sub_name = "FAR SHOALS"
	beta.links = [&"sector_alpha", &"cinder_docks"] as Array[StringName]
	beta.link_gates = {"sector_alpha": Vector3(0, 10, -560), "cinder_docks": Vector3(120, 0, -400)}
	beta.bg_color = Color("0d0714")
	beta.ambient_color = Color("c9a0c8")
	beta.ambient_energy = 0.6
	beta.sun_rotation = Vector3(-35, 30, 0)
	beta.sun_color = Color("ffb08a")
	beta.sun_energy = 1.2
	beta.star_seed = 777
	beta.planet_position = Vector3(-500, 220, -1500)
	beta.planet_radius = 300.0
	beta.planet_color = Color("7a3b1e")
	beta.gate_phase = 2.1
	beta.gate_spacing = 95.0
	beta.accent_a = Color("c86ab4")
	beta.accent_b = Color("6ad4c8")
	beta.obstacle_color = Color("5b3a5e")
	beta.jump_gate_position = Vector3(-40, -6, -560)
	beta.station_name = "REACH ANCHORAGE"
	beta.station_position = Vector3(-90, -5, -250)
	systems[beta.id] = beta
	markets[beta.id] = MarketService.with_offers(
		[&"water", &"ore", &"medicine", &"spike"], [10, 40, 12, 8], [14, 18, 55, 40])

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
	gain_xp("piloting", 5)
	_gate_labels[index].text = "CLEAR"
	_gate_labels[index].modulate = Color("6ee4af")
	if index + 1 < _gate_labels.size():
		_gate_labels[index + 1].modulate = Color("65dacf")

func _restart() -> void:
	if docked:
		docked = false
		_hide_station_menu()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ship.repair_full()
	ship.request_reset()
	ship.controls_enabled = true
	_travel_lock = false
	hud.travel_active = false
	_reset_drone()
	set_paused(false)


func save_ship() -> void:
	var state = ShipState.snapshot(ship, current_system)
	state.credits = int(wallet.get(&"credits", 0))
	state.cargo = (cargo as Dictionary).duplicate()
	state.cargo_capacity = cargo_capacity
	state.upgrades = upgrades.duplicate()
	state.missions = (missions.missions as Array).duplicate(true)
	state.hull_id = active_hull
	state.owned_hulls = owned_hulls.duplicate()
	var saved_standings := {}
	for key in standings:
		saved_standings[str(key)] = int(standings[key])
	state.standings = saved_standings
	state.customs_pass = customs_pass
	var saved_skills := {}
	for key in skills:
		saved_skills[str(key)] = int(skills[key])
	state.skills = saved_skills
	var saved_disp := {}
	for key in disposition:
		saved_disp[str(key)] = int(disposition[key])
	state.disposition = saved_disp
	var saved_heat := {}
	for key in heat:
		saved_heat[str(key)] = int(heat[key])
	state.heat = saved_heat
	var saved_markets := {}
	for id in markets:
		saved_markets[id] = {
			"stock": (markets[id].stock as Dictionary).duplicate(),
			"prices": (markets[id].prices as Dictionary).duplicate(),
		}
	state.markets = saved_markets
	state.mission_offers = mission_offers.duplicate(true)
	if state.save_to(SAVE_PATH):
		hud.notice("Ship state saved")
	else:
		hud.notice("Save failed")


func load_ship() -> void:
	var state = ShipState.load_from(SAVE_PATH)
	if state == null:
		hud.notice("No save found")
		return
	var target_system: StringName = state.system_id
	if target_system != &"" and target_system != current_system:
		if _travel_lock:
			hud.notice("Busy — try again")
			return
		if not systems.has(target_system):
			hud.notice("Unknown system in save")
			return
		_pass_time()
		_switch_zone(target_system)
	for id in (state.owned_hulls as Array):
		if not owned_hulls.has(id) and hulls.has(StringName(id)):
			owned_hulls.append(id)
	var saved_hull := StringName(str(state.hull_id))
	if saved_hull != active_hull and owned_hulls.has(str(saved_hull)) and hulls.has(saved_hull):
		equip_hull(str(saved_hull))
	state.apply_to(ship)
	_apply_pilot_bonus()
	wallet[&"credits"] = int(state.credits)
	cargo = (state.cargo as Dictionary).duplicate()
	cargo_capacity = int(state.cargo_capacity)
	upgrades = (state.upgrades as Array).duplicate()
	missions.missions = (state.missions as Array).duplicate(true)
	for id in (state.markets as Dictionary):
		if markets.has(id):
			var entry: Dictionary = (state.markets as Dictionary)[id]
			markets[id].stock = ((entry.get("stock", {}) as Dictionary)).duplicate()
			markets[id].prices = ((entry.get("prices", {}) as Dictionary)).duplicate()
	mission_offers = (state.mission_offers as Array).duplicate(true)
	for key in (state.standings as Dictionary):
		if standings.has(key):
			standings[key] = int((state.standings as Dictionary)[key])
	customs_pass = bool(state.customs_pass)
	for key in (state.skills as Dictionary):
		if skills.has(key):
			skills[key] = int((state.skills as Dictionary)[key])
	for key in (state.disposition as Dictionary):
		disposition[StringName(str(key))] = int((state.disposition as Dictionary)[key])
	for key in (state.heat as Dictionary):
		if heat.has(key):
			heat[key] = int((state.heat as Dictionary)[key])
	_refresh_station_menu()
	hud.notice("Ship state loaded")


## ── Docking & station services ────────────────────────────────────────

const UPGRADES := {
	&"shield_booster": {"name": "Shield Booster", "desc": "+25 max shield", "cost": 400},
	&"cargo_expansion": {"name": "Cargo Hold", "desc": "+10 cargo space", "cost": 300},
	&"insurance": {"name": "Cargo Insurance", "desc": "Keep cargo after destruction (one wreck)", "cost": 200},
}
const LORE := [
	{"title": "Meridian Charter", "text": "Port Meridian was chartered as a free dock after the Belt courts collapsed. Every berth pays harbor tithe; every tithe buys patrol fuel. That is the whole of the law here."},
	{"title": "Reach Strike of '87", "text": "When the combines cut hazard pay, the Reach crews downed tools for forty-one days. The ore piled up, the prices cratered, and nobody has trusted company scrip since."},
	{"title": "Flats Water War", "text": "Three prospecting outfits fought over the deep ice for one dry summer. The Union was born the day they stopped shooting and started sharing the pumps."},
	{"title": "Dreamspike Advisory", "text": "Dreamspike is a Schedule One euphoriant under Meridian law. Possession draws seizure and fine. The Reach and the Flats decline to enforce. You didn't read this here."},
]


func _station_pos() -> Vector3:
	var def = systems.get(current_system)
	return def.station_position if def != null else Vector3(90, 5, -250)


func _station_name() -> String:
	var def = systems.get(current_system)
	return def.station_name if def != null else "PORT MERIDIAN"


## Assisted-docking envelope: close and slow. The menu only opens inside it.
func dock_envelope_ok() -> bool:
	if not is_instance_valid(ship) or ship.destroyed_flag:
		return false
	if ship.position.distance_to(_station_pos()) > DOCK_RANGE:
		return false
	return ship.linear_velocity.length() <= DOCK_MAX_SPEED


func dock() -> bool:
	if paused or _travel_lock or docked:
		return false
	if not dock_envelope_ok():
		return false
	docked = true
	ship.controls_enabled = false
	ship.clear_commands()
	ship.linear_velocity = Vector3.ZERO
	ship.angular_velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(drone):
		var brain := drone.get_node_or_null("Brain")
		if brain:
			brain.set("player_docked", true)
	var completed: Array = missions.on_dock(str(current_system), cargo)
	for id in completed:
		hud.notice("Delivery complete — claim %d cr" % int(missions.get_mission(id).get("reward", 0)))
	gain_xp("piloting", 5)
	_customs_inspection()
	_refresh_contracts()
	ship.set("shield", float(ship.get("max_shield")))
	if is_instance_valid(audio):
		audio.play_sfx(&"dock")
	_show_station_menu()
	return true


## Customs scan: banned goods are confiscated plus a per-unit fine scaled
## by standing. A purchased blind eye is consumed to skip one inspection.
func _customs_inspection() -> void:
	var banned: Array = BANNED.get(current_system, [])
	var seized := 0
	for good in cargo.keys():
		if good in banned:
			seized += int(cargo[good])
	if seized <= 0:
		return
	if customs_pass:
		customs_pass = false
		hud.notice("Blind eye held — customs waved through")
		return
	for good in cargo.keys():
		if good in banned:
			cargo.erase(good)
	var fine := int(round((100 + 50 * seized) * fine_mult(faction_of())))
	wallet[&"credits"] = maxi(0, int(wallet.get(&"credits", 0)) - fine)
	add_standing(faction_of(), -15)
	add_heat(faction_of(), HEAT_BUST)
	hud.notice("Customs seized %d contraband — fined %d cr" % [seized, fine])


func _blind_eye_cost() -> int:
	return 200 if blind_discount else BLIND_EYE_COST


func can_blind_eye() -> bool:
	return not customs_pass and int(wallet.get(&"credits", 0)) >= _blind_eye_cost()


func buy_blind_eye() -> bool:
	if not can_blind_eye():
		return false
	wallet[&"credits"] = int(wallet.get(&"credits")) - _blind_eye_cost()
	blind_discount = false
	customs_pass = true
	_purchase_chime()
	_refresh_station_menu()
	return true


## Hull repairs for credits (shields recharge free on every docking).
## Allies of the local faction pay 25% less.
func repair_cost() -> int:
	if not is_instance_valid(ship):
		return 0
	var missing := float(ship.get("max_hull")) - float(ship.get("hull"))
	if missing <= 0.0:
		return 0
	var cost := int(ceil(missing)) * 4
	if int(standings.get(faction_of(), 0)) >= 60:
		cost = int(round(cost * 0.75))
	return cost


func repair_ship() -> bool:
	var cost := repair_cost()
	if cost <= 0 or int(wallet.get(&"credits", 0)) < cost:
		return false
	wallet[&"credits"] = int(wallet.get(&"credits")) - cost
	ship.set("hull", float(ship.get("max_hull")))
	_purchase_chime()
	_refresh_station_menu()
	return true


## Travel is time: every zone change drifts prices, restocks shelves, spoils
## one unit of carried medi-gel, and cools grudges slightly.
func _pass_time() -> void:
	for id in markets:
		markets[id].drift(econ_rng, 0.1)
		markets[id].restock(econ_rng)
	for faction in heat:
		if int(heat[faction]) > 0:
			add_heat(faction, -10)
	for faction in standings:
		var value := int(standings[faction])
		if value < 0:
			add_standing(faction, 3)
	var meds := int(cargo.get(&"medicine", 0))
	if meds > 0:
		cargo[&"medicine"] = meds - 1
		if meds - 1 <= 0:
			cargo.erase(&"medicine")


func undock() -> void:
	if not docked:
		return
	docked = false
	_hide_station_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(audio):
		audio.play_sfx(&"dock")
	if is_instance_valid(drone):
		var brain := drone.get_node_or_null("Brain")
		if brain:
			brain.set("player_docked", false)
	if is_instance_valid(ship) and not ship.destroyed_flag:
		ship.controls_enabled = true
		var away: Vector3 = (ship.position - _station_pos()).normalized()
		if away.is_zero_approx():
			away = Vector3(0, 0, 1)
		ship.linear_velocity = away * 8.0
	_maybe_spawn_hunter()


func _purchase_chime() -> void:
	if is_instance_valid(audio):
		audio.play_sfx(&"coin")


## Standing favors: +50 buys 10% cheaper and sells 10% dearer; −50 inverts.
func faction_of(system_id := &"") -> StringName:
	var key: StringName = system_id if system_id != &"" else current_system
	return SYSTEM_FACTION.get(key, &"meridian")


func standing_text(faction: StringName) -> String:
	var value := int(standings.get(faction, 0))
	return ("+" if value >= 0 else "") + str(value)


func favor_buy(faction: StringName) -> float:
	return clampf(1.0 - float(standings.get(faction, 0)) / 500.0, 0.8, 1.2)


func favor_sell(faction: StringName) -> float:
	var mult := 1.0 + float(standings.get(faction, 0)) / 500.0
	mult *= 1.0 + 0.02 * skill_rank("trade")
	return clampf(mult, 0.8, 1.3)


func fine_mult(faction: StringName) -> float:
	return clampf(1.0 - float(standings.get(faction, 0)) / 200.0, 0.5, 1.5)


func add_standing(faction: StringName, delta: int) -> void:
	standings[faction] = clampi(int(standings.get(faction, 0)) + delta, -100, 100)


## Bethesda-style reputation tiers. Hostile factions send hunters.
func rank_title(standing: int) -> String:
	if standing >= 60:
		return "Ally"
	if standing >= 25:
		return "Friend"
	if standing > -25:
		return "Neutral"
	if standing > -60:
		return "Hostile"
	return "Nemesis"


func faction_title(faction: StringName) -> String:
	return "%s %s" % [FACTION_NAMES.get(faction, "?"), rank_title(int(standings.get(faction, 0)))]


func add_heat(faction: StringName, delta: int) -> void:
	heat[faction] = clampi(int(heat.get(faction, 0)) + delta, 0, 100)


func pay_reparations() -> bool:
	var faction := faction_of()
	if int(heat.get(faction, 0)) <= 0:
		return false
	if int(wallet.get(&"credits", 0)) < REPARATION_COST:
		return false
	wallet[&"credits"] = int(wallet.get(&"credits")) - REPARATION_COST
	add_heat(faction, -REPARATION_RELIEF)
	_purchase_chime()
	_refresh_station_menu()
	return true


## ── Skills ────────────────────────────────────────────────────────────
## Use-based progression, Bethesda-style: Piloting (flight deeds),
## Mercantile (trade volume), Speechcraft (successful persuasion).

const SKILL_TIERS := [0, 50, 150, 300, 500]
const SKILL_TITLES := ["Novice", "Apprentice", "Adept", "Expert", "Master"]
const SKILL_NAMES := {"piloting": "Piloting", "trade": "Mercantile", "speech": "Speechcraft"}

var skills := {"piloting": 0, "trade": 0, "speech": 0}


func skill_rank(skill: String) -> int:
	var xp := int(skills.get(skill, 0))
	var rank := 0
	for i in SKILL_TIERS.size():
		if xp >= SKILL_TIERS[i]:
			rank = i
	return rank


func skill_title(skill: String) -> String:
	return SKILL_TITLES[skill_rank(skill)]


## Returns true on rank-up (applies the piloting bonus + notice).
func gain_xp(skill: String, amount: int) -> bool:
	if amount <= 0 or not skills.has(skill):
		return false
	var before := skill_rank(skill)
	skills[skill] = int(skills[skill]) + amount
	if skill_rank(skill) > before:
		if skill == "piloting":
			_apply_pilot_bonus()
		hud.notice("%s rank up: %s" % [SKILL_NAMES.get(skill, skill), skill_title(skill)])
		return true
	return false


## Each piloting rank is +4% handling over the active hull's base tuning.
func _apply_pilot_bonus() -> void:
	if not is_instance_valid(ship):
		return
	var hull = hulls.get(active_hull)
	if hull == null:
		return
	var mult := 1.0 + 0.04 * skill_rank("piloting")
	ship.set("thrust_acceleration", float(hull.thrust_acceleration) * mult)
	ship.set("strafe_acceleration", float(hull.strafe_acceleration) * mult)
	ship.set("brake_acceleration", float(hull.brake_acceleration) * mult)
	ship.set("maximum_speed", float(hull.maximum_speed) * mult)
	ship.set("angular_speed", float(hull.angular_speed) * mult)


func disp_of(npc: String) -> int:
	return clampi(int(disposition.get(npc, 50)), 0, 100)


func add_disp(npc: String, delta: int) -> void:
	disposition[npc] = clampi(disp_of(npc) + delta, 0, 100)


## The station merchant's disposition shades prices ±10%.
func merch_buy_mult() -> float:
	var disp := disp_of(str(STATION_MERCHANT.get(current_system, "sable")))
	return clampf(1.0 - float(disp - 50) / 500.0, 0.9, 1.1)


func merch_sell_mult() -> float:
	var disp := disp_of(str(STATION_MERCHANT.get(current_system, "sable")))
	return clampf(1.0 + float(disp - 50) / 500.0, 0.9, 1.1)


func buy_commodity(good: StringName, qty: int) -> int:
	var mult := favor_buy(faction_of()) * merch_buy_mult()
	if discounts.has(good):
		mult *= float(discounts[good])
	var result: int = _market().buy(good, qty, wallet, cargo, cargo_capacity, mult)
	if result == MarketService.TradeResult.OK:
		if discounts.has(good):
			discounts.erase(good)
		_purchase_chime()
		_refresh_station_menu()
	return result


func sell_commodity(good: StringName, qty: int) -> int:
	var result: int = _market().sell(good, qty, wallet, cargo, favor_sell(faction_of()) * merch_sell_mult())
	if result == MarketService.TradeResult.OK:
		gain_xp("trade", maxi(1, int(_market().quote(good)) * qty / 20))
		_purchase_chime()
		_refresh_station_menu()
	return result


func buy_upgrade(id: String) -> bool:
	var spec: Dictionary = UPGRADES.get(StringName(id), {})
	if spec.is_empty() or upgrades.has(id):
		return false
	if int(wallet.get(&"credits", 0)) < int(spec["cost"]):
		return false
	wallet[&"credits"] = int(wallet[&"credits"]) - int(spec["cost"])
	upgrades.append(id)
	if id == "shield_booster":
		ship.set("max_shield", float(ship.get("max_shield")) + 25.0)
		ship.set("shield", float(ship.get("shield")) + 25.0)
	elif id == "cargo_expansion":
		cargo_capacity += 10
	_purchase_chime()
	_refresh_station_menu()
	return true


func accept_delivery() -> bool:
	var ok: bool = missions.accept(MissionService.delivery_mission("delivery_ore", "ore", 6, "outer_reach", "Outer Reach", 250))
	if ok:
		_refresh_station_menu()
	return ok


func accept_bounty() -> bool:
	var ok: bool = missions.accept(MissionService.bounty_mission("bounty_drones", "Hostile drone", 2, 300))
	if ok:
		_refresh_station_menu()
	return ok


func claim_mission(id: String) -> int:
	var result: int = missions.claim(id, wallet)
	if result == MissionService.ClaimResult.OK:
		var claimed: Dictionary = missions.get_mission(id)
		if str(claimed.get("kind", "")) == "delivery":
			add_standing(faction_of(StringName(str(claimed.get("dest", "")))), 8)
		else:
			add_standing(faction_of(), 12)
		var next: Dictionary = MissionService.follow_up(id)
		if not next.is_empty() and missions.get_mission(str(next.get("id", ""))).is_empty():
			missions.missions.append(next)
			hud.notice("New work pinned: route raiders — 350 cr")
		_purchase_chime()
		_refresh_station_menu()
	return result


func buy_hull(id: String) -> bool:
	var def = hulls.get(StringName(id))
	if def == null or owned_hulls.has(id):
		return false
	if int(wallet.get(&"credits", 0)) < int(def.cost):
		return false
	wallet[&"credits"] = int(wallet.get(&"credits")) - int(def.cost)
	owned_hulls.append(id)
	_purchase_chime()
	_refresh_station_menu()
	return true


## Swap to an owned hull. The shipyard delivers it fresh (full durability);
## pose, dock state, and economy are untouched, but every ship-bound
## reference (camera, HUD, signals, drone target) is rewired.
func equip_hull(id: String) -> bool:
	if not owned_hulls.has(id) or not hulls.has(StringName(id)):
		return false
	if StringName(id) == active_hull:
		return true
	active_hull = StringName(id)
	var pose: Transform3D = ship.global_transform
	var vel: Vector3 = ship.linear_velocity
	var ang_vel: Vector3 = ship.angular_velocity
	ship.free()
	_build_ship()
	ship.global_transform = pose
	ship.linear_velocity = vel
	ship.angular_velocity = ang_vel
	ship.repair_full()
	ship.controls_enabled = not docked and not get_tree().paused
	_apply_pilot_bonus()
	_recalc_capacity()
	hud.ship = ship
	hud.camera = camera
	ship.connect("damaged", Callable(hud, "flash_damage"))
	ship.connect("destroyed", _on_player_destroyed)
	ship.reset_completed.connect(_reset_course)
	if is_instance_valid(drone):
		var brain := drone.get_node_or_null("Brain")
		if brain:
			brain.set("player", ship)
	_refresh_station_menu()
	return true


## ── Starmap ───────────────────────────────────────────────────────────
## Real-time overlay (flight continues while browsing). Shows systems,
## station prices, and links; plotting a linked destination guides the HUD
## to the local jump ring. Jumping still requires flying the gate.

var _map_selected := &""


func _build_map(layer: CanvasLayer) -> void:
	_map_panel = PanelContainer.new()
	_map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_map_panel.offset_left = -360
	_map_panel.offset_top = -260
	_map_panel.offset_right = 360
	_map_panel.offset_bottom = 260
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a1420")
	style.border_color = Color("397770")
	style.set_border_width_all(1)
	style.set_content_margin_all(20)
	style.set_corner_radius_all(8)
	_map_panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	_map_panel.add_child(stack)
	var title := Label.new()
	title.text = "STAR MAP"
	title.add_theme_font_size_override("font_size", 24)
	stack.add_child(title)
	_map_rows = VBoxContainer.new()
	_map_rows.add_theme_constant_override("separation", 6)
	stack.add_child(_map_rows)
	_map_detail = Label.new()
	_map_detail.add_theme_font_size_override("font_size", 15)
	_map_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_map_detail)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	stack.add_child(footer)
	footer.add_child(_button("Plot course", plot_course))
	footer.add_child(_button("Close  /  M", close_map))
	layer.add_child(_map_panel)
	_map_panel.hide()


func open_map() -> void:
	if paused or docked:
		return
	map_open = true
	_map_selected = current_system
	_refresh_map()
	_map_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_map() -> void:
	map_open = false
	if is_instance_valid(_map_panel):
		_map_panel.hide()
	if not docked and not paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func select_system(id: String) -> void:
	if systems.has(StringName(id)):
		_map_selected = StringName(id)
		_refresh_map()


## Breadth-first route over the jump network, origin included.
## Returns [] when destination equals origin or no path exists.
func find_route(from_id: StringName, to_id: StringName) -> Array:
	if from_id == to_id or not systems.has(from_id) or not systems.has(to_id):
		return []
	var prev := {from_id: &""}
	var queue: Array = [from_id]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		for link in (systems[cur].links as Array):
			var lid := StringName(link)
			if prev.has(lid) or not systems.has(lid):
				continue
			prev[lid] = cur
			if lid == to_id:
				var path := [to_id]
				var step: StringName = to_id
				while prev[step] != &"":
					step = prev[step]
					path.push_front(step)
				return path
			queue.append(lid)
	return []


func plot_course() -> void:
	if _map_selected == &"" or _map_selected == current_system:
		nav_route = []
		hud.notice("You are here")
		_refresh_map()
		return
	var path: Array = find_route(current_system, _map_selected)
	if path.is_empty():
		nav_route = []
		hud.notice("No route")
	else:
		nav_route = path.slice(1)
		hud.notice("Course plotted — %d jump%s" % [nav_route.size(), "" if nav_route.size() == 1 else "s"])
	_refresh_map()


func _refresh_map() -> void:
	if not is_instance_valid(_map_panel):
		return
	for child in _map_rows.get_children():
		_map_rows.remove_child(child)
		child.queue_free()
	for id in systems:
		var def = systems[id]
		var marker := "● " if id == current_system else "○ "
		var plotted := "  [PLOTTED]" if StringName(id) in nav_route else ""
		_map_rows.add_child(_button("%s%s%s" % [marker, def.display_name, plotted], select_system.bind(str(id))))
	_map_detail.text = _system_brief(_map_selected)


func _system_brief(id: StringName) -> String:
	var def = systems.get(id)
	if def == null:
		return "Unknown system."
	var market = markets.get(id)
	var lines: PackedStringArray = [
		"%s — %s" % [def.display_name, def.sub_name],
		"Station: %s" % def.station_name,
		"Market: water %d, ore %d, medicine %d" % [market.quote(&"water"), market.quote(&"ore"), market.quote(&"medicine")],
	]
	var link_names: PackedStringArray = []
	for link in (def.links as Array):
		link_names.append(str(systems[link].display_name) if systems.has(link) else str(link))
	lines.append("Links: %s" % " · ".join(link_names))
	var map_faction: StringName = SYSTEM_FACTION.get(id, &"meridian")
	lines.append("Standing: %s" % faction_title(map_faction))
	lines.append("Heat: %d" % int(heat.get(map_faction, 0)))
	if not nav_route.is_empty():
		var stops: PackedStringArray = [str(systems[current_system].display_name)]
		for hop in nav_route:
			stops.append(str(systems[StringName(hop)].display_name))
		lines.append("Route: %s" % " → ".join(stops))
	if id == current_system:
		lines.append("You are here.")
	elif StringName(id) in nav_route:
		lines.append("Plotted. Follow the cyan marker to the jump ring.")
	return "\n".join(lines)


func _on_player_destroyed() -> void:
	ship.controls_enabled = false
	ship.clear_commands()
	_spawn_explosion(ship.position, 3.0, Color("e05a4e"))
	if upgrades.has("insurance"):
		upgrades.erase("insurance")
		hud.notice("Insurance covered the cargo")
	elif not cargo.is_empty():
		cargo.clear()
		hud.notice("Cargo lost in the wreck")
	if is_instance_valid(audio):
		audio.play_sfx(&"explosion")


## Expanding flash sphere, tweened out and freed. Added to the sandbox root
## (never the zone) so zone switches cannot strand it.
func _spawn_explosion(at: Vector3, radius: float, color: Color) -> void:
	var boom := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	boom.mesh = mesh
	boom.material_override = _material(color, true)
	boom.position = at
	add_child(boom)
	var tw := create_tween()
	tw.tween_property(boom, "scale", Vector3.ONE * 2.5, 0.5)
	tw.tween_callback(boom.queue_free)


func _on_combatant_destroyed(body: RigidBody3D) -> void:
	# destroyed emits exactly once per kill, so this cannot double-count.
	kills += 1
	hud.kills = kills
	gain_xp("piloting", 8)
	_spawn_explosion(body.position, 2.0, Color("ff9a3c"))
	if is_instance_valid(audio):
		audio.play_sfx(&"explosion")
	for id in missions.on_kill():
		hud.notice("Bounty complete — claim %d cr" % int(missions.get_mission(id).get("reward", 0)))
	if body == hunter:
		hud.notice("Hunter down  (%d)" % kills)
		add_heat(faction_of(), HEAT_HUNTER_KILL)
		hunter.queue_free()
		hunter = null
		if is_instance_valid(hud):
			hud.hunter = null
	else:
		hud.notice("Drone destroyed  (%d)" % kills)
		drone.visible = false
		drone.controls_enabled = false
		_respawn_left = DRONE_RESPAWN_DELAY


func _reset_drone() -> void:
	_respawn_left = 0.0
	_place_ship(drone)
	drone.repair_full()
	drone.visible = true
	drone.controls_enabled = true


func _respawn_drone() -> void:
	_reset_drone()
	hud.notice("Hostile drone inbound")

func _build_pause_menu(layer: CanvasLayer) -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -210
	_pause_panel.offset_top = -232
	_pause_panel.offset_right = 210
	_pause_panel.offset_bottom = 232
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
	_pause_info = Label.new()
	_pause_info.add_theme_font_size_override("font_size", 13)
	stack.add_child(_pause_info)
	_resume_button = _button("Resume flight  /  ESC", func(): set_paused(false))
	stack.add_child(_resume_button)
	stack.add_child(_button("Restart course", _restart))
	stack.add_child(_button("Save ship", save_ship))
	stack.add_child(_button("Load ship", load_ship))
	stack.add_child(_button("Exit Flight Lab", func(): get_tree().quit()))
	layer.add_child(_pause_panel)
	_pause_panel.hide()

## ── Station menu ──────────────────────────────────────────────────────

func _build_station_menu(layer: CanvasLayer) -> void:
	_station_panel = PanelContainer.new()
	_station_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_station_panel.offset_left = -360
	_station_panel.offset_top = -260
	_station_panel.offset_right = 360
	_station_panel.offset_bottom = 260
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0c1929")
	style.border_color = Color("397770")
	style.set_border_width_all(1)
	style.set_content_margin_all(20)
	style.set_corner_radius_all(8)
	_station_panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	_station_panel.add_child(stack)
	_station_title = Label.new()
	_station_title.add_theme_font_size_override("font_size", 24)
	stack.add_child(_station_title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	stack.add_child(tabs)
	tabs.add_child(_button("Market", _show_station_tab.bind(&"market")))
	tabs.add_child(_button("Outfitting", _show_station_tab.bind(&"outfit")))
	tabs.add_child(_button("Shipyard", _show_station_tab.bind(&"shipyard")))
	tabs.add_child(_button("Missions", _show_station_tab.bind(&"missions")))
	tabs.add_child(_button("Contacts", _show_station_tab.bind(&"contacts")))
	tabs.add_child(_button("Terminal", _show_station_tab.bind(&"terminal")))
	tabs.add_child(_button("Undock  /  X", undock))
	_market_tab = _station_tab(stack)
	_outfit_tab = _station_tab(stack)
	_ship_tab = _station_tab(stack)
	_mission_tab = _station_tab(stack)
	_contacts_tab = _station_tab(stack)
	_lore_tab = _station_tab(stack)
	layer.add_child(_station_panel)
	_station_panel.hide()


func _station_tab(stack: VBoxContainer) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.add_theme_constant_override("separation", 6)
	stack.add_child(tab)
	tab.hide()
	return tab


## One info row: expanding label plus [text, action] buttons.
func _station_row(parent: VBoxContainer, text: String, buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	for spec in buttons:
		row.add_child(_button(str(spec[0]), spec[1]))


func _clear_tab(tab: VBoxContainer) -> void:
	for child in tab.get_children():
		tab.remove_child(child)
		child.queue_free()


func _show_station_menu() -> void:
	_station_title.text = "%s — DOCKED" % _station_name()
	_station_panel.show()
	_show_station_tab(&"market")


func _hide_station_menu() -> void:
	if is_instance_valid(_station_panel):
		_station_panel.hide()


func _show_station_tab(which: StringName) -> void:
	_market_tab.hide()
	_outfit_tab.hide()
	_ship_tab.hide()
	_mission_tab.hide()
	_contacts_tab.hide()
	_lore_tab.hide()
	match which:
		&"market":
			_populate_market_tab()
			_market_tab.show()
		&"outfit":
			_populate_outfit_tab()
			_outfit_tab.show()
		&"shipyard":
			_populate_ship_tab()
			_ship_tab.show()
		&"missions":
			_populate_mission_tab()
			_mission_tab.show()
		&"contacts":
			_dialogue_session = {}
			_populate_contacts_tab()
			_contacts_tab.show()
		&"terminal":
			_populate_lore_tab()
			_lore_tab.show()


func _refresh_station_menu() -> void:
	if not is_instance_valid(_station_panel) or not _station_panel.visible:
		return
	_populate_market_tab()
	_populate_outfit_tab()
	_populate_ship_tab()
	_populate_mission_tab()
	if _contacts_tab.visible:
		_populate_contacts_tab()


func _populate_lore_tab() -> void:
	_clear_tab(_lore_tab)
	for entry in LORE:
		_station_row(_lore_tab, "%s — %s" % [entry["title"], entry["text"]], [])


func _populate_contacts_tab() -> void:
	_clear_tab(_contacts_tab)
	if _dialogue_session.is_empty():
		_update_dialogue_context()
		for npc in (contacts.get(current_system, []) as Array):
			_station_row(_contacts_tab, "%s (%s)" % [npc["name"], npc["role"]], [["Talk", _open_dialogue.bind(str(npc["dlg"]))]])
	else:
		var node: Dictionary = dialogue.current()
		if node.is_empty():
			_dialogue_session = {}
			_populate_contacts_tab()
			return
		_station_row(_contacts_tab, "%s: %s" % [node.get("speaker", ""), node.get("text", "")], [])
		var choices: Array = node.get("choices", [])
		if choices.is_empty():
			_station_row(_contacts_tab, "", [["Leave", _close_dialogue]])
		else:
			for i in choices.size():
				_station_row(_contacts_tab, "", [[str(choices[i].get("text", "")), _choose_dialogue.bind(i)]])


func _open_dialogue(id: String) -> void:
	_update_dialogue_context()
	_dialogue_session = {"def": id}
	dialogue.start(id)
	_populate_contacts_tab()


func _close_dialogue() -> void:
	_dialogue_session = {}
	_populate_contacts_tab()


## Speechcraft check: d100 under chance (skill + disposition − difficulty).
func persuade_chance(dc: int, npc: String) -> float:
	var chance := 50.0 + 10.0 * skill_rank("speech") + float(disp_of(npc) - 50) / 5.0 - float(dc)
	return clampf(chance, 5.0, 95.0)


func _persuade_roll(dc: int, npc: String) -> bool:
	var roll := social_rigged
	if roll < 0.0:
		roll = social_rng.randf_range(0.0, 100.0)
	else:
		social_rigged = -1.0
	return roll < persuade_chance(dc, npc)


func can_bribe(do: String) -> bool:
	return int(wallet.get(&"credits", 0)) >= int(do.trim_prefix("bribe:"))


func _choose_dialogue(index: int) -> void:
	# Preview priced effects before advancing so broke choices hold position.
	var preview: Dictionary = dialogue.current()
	var preview_choices: Array = preview.get("choices", [])
	if index < 0 or index >= preview_choices.size():
		return
	var preview_effect := str(preview_choices[index].get("do", ""))
	if preview_effect == "blindeye" and not can_blind_eye():
		hud.notice("Need 300 cr for the blind eye")
		_populate_contacts_tab()
		return
	if preview_effect.begins_with("bribe:") and not can_bribe(preview_effect):
		hud.notice("Not enough credits for the bribe")
		_populate_contacts_tab()
		return
	var npc := str(_dialogue_session.get("def", ""))
	if str(preview_choices[index].get("check", "")) == "speech":
		var dc := int(preview_choices[index].get("dc", 30))
		if not _persuade_roll(dc, npc):
			add_disp(npc, -5)
			var fail_to := str(preview_choices[index].get("fail_to", ""))
			if fail_to != "":
				dialogue.go(fail_to)
			_populate_contacts_tab()
			return
		add_disp(npc, 10)
		gain_xp("speech", 15)
	var result: Dictionary = dialogue.choose(index)
	_apply_dialogue_effect(str(result.get("effect", "")), npc)
	if str(result.get("effect", "")) == "leave" or (result.get("node") as Dictionary).is_empty():
		_dialogue_session = {}
	_populate_contacts_tab()


func _apply_dialogue_effect(do: String, npc: String) -> void:
	if do.begins_with("accept:"):
		accept_dialogue_mission(do.trim_prefix("accept:"))
	elif do == "blindeye":
		buy_blind_eye()
	elif do.begins_with("bribe:"):
		var amt := int(do.trim_prefix("bribe:"))
		wallet[&"credits"] = int(wallet.get(&"credits", 0)) - amt
		add_disp(npc, 15)
		gain_xp("speech", 5)
	elif do == "contract":
		_effect_contract()
	elif do == "pardon":
		var faction := faction_of()
		heat[faction] = maxi(0, int(heat.get(faction, 0)) - 20)
	elif do.begins_with("discount:"):
		discounts[StringName(do.trim_prefix("discount:"))] = 0.8
	elif do == "freebie":
		var space := cargo_capacity - _cargo_total()
		var gift := mini(2, space)
		if gift > 0:
			cargo[&"water"] = int(cargo.get(&"water", 0)) + gift
		ship.set("hull", minf(float(ship.get("max_hull")), float(ship.get("hull")) + 15.0))
	elif do == "blind200":
		blind_discount = true
	# "admire" and "leave" need no extra handling beyond disposition/session.


func _cargo_total() -> int:
	var total := 0
	for good in cargo:
		total += int(cargo[good])
	return total


func _populate_market_tab() -> void:
	_clear_tab(_market_tab)
	var used := 0
	for good in cargo:
		used += int(cargo[good])
	_station_row(_market_tab, "Credits: %d cr      Hold: %d / %d      %s" % [int(wallet.get(&"credits", 0)), used, cargo_capacity, faction_title(faction_of())], [])
	for good in commodities:
		var id: StringName = good.id
		var text := "%s — %d cr (stock %d) — hold %d" % [good.display_name, _market().quote(id), _market().stock_of(id), int(cargo.get(id, 0))]
		_station_row(_market_tab, text, [
			["Buy 1", buy_commodity.bind(id, 1)],
			["Buy 10", buy_commodity.bind(id, 10)],
			["Sell 1", sell_commodity.bind(id, 1)],
			["Sell 10", sell_commodity.bind(id, 10)],
		])


func _populate_outfit_tab() -> void:
	_clear_tab(_outfit_tab)
	var damage_cost := repair_cost()
	if damage_cost > 0:
		var missing := int(ceil(float(ship.get("max_hull")) - float(ship.get("hull"))))
		_station_row(_outfit_tab, "Repair Hull (%d dmg) — %d cr" % [missing, damage_cost], [["Repair", repair_ship]])
	else:
		_station_row(_outfit_tab, "Hull intact.", [])
	for id in UPGRADES:
		var spec: Dictionary = UPGRADES[id]
		var owned: bool = upgrades.has(str(id))
		var text := "%s (%s) — %d cr%s" % [spec["name"], spec["desc"], int(spec["cost"]), " — OWNED" if owned else ""]
		if owned:
			_station_row(_outfit_tab, text, [])
		else:
			_station_row(_outfit_tab, text, [["Buy", buy_upgrade.bind(str(id))]])


func _populate_ship_tab() -> void:
	_clear_tab(_ship_tab)
	for id in hulls:
		var def = hulls[id]
		var text := "%s — %s [%d m/s, %d hull, %d shield] — %d cr" % [
			def.display_name, def.description,
			int(def.maximum_speed), int(def.max_hull), int(def.max_shield), int(def.cost)]
		if StringName(id) == active_hull:
			_station_row(_ship_tab, text + " — ACTIVE", [])
		elif owned_hulls.has(str(id)):
			_station_row(_ship_tab, text, [["Equip", equip_hull.bind(str(id))]])
		else:
			_station_row(_ship_tab, text, [["Buy", buy_hull.bind(str(id))]])


func _populate_mission_tab() -> void:
	_clear_tab(_mission_tab)
	if mission_offers.is_empty():
		_station_row(_mission_tab, "No contracts on the board.", [])
	else:
		for offer in mission_offers:
			_station_row(_mission_tab, _offer_text(offer), [["Accept", accept_offer.bind(str(offer.get("id", "")))]])
	var delivery: Dictionary = missions.get_mission("delivery_ore")
	if delivery.is_empty():
		_station_row(_mission_tab, "Deliver 6 Titanium Ore to Outer Reach — 250 cr", [["Accept", accept_delivery]])
	elif bool(delivery.get("claimed", false)):
		_station_row(_mission_tab, "Ore delivery — CLAIMED", [])
	elif bool(delivery.get("complete", false)):
		_station_row(_mission_tab, "Ore delivery ready — 250 cr", [["Claim", claim_mission.bind("delivery_ore")]])
	else:
		_station_row(_mission_tab, "Deliver 6 Titanium Ore to Outer Reach — 250 cr (hold %d/6)" % int(cargo.get(&"ore", 0)), [])
	var bounty: Dictionary = missions.get_mission("bounty_drones")
	if bounty.is_empty():
		_station_row(_mission_tab, "Destroy 2 hostile drones — 300 cr", [["Accept", accept_bounty]])
	elif bool(bounty.get("claimed", false)):
		_station_row(_mission_tab, "Drone bounty — CLAIMED", [])
	elif bool(bounty.get("complete", false)):
		_station_row(_mission_tab, "Drone bounty ready — 300 cr", [["Claim", claim_mission.bind("bounty_drones")]])
	else:
		_station_row(_mission_tab, "Destroy 2 hostile drones — 300 cr (%d/2)" % int(bounty.get("kills", 0)), [])
	var heat_here := int(heat.get(faction_of(), 0))
	if heat_here > 0:
		_station_row(_mission_tab, "Heat: %d — clear %d for %d cr" % [heat_here, mini(REPARATION_RELIEF, heat_here), REPARATION_COST], [["Pay", pay_reparations]])


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

func _build_hulls() -> void:
	var sparrow := HullDefinition.new()
	sparrow.id = &"sparrow"
	sparrow.display_name = "Sparrow"
	sparrow.description = "Nimble courier. Standard fitting."
	sparrow.cost = 0
	hulls[sparrow.id] = sparrow
	var mule := HullDefinition.new()
	mule.id = &"mule"
	mule.display_name = "Mule"
	mule.description = "Slow freighter. Hauls +20 cargo."
	mule.cost = 800
	mule.thrust_acceleration = 16.0
	mule.strafe_acceleration = 11.0
	mule.maximum_speed = 85.0
	mule.angular_speed = 1.0
	mule.max_shield = 40.0
	mule.max_hull = 150.0
	mule.cargo_bonus = 20
	mule.hull_tint = Color("b09a6a")
	mule.wing_tint = Color("5e6b7a")
	hulls[mule.id] = mule


func _recalc_capacity() -> void:
	cargo_capacity = START_CARGO_CAPACITY
	if upgrades.has("cargo_expansion"):
		cargo_capacity += 10
	var hull = hulls.get(active_hull)
	if hull:
		cargo_capacity += int(hull.cargo_bonus)


func _build_ship() -> void:
	var def = hulls.get(active_hull, HullDefinition.new())
	_thrusters.clear()
	ship = ShipController.new()
	ship.name = "PlayerShip"
	ship.mass = 1.0
	ship.thrust_acceleration = def.thrust_acceleration
	ship.strafe_acceleration = def.strafe_acceleration
	ship.brake_acceleration = def.brake_acceleration
	ship.maximum_speed = def.maximum_speed
	ship.angular_speed = def.angular_speed
	ship.angular_response = def.angular_response
	ship.max_shield = def.max_shield
	ship.max_hull = def.max_hull
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
	hull.material_override = _material(def.hull_tint)
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
		wing.material_override = _material(def.wing_tint)
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
	camera.position = Vector3(0, 0.5, 0.5)
	camera.rotation_degrees.x = 0
	camera.fov = 75
	camera.far = 6000
	camera.current = true
	ship.add_child(camera)
	var laser := LaserCannon.new()
	laser.name = "Laser"
	laser.position = Vector3(0, 0.3, -2.3)
	laser.damage = 12.0
	laser.weapon_range = 300.0
	laser.cooldown = 0.25
	laser.target_group = &"hostile_drone"
	laser.fired.connect(func(_hit: bool) -> void:
		if is_instance_valid(audio):
			audio.play_sfx(&"laser"))
	ship.add_child(laser)
	ship.shield_bubble = _make_shield_bubble(2.6)
	ship.add_child(ship.shield_bubble)
	ship.add_to_group("player_ship")
	add_child(ship)


## Transparent shell flashed on hits. Hidden until the first impact.
func _make_shield_bubble(radius: float) -> MeshInstance3D:
	var bubble := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	bubble.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 0.9, 1.0, 0.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bubble.material_override = mat
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.visible = false
	return bubble

func _build_drone(hunter_body := false) -> void:
	var body := ShipController.new()
	body.name = "Hunter" if hunter_body else "Drone"
	body.mass = 1.0
	body.thrust_acceleration = 18.0 if hunter_body else 14.0
	body.strafe_acceleration = 12.0 if hunter_body else 10.0
	body.brake_acceleration = 30.0
	body.maximum_speed = 65.0 if hunter_body else 55.0
	body.angular_speed = 1.8 if hunter_body else 1.6
	body.angular_response = 7.0
	body.zone_radius = 5000.0
	body.max_shield = 40.0 if hunter_body else 25.0
	body.shield_regen_rate = 6.0 if hunter_body else 5.0
	body.shield_regen_delay = 4.0
	body.max_hull = 80.0 if hunter_body else 40.0
	body.read_player_input = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 0.7, 2.2)
	collision.shape = shape
	body.add_child(collision)
	_box(body, Vector3.ZERO, Vector3(1.2, 0.7, 2.2), Color("23232c") if hunter_body else Color("8c2f36"), false)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.22
	eye_mesh.height = 0.44
	eye.mesh = eye_mesh
	eye.position = Vector3(0, 0.1, -1.15)
	eye.material_override = _material(Color("ff2222") if hunter_body else Color("ff5a3c"), true)
	body.add_child(eye)
	var laser := LaserCannon.new()
	laser.name = "Laser"
	laser.position = Vector3(0, 0.1, -1.3)
	laser.damage = 8.0 if hunter_body else 6.0
	laser.weapon_range = 250.0
	laser.cooldown = 1.0 if hunter_body else 1.2
	laser.target_group = &"player_ship"
	laser.fire_action = &""
	laser.fired.connect(func(_hit: bool) -> void:
		if is_instance_valid(audio):
			audio.play_sfx(&"laser"))
	body.add_child(laser)
	var brain := DroneBrain.new()
	brain.name = "Brain"
	brain.player = ship
	brain.laser = laser
	if is_instance_valid(ship) and ship.get("controls_enabled") == false and docked:
		brain.set("player_docked", true)
	body.add_child(brain)
	body.shield_bubble = _make_shield_bubble(1.6)
	body.add_child(body.shield_bubble)
	body.add_to_group("hostile_drone")
	add_child(body)
	if hunter_body:
		hunter = body
	else:
		drone = body
	body.connect("destroyed", _on_combatant_destroyed.bind(body))
	_place_ship(body)


func _place_ship(body: RigidBody3D) -> void:
	body.position = Vector3(25, 6, -110)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	if is_instance_valid(ship):
		body.look_at(ship.position, Vector3.UP)


## A hostile faction (standing ≤ −25) or burning heat (≥ 50) sends a hunter.
func hunter_eligible() -> bool:
	if is_instance_valid(hunter):
		return false
	var faction := faction_of()
	return int(standings.get(faction, 0)) <= HUNTER_STANDING or int(heat.get(faction, 0)) >= HUNTER_HEAT


func _maybe_spawn_hunter() -> void:
	if hunter_eligible():
		_build_drone(true)
		hud.notice("Hunter inbound — %s wants you" % FACTION_NAMES.get(faction_of(), "?"))


func _build_environment(def, parent: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = def.bg_color
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = def.ambient_color
	world.environment.ambient_light_energy = def.ambient_energy
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = def.sun_rotation
	sun.light_color = def.sun_color
	sun.light_energy = def.sun_energy
	parent.add_child(sun)
	var rng := RandomNumberGenerator.new()
	rng.seed = def.star_seed
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
	parent.add_child(stars)
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = def.planet_radius
	sphere.height = def.planet_radius * 2.0
	planet.mesh = sphere
	planet.position = def.planet_position
	planet.material_override = _material(def.planet_color)
	parent.add_child(planet)

func _build_course(def, parent: Node3D) -> void:
	_gate_labels.clear()
	course.gates.clear()
	var course_root := Node3D.new()
	course_root.name = "TrainingCourse"
	parent.add_child(course_root)
	for i in def.gate_count:
		var center := Vector3(sin(i * 0.65 + def.gate_phase) * 22, sin(i * 0.9 + def.gate_phase) * 12, -60 - i * def.gate_spacing)
		course.gates.append(center)
		var color: Color = def.accent_a if i % 2 == 0 else def.accent_b
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
		_box(course_root, at, Vector3(8, 6, 10), def.obstacle_color)
	# Sparse reference grid provides motion cues without an infinite world.
	for i in range(-8, 9):
		_box(course_root, Vector3(i * 25, -30, -250), Vector3(0.12, 0.12, 600), Color("234358"), false)
		_box(course_root, Vector3(0, -30, i * 40 - 250), Vector3(400, 0.12, 0.12), Color("234358"), false)


## Surface zone: day sky, solid ground plane, pad cluster, habitat blocks,
## and a mountain ring silhouette. Flight stays zero-G (hover) for now.
func _build_surface(def, parent: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = def.surface_sky
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("e8c39a")
	world.environment.ambient_light_energy = 0.9
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-12, 55, 0)
	sun.light_color = Color("ffd9a8")
	sun.light_energy = 1.6
	parent.add_child(sun)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.position = Vector3(0, -2, -100)
	parent.add_child(ground)
	_box(ground, Vector3.ZERO, Vector3(2200, 4, 1600), def.ground_color)
	for i in 3:
		var pad := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 6.0
		disc.bottom_radius = 6.0
		disc.height = 0.4
		pad.mesh = disc
		pad.position = Vector3(-40 + i * 40, 0.2, 60)
		pad.material_override = _material(def.accent_a, true)
		parent.add_child(pad)
	for i in 7:
		var h := 14.0 + (i % 3) * 10.0
		_box(parent, Vector3(-70 + i * 22, h / 2.0, -40 - (i % 2) * 30), Vector3(14, h, 14), def.obstacle_color)
	for i in 10:
		var angle := TAU * i / 10.0
		_box(parent, Vector3(cos(angle) * 850.0, 40, -100 + sin(angle) * 650.0), Vector3(180, 120 + (i % 3) * 60.0, 180), Color("4a3040"), false)
	var label := Label3D.new()
	label.text = def.display_name
	label.position = Vector3(0, 34, 0)
	label.font_size = 64
	label.pixel_size = 0.06
	parent.add_child(label)


## Amber beacon marking the atmospheric entry point. Purely visual; land()
## is proximity-gated like the jump ring.
func _build_landing_beacon(def, parent: Node3D) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 8.0
	torus.rings = 36
	torus.ring_segments = 10
	ring.mesh = torus
	ring.position = def.landing_beacon
	ring.material_override = _material(Color("e8b16b"), true)
	parent.add_child(ring)
	var label := Label3D.new()
	label.text = "LAND  ↓  %s" % systems[def.landing_target].display_name
	label.position = def.landing_beacon + Vector3(0, 13, 0)
	label.font_size = 48
	label.pixel_size = 0.06
	label.modulate = Color("e8b16b")
	parent.add_child(label)


## Station structure with landing pads and a name beacon. Docking is a
## proximity/speed interaction handled by dock(); the mesh is a solid
## StaticBody so careless approaches still collide.
func _build_station(def, parent: Node3D) -> void:
	var root := StaticBody3D.new()
	root.name = "Station"
	root.position = def.station_position
	parent.add_child(root)
	_box(root, Vector3.ZERO, Vector3(44, 10, 44), Color("3a4c63"))
	_box(root, Vector3(0, 7, 0), Vector3(20, 4, 20), Color("22303f"))
	for i in 4:
		var pad := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 4.0
		disc.bottom_radius = 4.0
		disc.height = 0.4
		pad.mesh = disc
		pad.position = Vector3(-12 + 24 * (i % 2), 5.3, -12 + 24 * (i / 2))
		pad.material_override = _material(Color("65dacf"), true)
		root.add_child(pad)
	var beacon := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 1.6
	orb.height = 3.2
	beacon.mesh = orb
	beacon.position = Vector3(0, 14, 0)
	beacon.material_override = _material(Color("e8b16b"), true)
	root.add_child(beacon)
	var label := Label3D.new()
	label.text = def.station_name
	label.position = Vector3(0, 20, 0)
	label.font_size = 48
	label.pixel_size = 0.06
	root.add_child(label)


## Visible jump ring marking this zone's hyperspace exit. Purely visual;
## the jump itself is proximity-gated input handled by _try_jump_from_gate().
func _build_jump_gate(def, parent: Node3D) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 1.2
	torus.outer_radius = 12.0
	torus.rings = 48
	torus.ring_segments = 12
	var glow := _material(def.accent_a, true)
	for link in (def.links as Array):
		var dest := StringName(link)
		if not systems.has(dest):
			continue
		var gate := MeshInstance3D.new()
		gate.mesh = torus
		gate.material_override = glow
		gate.position = gate_pos_for(def, dest)
		parent.add_child(gate)
		var label := Label3D.new()
		label.text = "JUMP  →  %s" % systems[dest].display_name
		label.position = gate.position + Vector3(0, 17, 0)
		label.font_size = 48
		label.pixel_size = 0.06
		label.modulate = def.accent_a
		parent.add_child(label)

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
