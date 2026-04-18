class_name SKBTDecorator
extends SKBTNode
## Base class for decorator behaviour tree nodes.
##
## Decorators wrap a single child and modify its result or execution.
## Think of them as an extra layer of logic executed around the child.


## The single child this decorator wraps.
var leaf: SKBTNode


func _ready() -> void:
	if get_child_count() > 0 and get_child(0) is SKBTNode:
		leaf = get_child(0) as SKBTNode


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not (get_parent() is SKBTComposite or get_parent() is SKBTRoot):
		warnings.append("SKBTDecorator should be a child of SKBTComposite or SKBTRoot.")
	if get_child_count() == 0:
		warnings.append("SKBTDecorator needs exactly one child.")
	elif get_child_count() > 1:
		warnings.append("SKBTDecorator should have only one child.")
	elif not (get_child(0) is SKBTNode):
		warnings.append("SKBTDecorator child must be an SKBTNode.")
	return warnings
