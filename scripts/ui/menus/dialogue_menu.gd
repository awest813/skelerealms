class_name SKDialogueMenu
extends Control
## Contract for a dialogue menu popup.
##
## Subclass and override the display methods. The [SKUIManager] wires
## [signal DialogueSystem.dialogue_started] to show this popup and
## feeds lines and choices through these methods.


## Display a line of dialogue from a speaker.
func show_line(speaker:String, text:String) -> void:
	pass


## Display available dialogue choices.
## [param choices] is an array of choice data (text, conditions met, etc.).
func show_choices(choices:Array) -> void:
	pass


## Clear the dialogue display.
func clear() -> void:
	pass
