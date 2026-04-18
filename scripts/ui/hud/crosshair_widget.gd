class_name SKCrosshair
extends Control
## Contract for a crosshair widget.
##
## Subclass and override [method set_state] to change crosshair appearance
## based on what the player is looking at.


## Set the crosshair visual state.
## Common states: &"default", &"hostile", &"interactive", &"hidden".
func set_state(state_name:StringName) -> void:
	pass
