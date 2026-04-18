class_name SKBTComposite
extends SKBTNode
## Base class for composite behaviour tree nodes.
##
## Composites hold multiple children and evaluate/execute them based on
## custom logic (sequence, selector, parallel, etc.).


## Cached child list, populated in [method _ready].
var leaves: Array[SKBTNode] = []


func _ready() -> void:
	_rebuild_leaves()


## Rebuild the leaf cache from children.
func _rebuild_leaves() -> void:
	leaves.clear()
	for child in get_children():
		if child is SKBTNode:
			leaves.append(child as SKBTNode)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not (get_parent() is SKBTComposite or get_parent() is SKBTRoot or get_parent() is SKBTDecorator):
		warnings.append("SKBTComposite must be a child of SKBTComposite, SKBTDecorator, or SKBTRoot.")
	if get_child_count() == 0:
		warnings.append("SKBTComposite must have at least one child.")
	return warnings
