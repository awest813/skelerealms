class_name SKBTRandom
extends SKBTComposite
## Randomly selects one child to execute each time the node starts.
## The chosen child runs until it returns SUCCESS or FAILURE; then a new
## random child is selected on the next evaluation.


var _rng := RandomNumberGenerator.new()
var _active_leaf: SKBTNode = null


func tick(delta: float, actor: Node, blackboard: SKBlackboard) -> Status:
	if leaves.is_empty():
		return Status.FAILURE

	if _active_leaf == null:
		_active_leaf = leaves[_rng.randi() % leaves.size()]

	var response: Status = _active_leaf.tick(delta, actor, blackboard)

	if response == Status.RUNNING:
		return Status.RUNNING

	_active_leaf = null
	return response
