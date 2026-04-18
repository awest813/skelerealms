class_name DamagePacket
extends DamageInfo
## Enhanced damage event data extending [DamageInfo] with combat-specific fields.
## Adds critical hit tracking, hit reactions, damage categories, source weapon
## identification, and gameplay tags for richer combat interactions.
##
## Backward-compatible: any code accepting [DamageInfo] also accepts [DamagePacket].


## The weapon or ability that produced this damage.
var source_weapon:StringName = &""
## Whether this hit was a critical strike.
var is_critical:bool = false
## Suggested hit reaction for the target: &"flinch", &"stagger", &"knockdown", or &"none".
var hit_reaction:StringName = &"none"
## High-level damage category: &"physical", &"elemental", or &"true".
var damage_category:StringName = &"physical"
## Gameplay tags for filtering and queries (e.g. &"fire", &"backstab", &"AOE").
var tags:Array[StringName] = []


func _init(
	p_offender:String = "",
	p_damage_effects:Dictionary = {},
	p_spell_effects:Array[StringName] = [],
	p_info:Dictionary = {},
	p_source_weapon:StringName = &"",
	p_is_critical:bool = false,
	p_hit_reaction:StringName = &"none",
	p_damage_category:StringName = &"physical",
	p_tags:Array[StringName] = [],
) -> void:
	super._init(p_offender, p_damage_effects, p_spell_effects, p_info)
	source_weapon = p_source_weapon
	is_critical = p_is_critical
	hit_reaction = p_hit_reaction
	damage_category = p_damage_category
	tags = p_tags


## Create a [DamagePacket] from a plain [DamageInfo], preserving existing fields.
static func from_damage_info(info:DamageInfo) -> DamagePacket:
	return DamagePacket.new(
		info.offender,
		info.damage_effects,
		info.spell_effects,
		info.info,
	)
