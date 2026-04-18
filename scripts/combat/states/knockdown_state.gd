class_name CombatKnockdownState
extends CombatState
## Knockdown state — the entity is on the ground and must get up.
## Longer recovery than stagger; entity is fully vulnerable.


## Default knockdown duration in seconds.
const DEFAULT_KNOCKDOWN_DURATION := 2.0

var _elapsed:float = 0.0
var _duration:float = DEFAULT_KNOCKDOWN_DURATION


func _get_state_name() -> String:
	return "Knockdown"


func enter(msg:Dictionary) -> void:
	_elapsed = 0.0
	_duration = msg.get("duration", DEFAULT_KNOCKDOWN_DURATION)
	combat_machine.combat_state_changed.emit(&"knockdown")
	combat_machine.animation_requested.emit(&"knockdown")


func update(delta:float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		var combatant:CombatantComponent = combat_machine.entity.get_component("CombatantComponent")
		if combatant:
			combatant.restore_poise()
		state_machine.transition("Idle")


func exit() -> void:
	_elapsed = 0.0
