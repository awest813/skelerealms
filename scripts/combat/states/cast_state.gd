class_name CombatCastState
extends CombatState
## Cast state for spell-type combat actions.
## Similar to attack but uses mana instead of stamina and may
## fire a spell effect rather than a hitbox.


var _elapsed:float = 0.0
var _phase:int = 0


func _get_state_name() -> String:
	return "Cast"


func enter(msg:Dictionary) -> void:
	var action:CombatAction = msg.get("action")
	if not action:
		state_machine.transition("Idle")
		return

	combat_machine._current_action = action
	_elapsed = 0.0
	_phase = 0

	var vitals:VitalsComponent = combat_machine.entity.get_component("VitalsComponent")
	if vitals:
		action.pay_cost(vitals)

	combat_machine.attack_started.emit(action)
	combat_machine.combat_state_changed.emit(&"cast_startup")
	combat_machine.animation_requested.emit(action.animation)


func update(delta:float) -> void:
	var action := combat_machine._current_action
	if not action:
		state_machine.transition("Idle")
		return

	_elapsed += delta

	match _phase:
		0: # Startup (channeling)
			if _elapsed >= action.startup_duration:
				_elapsed -= action.startup_duration
				_phase = 1
				combat_machine.combat_state_changed.emit(&"cast_active")
				# Spell delivery happens via signal — puppet or controller listens
				combat_machine.hitbox_active.emit(true)
		1: # Active (spell fires)
			if _elapsed >= action.active_duration:
				_elapsed -= action.active_duration
				_phase = 2
				combat_machine.hitbox_active.emit(false)
				combat_machine.combat_state_changed.emit(&"cast_recovery")
		2: # Recovery
			if _elapsed >= action.recovery_duration:
				combat_machine.attack_finished.emit(action)
				combat_machine._current_action = null
				state_machine.transition("Idle")


func exit() -> void:
	combat_machine.hitbox_active.emit(false)
	_phase = 0
	_elapsed = 0.0
