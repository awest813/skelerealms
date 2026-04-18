class_name CombatStateMachine
extends FSMMachine
## Combat-specific state machine that manages attack, cast, stagger,
## knockdown, and death states for an entity.
##
## Sits as a child of an [SKEntity] (via [CombatantComponent] or directly)
## and drives combat flow through signals that puppets and animation
## controllers can listen to.


## The entity this combat machine belongs to.
var entity:SKEntity
## The action currently being executed, if any.
var _current_action:CombatAction

## Emitted when the combat state changes, with the state name as a StringName.
signal combat_state_changed(state_name:StringName)
## Emitted when an attack action begins.
signal attack_started(action:CombatAction)
## Emitted when an attack action completes all phases.
signal attack_finished(action:CombatAction)
## Emitted to request the puppet play an animation.
signal animation_requested(anim_name:StringName)
## Emitted to enable/disable hitbox detection.
signal hitbox_active(active:bool)
## Emitted when the entity dies.
signal entity_died


func _init() -> void:
	name = "CombatStateMachine"


## Initialize the combat state machine with all combat states.
## Call this after adding to the scene tree.
func initialize(p_entity:SKEntity) -> void:
	entity = p_entity
	initial_state = "Idle"
	var states:Array[FSMState] = [
		CombatIdleState.new(),
		CombatAttackState.new(),
		CombatCastState.new(),
		CombatStaggerState.new(),
		CombatKnockdownState.new(),
		CombatDeathState.new(),
	]
	setup(states)


## Request execution of a [CombatAction]. Returns false if the entity
## cannot currently act (wrong state, insufficient resources, etc.).
func execute_action(action:CombatAction) -> bool:
	# Can only act from idle
	if not state or state.name != "Idle":
		return false

	# Check resource cost
	var vitals:VitalsComponent = entity.get_component("VitalsComponent") as VitalsComponent
	if vitals and not action.can_afford(vitals):
		return false

	# Route to appropriate state
	match action.action_type:
		CombatAction.ActionType.MELEE, CombatAction.ActionType.RANGED:
			transition("Attack", {"action": action})
		CombatAction.ActionType.SPELL:
			transition("Cast", {"action": action})

	return true


## Force the entity into a stagger state (e.g. from poise break).
func apply_stagger(duration:float = CombatStaggerState.DEFAULT_STAGGER_DURATION) -> void:
	# Can stagger from any state except death
	if state and state.name == "Death":
		return
	_current_action = null
	transition("Stagger", {"duration": duration})


## Force the entity into a knockdown state.
func apply_knockdown(duration:float = CombatKnockdownState.DEFAULT_KNOCKDOWN_DURATION) -> void:
	if state and state.name == "Death":
		return
	_current_action = null
	transition("Knockdown", {"duration": duration})


## Transition to the death state.
func die() -> void:
	_current_action = null
	transition("Death")


## Whether the entity can currently execute an action.
func can_act() -> bool:
	return state != null and state.name == "Idle"


## Queue a combo follow-up while the current attack is in recovery.
## Returns false if the entity is not in an attack/cast recovery phase,
## or the action is not a valid combo link.
func queue_combo(action:CombatAction) -> bool:
	if state is CombatAttackState:
		return (state as CombatAttackState).queue_combo(action)
	return false


## Whether the current state is in a recovery phase that accepts combo input.
func is_in_combo_window() -> bool:
	if state is CombatAttackState:
		return (state as CombatAttackState)._phase == 2
	return false


## Get the name of the current combat state.
func get_current_state_name() -> StringName:
	if state:
		return StringName(state.name)
	return &""
