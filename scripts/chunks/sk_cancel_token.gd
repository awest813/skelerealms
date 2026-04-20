class_name SKCancelToken
extends RefCounted
## Lightweight cancellation token for async chunk operations.
##
## Check [member is_cancelled] in long-running load operations to
## detect when the [SKChunkManager] has requested early termination.


## Whether cancellation has been requested.
var is_cancelled: bool = false


## Request cancellation. Safe to call multiple times.
func cancel() -> void:
	is_cancelled = true
