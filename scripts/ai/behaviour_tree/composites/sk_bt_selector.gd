class_name SKBTSelector
extends SKBTComposite
## Tries children in order until one succeeds.
## Succeeds as soon as any child succeeds.  Fails only if every child fails.
## Returns RUNNING while a child is still in progress.


var _current_index: int = 0


func tick(delta: float, actor: Node, blackboard: SKBlackboard) -> Status:
	while _current_index < leaves.size():
		var response: Status = leaves[_current_index].tick(delta, actor, blackboard)
		match response:
			Status.RUNNING:
				return Status.RUNNING
			Status.SUCCESS:
				_current_index = 0
				return Status.SUCCESS
			Status.FAILURE:
				_current_index += 1

	_current_index = 0
	return Status.FAILURE
