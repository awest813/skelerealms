class_name SKRadialSelector
extends Control
## Contract for a radial selector widget — a radial menu for quick-selecting
## weapons, spells, items, or abilities.
##
## Subclass and override to provide your styled implementation.


## Emitted when the player selects an option from the radial menu.
signal option_selected(option_id:StringName)
## Emitted when the radial menu is cancelled.
signal cancelled


## Populate the radial menu with selectable options.
## [param options] is an array of dictionaries with at minimum an "id"
## (StringName) and "label" (String) key. Optional: "icon" (Texture2D).
func set_options(options:Array[Dictionary]) -> void:
	pass


## Open the radial selector at screen center.
func open() -> void:
	visible = true


## Close the radial selector.
func close() -> void:
	visible = false
