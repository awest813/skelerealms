class_name SKBarterMenu
extends Control
## Contract for a barter/trade menu popup.
##
## Subclass and override to display the vendor and customer inventories
## for trading. The [SKUIManager] wires barter system signals to this.


## Populate the vendor's item list.
func populate_vendor(items:Array) -> void:
	pass


## Populate the customer's (player's) item list.
func populate_customer(items:Array) -> void:
	pass


## Update the displayed transaction totals.
func update_totals(vendor_total:float, customer_total:float) -> void:
	pass


## Clear the barter display.
func clear() -> void:
	pass
