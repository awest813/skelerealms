class_name CombatStaggerState
extends CombatState
## Stagger state — the entity was hit hard enough to break poise.
## During stagger, the entity cannot act and is vulnerable.


## Default stagger duration in seconds.
const DEFAULT_STAGGER_DURATION := 0.8

var _elapsed:float = 0.0
var _duration:float = DEFAULT_STAGGER_DURATION


func _get_state_name() -> String:
	return "Stagger"


func enter(msg:Dictionary) -> void:
	_elapsed = 0.0
	_duration = msg.get("duration", DEFAULT_STAGGER_DURATION)
	combat_machine.combat_state_changed.emit(&"stagger")
	combat_machine.animation_requested.emit(&"stagger")


func update(delta:float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		# Restore poise and return to idle
		var combatant:CombatantComponent = combat_machine.entity.get_component("CombatantComponent")
		if combatant:
			combatant.restore_poise()
		state_machine.transition("Idle")


func exit() -> void:
	_elapsed = 0.0
