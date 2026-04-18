class_name CombatDeathState
extends CombatState
## Death state — entered when vitals reach zero.
## This is a terminal state; the entity does not transition out.


func _get_state_name() -> String:
	return "Death"


func enter(msg:Dictionary) -> void:
	combat_machine.combat_state_changed.emit(&"death")
	combat_machine.animation_requested.emit(&"death")
	combat_machine.entity_died.emit()
