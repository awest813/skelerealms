class_name SKTooltip
extends Control
## Contract for a tooltip widget — a hover popup showing item details,
## ability descriptions, or other contextual information.
##
## Subclass and override to provide your styled implementation.
## The tooltip follows the mouse and appears after [member SKTheme.tooltip_delay].


## Set tooltip content.
## [param title]: bold heading text.
## [param description]: body text.
## [param stats]: optional dictionary of stat labels → values.
func set_content(title:String, description:String = "", stats:Dictionary = {}) -> void:
	pass


## Show the tooltip at the given position.
func show_at(pos:Vector2) -> void:
	global_position = pos
	visible = true


## Hide the tooltip.
func hide_tooltip() -> void:
	visible = false
