class_name SKHurtbox
extends Area3D
## A hurtbox representing a damageable region on an entity's puppet.
## When an [SKHitbox] overlaps this area, damage is routed through the
## entity's [DamageableComponent].
##
## Place as a child of a puppet's body region (torso, head, limbs, etc.).


## The entity that owns this hurtbox.
@export var owner_entity_ref:StringName = &""
## Optional body region identifier (e.g. &"head", &"torso", &"legs").
## Can be used for locational damage multipliers.
@export var body_region:StringName = &""
## Damage multiplier for this body region (e.g. 2.0 for headshots).
@export var damage_multiplier:float = 1.0


## Emitted when this hurtbox receives a hit from a hitbox.
signal hurt(hitbox:SKHitbox)


func _init() -> void:
	# Hurtboxes are monitorable targets but don't monitor others.
	monitoring = false
	monitorable = true
