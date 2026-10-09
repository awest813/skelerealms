extends RefCounted
## Plain-data snapshot of a ship: durability, transform, and velocities.
##
## Lives in the sandbox with no framework dependencies. The future framework
## adapter can feed these fields through SaveSystem hooks; the JSON format is
## versioned so that migration path stays open.
const FORMAT_VERSION := 6

var hull := 100.0
var shield := 50.0
var max_hull := 100.0
var max_shield := 50.0
var system_id := &""
var position := Vector3.ZERO
var rotation := Quaternion.IDENTITY
var linear_velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO
# Player-level economy: the sandbox fills these in before saving.
var credits := 0
var cargo := {}
var cargo_capacity := 20
var upgrades: Array = []
var missions: Array = []
var hull_id := &"sparrow"
var owned_hulls: Array = [&"sparrow"]
var markets := {}
var mission_offers: Array = []
var standings := {}
var customs_pass := false
var skills := {}
var disposition := {}
var heat := {}


## Capture a snapshot from any body running ship_controller.gd.
static func snapshot(ship: RigidBody3D, system_id := &"") -> RefCounted:
	var script := load("res://ship_state.gd")
	var state: RefCounted = script.new()
	state.hull = float(ship.get("hull"))
	state.shield = float(ship.get("shield"))
	state.max_hull = float(ship.get("max_hull"))
	state.max_shield = float(ship.get("max_shield"))
	state.system_id = system_id
	state.position = ship.global_position
	state.rotation = ship.global_transform.basis.get_rotation_quaternion()
	state.linear_velocity = ship.linear_velocity
	state.angular_velocity = ship.angular_velocity
	return state


## Restore durability and pose onto a ship body.
func apply_to(ship: RigidBody3D) -> void:
	ship.set("max_hull", max_hull)
	ship.set("max_shield", max_shield)
	ship.set("hull", minf(hull, max_hull))
	ship.set("shield", minf(shield, max_shield))
	ship.set("destroyed_flag", hull <= 0.0)
	ship.global_position = position
	ship.global_transform = Transform3D(Basis(rotation), position)
	ship.linear_velocity = linear_velocity
	ship.angular_velocity = angular_velocity


func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"hull": hull,
		"shield": shield,
		"max_hull": max_hull,
		"max_shield": max_shield,
		"system_id": str(system_id),
		"credits": credits,
		"cargo": _cargo_to_json(),
		"cargo_capacity": cargo_capacity,
		"upgrades": upgrades.duplicate(),
		"missions": missions.duplicate(true),
		"hull_id": str(hull_id),
		"owned_hulls": owned_hulls.duplicate(),
		"markets": _markets_to_json(),
		"mission_offers": mission_offers.duplicate(true),
		"standings": _strmap_to_json(standings),
		"customs_pass": customs_pass,
		"skills": _strmap_to_json(skills),
		"disposition": _strmap_to_json(disposition),
		"heat": _strmap_to_json(heat),
		"position": [position.x, position.y, position.z],
		"rotation": [rotation.x, rotation.y, rotation.z, rotation.w],
		"linear_velocity": [linear_velocity.x, linear_velocity.y, linear_velocity.z],
		"angular_velocity": [angular_velocity.x, angular_velocity.y, angular_velocity.z],
	}


## StringName cargo keys become plain Strings in JSON; normalize them back.
static func _cargo_from_json(data: Dictionary) -> Dictionary:
	var cargo := {}
	for key in data:
		cargo[StringName(str(key))] = int(data[key])
	return cargo


func _cargo_to_json() -> Dictionary:
	var out := {}
	for key in cargo:
		out[str(key)] = int(cargo[key])
	return out


func _markets_to_json() -> Dictionary:
	var out := {}
	for system in markets:
		var entry: Dictionary = markets[system]
		var stock := {}
		for key in (entry.get("stock", {}) as Dictionary):
			stock[str(key)] = int((entry["stock"] as Dictionary)[key])
		var prices := {}
		for key in (entry.get("prices", {}) as Dictionary):
			prices[str(key)] = int((entry["prices"] as Dictionary)[key])
		out[str(system)] = {"stock": stock, "prices": prices}
	return out


func _strmap_to_json(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		out[str(key)] = int(data[key])
	return out


static func _standing_from_json(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		out[StringName(str(key))] = int(data[key])
	return out


static func _markets_from_json(data: Dictionary) -> Dictionary:
	var out := {}
	for system in data:
		var entry: Dictionary = data[system]
		out[StringName(str(system))] = {
			"stock": _cargo_from_json(entry.get("stock", {})),
			"prices": _cargo_from_json(entry.get("prices", {})),
		}
	return out


static func from_dict(data: Dictionary) -> RefCounted:
	var script := load("res://ship_state.gd")
	var state: RefCounted = script.new()
	var version := int(data.get("format_version", 0))
	if version < 1 or version > FORMAT_VERSION:
		return null
	state.hull = float(data.get("hull", state.hull))
	state.shield = float(data.get("shield", state.shield))
	state.max_hull = float(data.get("max_hull", state.max_hull))
	state.max_shield = float(data.get("max_shield", state.max_shield))
	state.system_id = StringName(str(data.get("system_id", "")))
	if version >= 2:
		state.credits = int(data.get("credits", 0))
		var stored_cargo: Dictionary = data.get("cargo", {})
		state.cargo = _cargo_from_json(stored_cargo)
		state.cargo_capacity = int(data.get("cargo_capacity", state.cargo_capacity))
		state.upgrades = (data.get("upgrades", []) as Array).duplicate()
		state.missions = (data.get("missions", []) as Array).duplicate(true)
	if version >= 3:
		state.hull_id = StringName(str(data.get("hull_id", "sparrow")))
		var hulls: Array = []
		for id in (data.get("owned_hulls", []) as Array):
			hulls.append(str(id))
		state.owned_hulls = hulls
	if version >= 4:
		state.markets = _markets_from_json(data.get("markets", {}))
		state.mission_offers = (data.get("mission_offers", []) as Array).duplicate(true)
	if version >= 5:
		state.standings = _standing_from_json(data.get("standings", {}))
		state.customs_pass = bool(data.get("customs_pass", false))
	if version >= 6:
		state.skills = _standing_from_json(data.get("skills", {}))
		state.disposition = _standing_from_json(data.get("disposition", {}))
		state.heat = _standing_from_json(data.get("heat", {}))
	var pos: Array = data.get("position", [])
	if pos.size() >= 3:
		state.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	var rot: Array = data.get("rotation", [])
	if rot.size() >= 4:
		state.rotation = Quaternion(float(rot[0]), float(rot[1]), float(rot[2]), float(rot[3]))
	var lin: Array = data.get("linear_velocity", [])
	if lin.size() >= 3:
		state.linear_velocity = Vector3(float(lin[0]), float(lin[1]), float(lin[2]))
	var ang: Array = data.get("angular_velocity", [])
	if ang.size() >= 3:
		state.angular_velocity = Vector3(float(ang[0]), float(ang[1]), float(ang[2]))
	return state


## Persist to a user:// path. Returns false on write failure.
func save_to(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict()))
	return file.get_error() == OK


## Load from a user:// path. Returns null on missing/corrupt/versioned data.
static func load_from(path: String) -> RefCounted:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return null
	var script := load("res://ship_state.gd")
	return script.from_dict(parsed as Dictionary)
