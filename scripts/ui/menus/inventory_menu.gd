class_name SKInventoryMenu
extends Control
## Contract for an inventory menu page.
##
## Subclass and override [method populate] to display the player's
## inventory items and currencies.


## Populate the inventory display.
## [param items] is an array of item data (RefIDs or item info dicts).
## [param currencies] is a dictionary of currency name → amount.
func populate(items:Array, currencies:Dictionary) -> void:
	pass


## Called when the player selects an item.
## Override to handle item inspection, equipping, dropping, etc.
func on_item_selected(item_id:StringName) -> void:
	pass
