class_name SKInteractionPrompt
extends Control
## Contract for an interaction prompt widget.
##
## Subclass and override [method show_prompt] / [method hide_prompt] to
## display contextual interaction hints (e.g. "E: Talk", "R: Pickup").


## Show the prompt with the given text and input action name.
func show_prompt(text:String, action:StringName = &"interact") -> void:
	pass


## Hide the prompt.
func hide_prompt() -> void:
	pass
