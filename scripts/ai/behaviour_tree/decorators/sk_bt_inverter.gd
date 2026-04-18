class_name SKBTInverter
extends SKBTDecorator
## Inverts the result of the child node.
## SUCCESS → FAILURE, FAILURE → SUCCESS, RUNNING passes through.


func tick(delta: float, actor: Node, blackboard: SKBlackboard) -> Status:
	var response: Status = leaf.tick(delta, actor, blackboard)
	match response:
		Status.SUCCESS:
			return Status.FAILURE
		Status.FAILURE:
			return Status.SUCCESS
	return Status.RUNNING
