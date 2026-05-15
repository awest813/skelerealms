class_name DefaultStealthProvider
extends Node
## Default stealth provider that satisfies the Skelerealms stealth provider interface
## by delegating to an [EyesPerception] node.
##
## Attach this node to a puppet (or anywhere that has access to an [EyesPerception]).
## Set [member eyes] to the [EyesPerception] node, then assign this node to the puppet's
## [code]eyes[/code] slot (or wherever [NPCComponent] looks for its stealth provider).
##
## The stealth provider contract is:
##   [method get_visible_objects] -> Dictionary (object -> {&"visibility":float, &"last_seen_position":Vector3})
##   signal object_entered_view(Object)
##   signal object_exited_view(Object)
##
## @tutorial(Stealth providers): https://github.com/SlashScreen/skelerealms/blob/main/docs/user%20guide/stealth_provider.md


## The [EyesPerception] node this provider delegates to.
## Assign in the Inspector or via code after [method _ready].
@export var eyes:EyesPerception

## Seconds without visibility before an object is considered "left view".
## Increasing this creates a grace period before the NPC forgets an object.
@export var linger_time:float = 2.0

## The object-to-data map exposed to NPCComponent.
## Structure: Object -> { &"visibility": float, &"last_seen_position": Vector3 }
var _visible:Dictionary[Object, Dictionary] = {}

## Tracks linger timers for objects that left the FOV.
var _linger_timers:Dictionary[Object, float] = {}

## Emitted when an object enters the field of view for the first time.
signal object_entered_view(obj:Object)
## Emitted when an object exits the field of view (after [member linger_time]).
signal object_exited_view(obj:Object)


func _ready() -> void:
	if not eyes:
		push_warning("DefaultStealthProvider: no EyesPerception assigned on '%s'." % name)
		return
	eyes.perceived.connect(_on_perceived)
	eyes.not_perceived.connect(_on_not_perceived)


func _process(delta: float) -> void:
	# Count down linger timers; emit exit signal when expired.
	var expired: Array[Object] = []
	for obj in _linger_timers:
		_linger_timers[obj] -= delta
		if _linger_timers[obj] <= 0.0:
			expired.append(obj)
	for obj in expired:
		_linger_timers.erase(obj)
		if _visible.has(obj):
			_visible.erase(obj)
			object_exited_view.emit(obj)


## Returns the current visibility dictionary — satisfies the stealth provider contract.
func get_visible_objects() -> Dictionary:
	return _visible


func _on_perceived(data:EyesPerception.PerceptionData) -> void:
	if data.object == &"":
		return
	var entity:SKEntity = SKEntityManager.instance.get_entity(StringName(data.object)) if SKEntityManager.instance else null
	if not entity:
		return
	var puppet := entity.get_node_or_null("PuppetSpawnerComponent") as PuppetSpawnerComponent
	# Use the entity itself as the object key; fallback to a string key.
	var obj_key: Object = puppet if puppet else entity
	var was_visible := _visible.has(obj_key)
	_linger_timers.erase(obj_key) # restart linger if it was counting down
	_visible[obj_key] = {
		&"visibility": data.visibility,
		&"last_seen_position": _get_position(entity),
	}
	if not was_visible:
		object_entered_view.emit(obj_key)


func _on_not_perceived(data:EyesPerception.PerceptionData) -> void:
	if data.object == &"":
		return
	var entity:SKEntity = SKEntityManager.instance.get_entity(StringName(data.object)) if SKEntityManager.instance else null
	if not entity:
		return
	var puppet := entity.get_node_or_null("PuppetSpawnerComponent") as PuppetSpawnerComponent
	var obj_key: Object = puppet if puppet else entity
	if _visible.has(obj_key) and not _linger_timers.has(obj_key):
		_linger_timers[obj_key] = linger_time


func _get_position(entity:SKEntity) -> Vector3:
	return entity.position if entity else Vector3.ZERO
