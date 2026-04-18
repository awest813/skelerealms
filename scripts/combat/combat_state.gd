class_name CombatState
extends FSMState
## Base class for combat-specific states.
## Extends [FSMState] with a reference to the owning [CombatStateMachine]
## for convenient access to combat context.


## Typed reference to the parent combat state machine.
var combat_machine:CombatStateMachine:
	get:
		return state_machine as CombatStateMachine
