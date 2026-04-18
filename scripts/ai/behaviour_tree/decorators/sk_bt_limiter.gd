class_name SKBTLimiter
extends SKBTDecorator
## Limits how many times the child can run to completion.
##
## The child is ticked normally until it returns SUCCESS or FAILURE
## [member limit] times.  After that, every subsequent tick immediately
## returns [member on_limit] without ticking the child.  Call [method reset]
## to clear the counter.


## Maximum number of completed (non-RUNNING) runs allowed.
@export var limit: int = 1
## Status returned once the limit is reached.
@export var on_limit: SKBTNode.Status = SKBTNode.Status.FAILURE

var _count: int = 0


func tick(delta: float, actor: Node, blackboard: SKBlackboard) -> Status:
	if _count >= limit:
		return on_limit

	var response: Status = leaf.tick(delta, actor, blackboard)
	if response == Status.RUNNING:
		return Status.RUNNING

	_count += 1
	return response


## Reset the run counter so the child can execute again.
func reset() -> void:
	_count = 0
