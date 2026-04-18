class_name CombatIdleState
extends CombatState
## Idle combat state — the entity is ready to act.


func _get_state_name() -> String:
	return "Idle"


func enter(msg:Dictionary) -> void:
	combat_machine.combat_state_changed.emit(&"idle")


func update(delta:float) -> void:
	# Idle state simply waits for external transitions (input or AI).
	pass
