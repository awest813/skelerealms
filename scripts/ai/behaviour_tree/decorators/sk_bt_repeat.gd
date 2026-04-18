class_name SKBTRepeat
extends SKBTDecorator
## Repeats the child a fixed number of times.
##
## Each time the child returns SUCCESS the repetition counter advances.
## After [member repetitions] successful runs the decorator returns
## [member on_limit].  If the child returns FAILURE at any point the
## decorator immediately returns FAILURE.


## How many times to repeat the child.
@export var repetitions: int = 1
## Status returned after all repetitions complete.
@export var on_limit: SKBTNode.Status = SKBTNode.Status.SUCCESS

var _current_count: int = 0


func tick(delta: float, actor: Node, blackboard: SKBlackboard) -> Status:
	if _current_count >= repetitions:
		_current_count = 0
		return on_limit

	var response: Status = leaf.tick(delta, actor, blackboard)

	match response:
		Status.RUNNING:
			return Status.RUNNING
		Status.SUCCESS:
			_current_count += 1
			if _current_count >= repetitions:
				_current_count = 0
				return on_limit
			return Status.RUNNING
		Status.FAILURE:
			_current_count = 0
			return Status.FAILURE

	return Status.RUNNING
