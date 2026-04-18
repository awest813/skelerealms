class_name SKBTLeaf
extends SKBTNode
## A leaf node where actual behaviour logic is implemented.
##
## Extend this class and override [method tick] to implement custom actions
## or condition checks.  Leaves must not have children.


func tick(_delta: float, _actor: Node, _blackboard: SKBlackboard) -> Status:
	return Status.SUCCESS


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not (get_parent() is SKBTNode or get_parent() is SKBTRoot):
		warnings.append("SKBTLeaf must be a child of an SKBTNode or SKBTRoot.")
	if get_child_count() > 0:
		warnings.append("SKBTLeaf must not have any children.")
	return warnings
