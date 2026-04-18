class_name SKBTSequence
extends SKBTComposite
## Ticks children in order.  Succeeds when all children succeed.
## Fails immediately if any child fails.  Returns RUNNING while a child
## is still in progress.


var _current_index: int = 0


func tick(delta: float, actor: Node, blackboard: SKBlackboard) -> Status:
	while _current_index < leaves.size():
		var response: Status = leaves[_current_index].tick(delta, actor, blackboard)
		match response:
			Status.RUNNING:
				return Status.RUNNING
			Status.FAILURE:
				_current_index = 0
				return Status.FAILURE
			Status.SUCCESS:
				_current_index += 1

	_current_index = 0
	return Status.SUCCESS
