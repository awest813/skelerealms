class_name SKBTParallel
extends SKBTComposite
## Ticks all children every frame.
##
## Returns FAILURE immediately if any child fails.
## [member policy] controls when the node returns SUCCESS:
## - [code]SUCCESS_ON_ALL[/code]: all children must succeed.
## - [code]SUCCESS_ON_ONE[/code]: any single child succeeding is enough.


enum ParallelPolicy {
	SUCCESS_ON_ALL,  ## All children must return SUCCESS.
	SUCCESS_ON_ONE,  ## Any child returning SUCCESS is sufficient.
}

## When to return SUCCESS.
@export var policy: ParallelPolicy = ParallelPolicy.SUCCESS_ON_ALL


var _responses: Dictionary[int, int] = {}


func tick(delta: float, actor: Node, blackboard: SKBlackboard) -> Status:
	for i in range(leaves.size()):
		var response: Status = leaves[i].tick(delta, actor, blackboard)
		_responses[i] = response

		if response == Status.FAILURE:
			_responses.clear()
			return Status.FAILURE

		if policy == ParallelPolicy.SUCCESS_ON_ONE and response == Status.SUCCESS:
			_responses.clear()
			return Status.SUCCESS

	if policy == ParallelPolicy.SUCCESS_ON_ALL:
		for response: Status in _responses.values():
			if response != Status.SUCCESS:
				return Status.RUNNING
		_responses.clear()
		return Status.SUCCESS

	return Status.RUNNING
