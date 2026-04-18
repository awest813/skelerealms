class_name SKHitbox
extends Area3D
## A hitbox attached to a weapon, projectile, or ability source.
## When active and overlapping an [SKHurtbox], it triggers damage delivery
## through the [HitPipeline].
##
## Place as a child of a puppet's weapon bone or spell origin.


## The entity that owns this hitbox.
@export var owner_entity_ref:StringName = &""
## Whether the hitbox is currently checking for overlaps.
var active:bool = false:
	set(val):
		active = val
		monitoring = val
		monitorable = val
		if not val:
			_already_hit.clear()

## Tracks which hurtboxes have already been hit in the current active window
## to prevent duplicate hits per swing.
var _already_hit:Array[SKHurtbox] = []


## Emitted when this hitbox contacts a hurtbox it hasn't hit yet in this window.
signal hit_registered(hurtbox:SKHurtbox)


func _init() -> void:
	monitoring = false
	monitorable = false
	# Default collision: hitboxes on layer 0, detect hurtboxes on layer 0
	# The consuming project should configure collision layers appropriately.


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area:Area3D) -> void:
	if not active:
		return
	if not area is SKHurtbox:
		return
	var hurtbox := area as SKHurtbox
	# Skip self-hits
	if hurtbox.owner_entity_ref == owner_entity_ref:
		return
	# Skip duplicates
	if _already_hit.has(hurtbox):
		return
	_already_hit.append(hurtbox)
	hit_registered.emit(hurtbox)
