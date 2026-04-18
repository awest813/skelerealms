class_name CombatAction
extends Resource
## Defines a single combat action — an attack, ability, or spell.
##
## Encapsulates timing windows, resource costs, damage templates, and combo
## links so the combat state machine can execute it frame-by-frame.


## Action type determines how the hit is detected.
enum ActionType {
	MELEE,   ## Hitbox-based detection via Area3D overlap.
	RANGED,  ## Hitscan ray detection.
	SPELL,   ## Spell-effect delivery (may use projectile or AOE).
}

## Unique identifier for this action.
@export var id:StringName = &""
## Human-readable name for UI display.
@export var display_name:String = ""
## The type of action — melee, ranged, or spell.
@export var action_type:ActionType = ActionType.MELEE

@export_category("Timing")
## Duration of startup phase in seconds (wind-up before the hit becomes active).
@export var startup_duration:float = 0.2
## Duration of active phase in seconds (window during which the hit can land).
@export var active_duration:float = 0.15
## Duration of recovery phase in seconds (cooldown before next action).
@export var recovery_duration:float = 0.3

@export_category("Cost")
## Stamina (moxie) cost to perform this action.
@export var stamina_cost:float = 0.0
## Magica (will) cost to perform this action.
@export var mana_cost:float = 0.0

@export_category("Animation")
## Animation name to play during this action.
@export var animation:StringName = &""

@export_category("Damage")
## Base damage effects dictionary. Keys are StringName damage types,
## values are float amounts. Used to build a [DamagePacket].
@export var base_damage:Dictionary = {}
## Spell effects to attach to the damage packet.
@export var spell_effects:Array[StringName] = []
## High-level damage category: &"physical", &"elemental", or &"true".
@export var damage_category:StringName = &"physical"
## Poise damage dealt to the target.
@export var poise_damage:float = 20.0
## Suggested hit reaction: &"flinch", &"stagger", &"knockdown", or &"none".
@export var hit_reaction:StringName = &"flinch"
## Gameplay tags (e.g. &"fire", &"backstab", &"heavy").
@export var tags:Array[StringName] = []

@export_category("Combo")
## Actions that can chain from this one during recovery. Empty = no combo.
@export var combo_links:Array[StringName] = []
## If true, this action can be used as a combo opener.
@export var is_combo_starter:bool = false

@export_category("Ranged")
## Maximum range for hitscan actions.
@export var hitscan_range:float = 100.0

@export_category("Critical")
## Base critical hit chance (0.0 – 1.0).
@export var crit_chance:float = 0.05
## Critical hit damage multiplier.
@export var crit_multiplier:float = 1.5


## Build a [DamagePacket] from this action's template.
func build_damage_packet(offender:String, source_weapon:StringName = &"") -> DamagePacket:
	var is_crit := randf() < crit_chance
	var effects := base_damage.duplicate()
	if is_crit:
		for key in effects:
			effects[key] *= crit_multiplier
	return DamagePacket.new(
		offender,
		effects,
		spell_effects,
		{},
		source_weapon,
		is_crit,
		hit_reaction,
		damage_category,
		tags,
	)


## Total duration of the action across all phases.
func get_total_duration() -> float:
	return startup_duration + active_duration + recovery_duration


## Whether the entity can afford the resource cost given current vitals.
func can_afford(vitals:VitalsComponent) -> bool:
	if stamina_cost > 0.0 and vitals.vitals.get("moxie", 0.0) < stamina_cost:
		return false
	if mana_cost > 0.0 and vitals.vitals.get("will", 0.0) < mana_cost:
		return false
	return true


## Deduct the resource cost from vitals.
func pay_cost(vitals:VitalsComponent) -> void:
	if stamina_cost > 0.0:
		vitals.change_moxie(-stamina_cost)
	if mana_cost > 0.0:
		vitals.change_will(-mana_cost)
