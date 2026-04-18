class_name SKListItem
extends Control
## Contract for a list item widget — used in inventory rows,
## quest entries, dialogue choices, and similar lists.
##
## Subclass and override to provide your styled implementation.


## Emitted when this item is selected.
signal item_selected(data:Variant)
## Emitted when this item is activated (double-click, enter).
signal item_activated(data:Variant)

## Arbitrary data payload associated with this list item.
var item_data:Variant


## Set the display content of this list item.
func set_content(label:String, icon:Texture2D = null, sublabel:String = "") -> void:
	pass


## Set the selected state visually.
func set_selected(selected:bool) -> void:
	pass
