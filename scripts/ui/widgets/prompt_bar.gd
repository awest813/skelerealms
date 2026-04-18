class_name SKPromptBar
extends Control
## Contract for a prompt bar widget — shows contextual action prompts
## at the bottom of the screen (e.g. "E: Talk", "R: Pickup", "Space: Jump").
##
## Subclass and override to provide your styled implementation.


## Set the prompts to display.
## [param prompts] is an array of dictionaries, each with:
##   "action" (StringName): the input action name.
##   "label" (String): the display text.
func set_prompts(prompts:Array[Dictionary]) -> void:
	pass


## Clear all displayed prompts.
func clear_prompts() -> void:
	pass


## Add a single prompt without replacing existing ones.
func add_prompt(action:StringName, label:String) -> void:
	pass


## Remove a specific prompt by action name.
func remove_prompt(action:StringName) -> void:
	pass
