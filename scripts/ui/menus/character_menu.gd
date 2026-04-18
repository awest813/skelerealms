class_name SKCharacterMenu
extends Control
## Contract for a character/stats menu page.
##
## Subclass and override to display attributes, skills, and
## equipment for the player character.


## Populate the character sheet with attribute and skill data.
## [param attributes] is a dictionary of attribute name → value.
## [param skills] is a dictionary of skill name → level/XP data.
func populate(attributes:Dictionary, skills:Dictionary) -> void:
	pass


## Update the equipment display.
## [param equipment] maps slot names to equipped item identifiers.
func update_equipment(equipment:Dictionary) -> void:
	pass
