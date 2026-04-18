class_name SKStatRow
extends Control
## Contract for a stat row widget — a label + value display with
## an optional progress bar for character sheets and stat panels.
##
## Subclass and override to provide your styled implementation.


## Set the stat display.
## [param label]: stat name (e.g. "Strength").
## [param value]: stat value as a string (e.g. "15").
## [param ratio]: optional 0.0–1.0 ratio for a progress bar fill.
func set_stat(label:String, value:String, ratio:float = -1.0) -> void:
	pass
