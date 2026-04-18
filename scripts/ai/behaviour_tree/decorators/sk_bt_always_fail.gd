class_name SKBTAlwaysFail
extends SKBTDecorator
## Forces the child result to FAILURE after it finishes.
## RUNNING passes through unchanged.


func tick(delta: float, actor: Node, blackboard: SKBlackboard) -> Status:
	var response: Status = leaf.tick(delta, actor, blackboard)
	if response == Status.RUNNING:
		return Status.RUNNING
	return Status.FAILURE
