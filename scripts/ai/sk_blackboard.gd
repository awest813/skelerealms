class_name SKBlackboard
extends Resource
## A shared key-value store for AI runtime state.
##
## [SKBlackboard] can be used by behaviour tree nodes, GOAP actions, AI modules,
## or any other system that needs to share transient data between nodes.
##
## Keys are [StringName]s and values can be any [Variant].
##
## Inspired by BehaviourToolkit (MIT) by ThePat02.


## Emitted whenever a value is set or removed.
signal changed(key: StringName)

## The backing dictionary.
@export var content: Dictionary = {}


## Sets a value in the blackboard.
func set_value(key: StringName, value: Variant) -> void:
	content[key] = value
	changed.emit(key)


## Returns a value from the blackboard, or [param default] if the key is absent.
func get_value(key: StringName, default: Variant = null) -> Variant:
	return content.get(key, default)


## Returns [code]true[/code] if the key exists.
func has_value(key: StringName) -> bool:
	return content.has(key)


## Removes a key.  Returns [code]true[/code] if the key existed.
func erase_value(key: StringName) -> bool:
	var existed := content.erase(key)
	if existed:
		changed.emit(key)
	return existed


## Removes all entries.
func clear() -> void:
	content.clear()


## Serializes the blackboard to a plain dictionary for saving.
func serialize() -> Dictionary:
	return content.duplicate(true)


## Restores the blackboard from a previously serialized dictionary.
func deserialize(data: Dictionary) -> void:
	content = data.duplicate(true)
