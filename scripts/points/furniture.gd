class_name Furniture
extends IdlePoint
## A special [IdlePoint] that plays animations on occupying actors and optionally
## supports multiple simultaneous users via sub-points.
## Add an [InteractiveObject] node somewhere.
## Does not enable crafting or anything by default, but you can extend it to do that if you want.


## Animation that plays on an actor when furniture is occupied.
@export var animation:Animation
## Maximum number of users. When greater than 1, child [IdlePoint] nodes act as
## sub-points for additional occupants.
@export var max_users:int = 1

## Currently occupying entity names.
var _occupants:Array[String] = []

## Emitted when an animation should be played on an actor.
signal play_animation(entity_name:String, anim:Animation)
## Emitted when an animation should be stopped on an actor.
signal stop_animation(entity_name:String)


func _ready() -> void:
	super._ready()
	occupied.connect(_on_occupied.bind())
	unoccupied.connect(_on_unoccupied.bind())


## Occupy this furniture with an entity. Returns true if a seat was available.
func occupy(who:String) -> bool:
	if _occupants.size() >= max_users:
		return false
	
	_occupants.append(who)
	
	# Use the base IdlePoint slot first, then sub-points
	if _occupants.size() == 1:
		super.occupy(who)
	else:
		# Assign to a child sub-point
		var sub := _find_free_sub_point()
		if sub:
			sub.occupy(who)
	
	# Trigger animation
	if animation:
		play_animation.emit(who, animation)
	
	return true


## Remove an occupant from this furniture.
func unoccupy_entity(who:String) -> void:
	if not _occupants.has(who):
		return
	
	_occupants.erase(who)
	
	# Stop animation
	if animation:
		stop_animation.emit(who)
	
	# Free the matching slot
	if owning_entity == who:
		super.unoccupy()
	else:
		for child in get_children():
			if child is IdlePoint and child.owning_entity == who:
				child.unoccupy()
				break
	
	if _occupants.is_empty():
		is_occupied = false


## Override base unoccupy to clear all occupants.
func unoccupy() -> void:
	var occupants_copy := _occupants.duplicate()
	for who in occupants_copy:
		unoccupy_entity(who)


## Whether this furniture has room for another user.
func has_room() -> bool:
	return _occupants.size() < max_users


func _on_occupied() -> void:
	pass


func _on_unoccupied() -> void:
	pass


func _find_free_sub_point() -> IdlePoint:
	for child in get_children():
		if child is IdlePoint and not child.is_occupied:
			return child
	return null
