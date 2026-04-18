class_name PlayerComponent
extends SKEntityComponent
## Player component.


var _set_up:bool

## Per-damage-type resistance modifiers. Keys are StringName damage types,
## values are multipliers (1.0 = full damage, 0.5 = half damage, 0.0 = immune).
## Any damage type not listed here uses a multiplier of 1.0.
@export var damage_modifiers:Dictionary = {}


func _init() -> void:
	name = "PlayerComponent"


func _ready():
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
func set_entity_position(pos:Vector3):
	parent_entity.position = pos


func set_entity_rotation(q:Quaternion) -> void:
	parent_entity.quaternion = q


func _process(delta):
	if not parent_entity.world == GameInfo.world:
		parent_entity.world = GameInfo.world
	
	if _set_up:
		return
	
	var pc = $"../PuppetSpawnerComponent".puppet
	
	if not pc == null:
		pc.update_position.connect(set_entity_position.bind())
		_set_up = true


## Teleport the player.
func teleport(world:String, pos:Vector3):
	GameInfo.world = world # Set the game's world to destination world
	parent_entity.world = world # Set this entity world to the destination
	(%WorldLoader as WorldLoader).load_world(world) # Load world
	($"../PuppetSpawnerComponent" as PuppetSpawnerComponent).set_puppet_position(pos) # Set player puppet position
