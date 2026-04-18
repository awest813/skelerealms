class_name SKCompassWidget
extends Control
## Contract for a compass widget.
##
## Subclass and override [method update_heading] to render a compass
## that tracks the camera or player direction.


## Update the compass to show the given heading in degrees (0–360).
func update_heading(degrees:float) -> void:
	pass
