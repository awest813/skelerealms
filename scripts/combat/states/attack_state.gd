class_name CombatAttackState
extends CombatState
## Manages the three-phase attack lifecycle: startup → active → recovery.
## Drives hitbox activation and combo window detection.


## Elapsed time in the current phase.
var _elapsed:float = 0.0
## Current phase: 0 = startup, 1 = active, 2 = recovery.
var _phase:int = 0


func _get_state_name() -> String:
	return "Attack"


func enter(msg:Dictionary) -> void:
	var action:CombatAction = msg.get("action")
	if not action:
		state_machine.transition("Idle")
		return

	combat_machine._current_action = action
	_elapsed = 0.0
	_phase = 0

	# Pay resource cost
	var vitals:VitalsComponent = combat_machine.entity.get_component("VitalsComponent")
	if vitals:
		action.pay_cost(vitals)

	combat_machine.attack_started.emit(action)
	combat_machine.combat_state_changed.emit(&"attack_startup")
	combat_machine.animation_requested.emit(action.animation)


func update(delta:float) -> void:
	var action := combat_machine._current_action
	if not action:
		state_machine.transition("Idle")
		return

	_elapsed += delta

	match _phase:
		0: # Startup
			if _elapsed >= action.startup_duration:
				_elapsed -= action.startup_duration
				_phase = 1
				combat_machine.hitbox_active.emit(true)
				combat_machine.combat_state_changed.emit(&"attack_active")
		1: # Active
			if _elapsed >= action.active_duration:
				_elapsed -= action.active_duration
				_phase = 2
				combat_machine.hitbox_active.emit(false)
				combat_machine.combat_state_changed.emit(&"attack_recovery")
		2: # Recovery
			if _elapsed >= action.recovery_duration:
				combat_machine.attack_finished.emit(action)
				combat_machine._current_action = null
				state_machine.transition("Idle")


func exit() -> void:
	# Ensure hitbox is disabled when leaving attack state early.
	combat_machine.hitbox_active.emit(false)
	_phase = 0
	_elapsed = 0.0
