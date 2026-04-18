class_name SKBTRoot
extends Node
## Root node for a behaviour tree in Skelerealms.
##
## Place this node in a scene, add a single [SKBTComposite] or [SKBTLeaf] child
## as the entry point, assign an [member actor] and optionally a [member blackboard].
## The root ticks the tree every frame according to [member process_type].
##
## Inspired by BehaviourToolkit (MIT) by ThePat02.


## Whether to tick on idle (render) frames or physics frames.
enum ProcessType {
	IDLE,     ## Updates every rendered frame.
	PHYSICS,  ## Updates on the physics tick (default).
}


## Start ticking immediately on ready.
@export var autostart: bool = false
## Idle vs physics processing.
@export var process_type: ProcessType = ProcessType.PHYSICS:
	set(value):
		process_type = value
		_setup_processing()
## The actor node the tree controls (e.g. a puppet, NPC, or entity).
@export var actor: Node
## Shared blackboard for the tree.  Created automatically if not assigned.
@export var blackboard: SKBlackboard


## Whether the tree is actively ticking.
var active: bool = false
## Last status returned by the entry point.
var current_status: SKBTNode.Status
## The first child node used as the tree entry point.
var entry_point: SKBTNode


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
		return

	if get_child_count() > 0 and get_child(0) is SKBTNode:
		entry_point = get_child(0) as SKBTNode

	if blackboard == null:
		blackboard = SKBlackboard.new()

	if autostart:
		active = true

	_setup_processing()


func _physics_process(delta: float) -> void:
	_tick(delta)


func _process(delta: float) -> void:
	_tick(delta)


func _tick(delta: float) -> void:
	if not active or entry_point == null:
		return
	current_status = entry_point.tick(delta, actor, blackboard)


## Configures which process callback is active based on [member process_type].
func _setup_processing() -> void:
	set_physics_process(process_type == ProcessType.PHYSICS)
	set_process(process_type == ProcessType.IDLE)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var children := get_children()
	if children.size() == 0:
		warnings.append("SKBTRoot needs exactly one SKBTNode child as entry point.")
	elif children.size() > 1:
		warnings.append("SKBTRoot should have only one child.")
	elif not (children[0] is SKBTNode):
		warnings.append("The child of SKBTRoot must be an SKBTNode.")
	return warnings
