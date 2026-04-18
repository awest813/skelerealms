class_name SKStatusEffectBar
extends Control
## Contract for a status effect bar widget.
##
## Subclass and override [method update_effects] to display active
## buffs, debuffs, and other status effects on the HUD.


## Update the displayed status effects.
## [param effects] is an array of active effect identifiers or data.
func update_effects(effects:Array) -> void:
	pass
