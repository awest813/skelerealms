class_name CombatAttackState
extends CombatState
## Manages the three-phase attack lifecycle: startup → active → recovery.
## Drives hitbox activation and combo window detection.


## Elapsed time in the current phase.
var _elapsed:float = 0.0
## Current phase: 0 = startup, 1 = active, 2 = recovery.
var _phase:int = 0
## Combo action queued during the recovery phase (if any).
var _queued_combo:CombatAction = null


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
	_queued_combo = null

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
				# If a combo was queued during recovery, chain into it.
				# We must transition to Idle first so the exit() cleanup
				# runs (disabling hitboxes, resetting phase) before the
				# new attack's enter() fires.
				if _queued_combo:
					var combo := _queued_combo
					_queued_combo = null
					state_machine.transition("Idle")
					combat_machine.execute_action(combo)
				else:
					state_machine.transition("Idle")


## Queue a combo follow-up during the recovery phase. The action must
## appear in the current action's [member CombatAction.combo_links].
func queue_combo(action:CombatAction) -> bool:
	if _phase != 2:
		return false
	var current := combat_machine._current_action
	if not current:
		return false
	if not current.combo_links.has(action.id):
		return false
	# Ensure the entity can afford it
	var vitals:VitalsComponent = combat_machine.entity.get_component("VitalsComponent")
	if vitals and not action.can_afford(vitals):
		return false
	_queued_combo = action
	return true


## Whether this attack state is in its recovery phase (combo window open).
func is_in_recovery_phase() -> bool:
	return _phase == 2


func exit() -> void:
	# Ensure hitbox is disabled when leaving attack state early.
	combat_machine.hitbox_active.emit(false)
	_phase = 0
	_elapsed = 0.0
	_queued_combo = null
