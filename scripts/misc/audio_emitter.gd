class_name AudioEventEmitter
extends Node3D
## Used to emit sounds that should have an effect on other things, like alerting NPCs.
## Put this beneath some sort of audio emitter, and link signals.


@export var ignore_self:bool = false


## Finds every node of group "audio_listener" within [param range] units and
## calls [code]heard_audio(self)[/code] on each one.
## Uses direct distance checks against group members instead of physics queries.
func send_play_event(range:float) -> void:
	var listeners := get_tree().get_nodes_in_group("audio_listener")
	var range_sq := range * range
	for listener in listeners:
		if not listener is Node3D:
			continue
		if ignore_self:
			if (listener as Node).is_ancestor_of(self) or self.is_ancestor_of(listener):
				continue
		var dist_sq:float = (listener as Node3D).global_position.distance_squared_to(global_position)
		if dist_sq > range_sq:
			continue
		if listener.has_method("heard_audio"):
			listener.heard_audio(self)
