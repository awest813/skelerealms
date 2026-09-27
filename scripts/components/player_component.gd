class_name PlayerComponent
extends SKEntityComponent
## Player component.


var _connected_puppet: Node3D
var _travel_loader: WorldLoader
var _arrival_world: String
var _arrival_position: Vector3

## Per-damage-type resistance modifiers. Keys are StringName damage types,
## values are multipliers (1.0 = full damage, 0.5 = half damage, 0.0 = immune).
## Any damage type not listed here uses a multiplier of 1.0.
@export var damage_modifiers:Dictionary[StringName, float] = {}


func _init() -> void:
	name = "PlayerComponent"


func _ready() -> void:
	super._ready()
	($"../TeleportComponent" as TeleportComponent).teleporting.connect(teleport.bind())
	(parent_entity.get_component("DamageableComponent") as DamageableComponent).damaged.connect(on_damage.bind())


func on_damage(info:DamageInfo) -> void:
	var vitals:VitalsComponent = parent_entity.get_component("VitalsComponent") as VitalsComponent
	if not vitals:
		return
	
	var accumulated_damage:float = 0.0
	for effect_name in info.damage_effects:
		var effect_amount:float = info.damage_effects[effect_name]
		var modifier:float = damage_modifiers.get(effect_name, 1.0)
		match effect_name:
			&"moxie":
				vitals.change_moxie(-effect_amount * modifier)
			&"will":
				vitals.change_will(-effect_amount * modifier)
			_:
				accumulated_damage += effect_amount * modifier
	
	if not is_zero_approx(accumulated_damage):
		vitals.change_health(-accumulated_damage)
	
	# Apply spell effects
	var spell_target:SpellTargetComponent = parent_entity.get_component("SpellTargetComponent") as SpellTargetComponent
	if spell_target:
		for eff in info.spell_effects:
			spell_target.add_effect(eff)


## Set the entity's position.
func set_entity_position(pos:Vector3) -> void:
	parent_entity.position = pos


func set_entity_rotation(q:Quaternion) -> void:
	parent_entity.rotation = q


func _process(_delta: float) -> void:
	if GameInfo.is_loading:
		return
	parent_entity.world = str(GameInfo.world)
	var puppet: Node3D = $"../PuppetSpawnerComponent".puppet as Node3D
	if not is_instance_valid(puppet):
		return
	if puppet != _connected_puppet:
		_connected_puppet = puppet
		if puppet.has_signal("update_position") and not puppet.is_connected("update_position", set_entity_position):
			puppet.connect("update_position", set_entity_position)
	GameInfo.world_origin = puppet
	parent_entity.rotation = puppet.quaternion


## Change world first; apply arrival only after a successful commit.
func teleport(world: String, pos: Vector3) -> void:
	if GameInfo.is_loading:
		return
	var loader := get_tree().root.find_child("WorldLoader", true, false) as WorldLoader
	if not loader:
		push_error("PlayerComponent: no WorldLoader in the game tree.")
		return
	_travel_loader = loader
	_arrival_world = world
	_arrival_position = pos
	loader.world_loading_ready.connect(_finish_teleport)
	loader.world_loading_failed.connect(_cancel_teleport)
	if not loader.load_world(world):
		_disconnect_travel()

func _finish_teleport() -> void:
	parent_entity.world = _arrival_world
	parent_entity.position = _arrival_position
	($"../PuppetSpawnerComponent" as PuppetSpawnerComponent).set_puppet_position(_arrival_position)
	_disconnect_travel()

func _cancel_teleport(_message: String) -> void:
	_disconnect_travel()

func _disconnect_travel() -> void:
	if is_instance_valid(_travel_loader):
		if _travel_loader.world_loading_ready.is_connected(_finish_teleport):
			_travel_loader.world_loading_ready.disconnect(_finish_teleport)
		if _travel_loader.world_loading_failed.is_connected(_cancel_teleport):
			_travel_loader.world_loading_failed.disconnect(_cancel_teleport)
	_travel_loader = null
