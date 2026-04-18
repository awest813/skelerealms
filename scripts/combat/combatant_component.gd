class_name CombatantComponent
extends SKEntityComponent
## Unifies combat-relevant stats for an entity: resistances, poise, stagger
## threshold, and equipment-derived combat modifiers.
##
## Shared by player and NPC entities alike. Delegates vitals changes to
## [VitalsComponent] and queries [EquipmentComponent] for weapon/armor bonuses.


## Emitted when poise reaches zero and the entity should stagger.
signal poise_broken
## Emitted when poise is restored after a stagger recovery.
signal poise_restored
## Emitted when the entity enters or exits an invincibility window.
signal invincibility_changed(active:bool)
## Emitted when the entity enters or exits a blocking state.
signal block_state_changed(active:bool)
## Emitted when a parry window opens or closes.
signal parry_state_changed(active:bool)
## Emitted when a block absorbs a hit. The attacking hitbox is passed for recoil/feedback.
signal block_hit(hitbox:SKHitbox)
## Emitted when a parry successfully deflects a hit. The attacking hitbox is passed.
signal parry_landed(hitbox:SKHitbox)

@export_category("Poise")
## Maximum poise value. Poise depletes when hit; at zero the entity staggers.
@export var max_poise:float = 100.0
## How much poise regenerates per second when not recently hit.
@export var poise_regen_rate:float = 10.0
## Seconds after last hit before poise begins regenerating.
@export var poise_regen_delay:float = 3.0

@export_category("Resistances")
## Per-damage-type resistance modifiers. Keys are [StringName] damage types,
## values are multipliers (1.0 = full damage, 0.5 = half, 0.0 = immune).
## Any damage type not listed uses 1.0.
@export var resistances:Dictionary[StringName, float] = {}

@export_category("Block")
## Damage multiplier applied when the entity is blocking (0.0 = full mitigation, 1.0 = no reduction).
@export var block_damage_multiplier:float = 0.25
## Poise-damage multiplier applied when the entity is blocking.
@export var block_poise_multiplier:float = 0.5

## Current poise value.
var poise:float
## Whether this entity is currently invincible (i-frames during dodge, etc.).
var invincible:bool = false:
	set(val):
		if invincible != val:
			invincible = val
			invincibility_changed.emit(val)
## Whether this entity is actively blocking.
var blocking:bool = false:
	set(val):
		if blocking != val:
			blocking = val
			block_state_changed.emit(val)
## Whether this entity is in a parry window.
var parrying:bool = false:
	set(val):
		if parrying != val:
			parrying = val
			parry_state_changed.emit(val)
## Timer tracking seconds since last hit for poise regen delay.
var _time_since_hit:float = 0.0
## Whether poise is currently broken.
var _poise_is_broken:bool = false


func _init() -> void:
	name = "CombatantComponent"


func _entity_ready() -> void:
	poise = max_poise


## Return the resistance modifier for a given damage type.
## Returns 1.0 (full damage) if no resistance is defined.
func get_resistance(damage_type:StringName) -> float:
	return resistances.get(damage_type, 1.0)


## Apply poise damage. Returns true if poise was broken by this hit.
func apply_poise_damage(amount:float) -> bool:
	if _poise_is_broken:
		return false
	poise = maxf(poise - amount, 0.0)
	_time_since_hit = 0.0
	dirty = true
	if poise <= 0.0:
		_poise_is_broken = true
		poise_broken.emit()
		return true
	return false


## Restore poise to maximum. Called after stagger recovery.
func restore_poise() -> void:
	poise = max_poise
	_poise_is_broken = false
	_time_since_hit = 0.0
	dirty = true
	poise_restored.emit()


## Process a [DamagePacket] through resistances and return the modified packet.
## The original packet is not mutated; a new one is returned.
func apply_resistances(packet:DamagePacket) -> DamagePacket:
	var modified_effects:Dictionary = {}
	for effect_name in packet.damage_effects:
		var amount:float = packet.damage_effects[effect_name]
		var modifier:float = get_resistance(effect_name)
		modified_effects[effect_name] = amount * modifier
	var result := DamagePacket.new(
		packet.offender,
		modified_effects,
		packet.spell_effects,
		packet.info,
		packet.source_weapon,
		packet.is_critical,
		packet.hit_reaction,
		packet.damage_category,
		packet.tags,
	)
	return result


func _physics_process(delta:float) -> void:
	if _poise_is_broken:
		return
	_time_since_hit += delta
	if _time_since_hit >= poise_regen_delay and poise < max_poise:
		poise = minf(poise + poise_regen_rate * delta, max_poise)


func get_dependencies() -> Array[String]:
	return ["DamageableComponent", "VitalsComponent"]


func save() -> Dictionary:
	dirty = false
	return {
		"poise": poise,
		"max_poise": max_poise,
		"resistances": resistances,
	}


func load_data(data:Dictionary) -> void:
	poise = data.get("poise", max_poise)
	max_poise = data.get("max_poise", max_poise)
	var res_data = data.get("resistances", null)
	if res_data is Dictionary:
		resistances = res_data
	dirty = false


func gather_debug_info() -> String:
	return """
[b]CombatantComponent[/b]
	Poise: %.1f / %.1f (broken: %s)
	Invincible: %s
	Blocking: %s (damage×%.2f, poise×%.2f)
	Parrying: %s
	Resistances: %s
""" % [
	poise, max_poise, _poise_is_broken,
	invincible,
	blocking, block_damage_multiplier, block_poise_multiplier,
	parrying,
	str(resistances),
]
