class_name SKVitalsWidget
extends Control
## Contract for a vitals display widget (health, stamina, magicka bars).
##
## Subclass this and override [method update_vitals] to render your
## custom health bars. The HUD shell calls this automatically when
## [signal VitalsComponent.vitals_updated] fires.


## Update the displayed vitals from a vitals dictionary.
## Expected keys: "health", "max_health", "moxie", "max_moxie",
## "will", "max_will".
func update_vitals(data:Dictionary) -> void:
	pass
