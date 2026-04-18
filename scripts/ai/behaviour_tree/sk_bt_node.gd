class_name SKBTNode
extends Node
## Base class for all behaviour tree nodes in Skelerealms.
##
## Behaviour tree nodes return [enum SKBTNode.Status] from their [method tick]
## method to drive the tree traversal.  Composites, decorators, and leaves all
## extend this class.
##
## Inspired by BehaviourToolkit (MIT) by ThePat02.


## Result status returned by every [method tick] call.
enum Status {
	SUCCESS,  ## The node completed successfully.
	FAILURE,  ## The node failed.
	RUNNING,  ## The node is still in progress; tick again next frame.
}


## Override in subclasses.  [param delta] is the frame time, [param actor] is the
## controlled [Node] (e.g. a puppet or the entity itself), and [param blackboard]
## is a shared [SKBlackboard] for runtime state.
func tick(_delta: float, _actor: Node, _blackboard: SKBlackboard) -> Status:
	return Status.SUCCESS
