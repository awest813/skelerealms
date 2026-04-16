class_name EquipmentComponent
extends SKEntityComponent


var equipment_slot:Dictionary

signal equipped(item:StringName, slot:StringName)
signal unequipped(item:StringName, slot:StringName)


func _init() -> void:
	name = "EquipmentComponent"


func _ready() -> void:
	super._ready()


func equip(item:StringName, slot:StringName, silent:bool = false) -> bool:
	# Get component
	var e = SKEntityManager.instance.get_entity(item)
	if not e:
		return false
	# Get item component
	var ic = e.get_component("ItemComponent")
	if not ic:
		return false
	# Get equippable data component
	var ec = (ic as ItemComponent).get_component("EquippableDataComponent")
	if not ec:
		return false
	# Check slot validity
	if not (ec as EquippableDataComponent).valid_slots.has(slot):
		return false
	# Unequip if already in slot so we ca nput it in a new slot
	unequip_item(item)

	equipment_slot[slot] = item
	dirty = true
	if not silent:
		equipped.emit(item, slot)
	return true


## Unequip anything in a slot.
func clear_slot(slot:StringName, silent:bool = false) -> void:
	if equipment_slot.has(slot):
		var to_unequip = equipment_slot[slot]
		equipment_slot[slot] = null
		dirty = true
		if not silent:
			unequipped.emit(to_unequip, slot)


## Unequip a specific item, no matter what slot it's in.
func unequip_item(item:StringName, silent:bool = false) -> void:
	for s in equipment_slot:
		if equipment_slot[s] == item:
			equipment_slot[s] = null
			dirty = true
			if not silent:
				unequipped.emit(item, s)
			return


func is_item_equipped(item:StringName, slot:StringName) -> bool:
	if not equipment_slot.has(slot):
		return false
	return equipment_slot[slot] == item


func is_slot_occupied(slot:StringName) -> Option:
	if equipment_slot.has(slot):
		return Option.wrap(equipment_slot[slot])
	else:
		return Option.none()


func save() -> Dictionary:
	dirty = false
	# Convert StringName keys/values to strings for JSON serialization
	var slots := {}
	for s in equipment_slot:
		slots[str(s)] = str(equipment_slot[s]) if equipment_slot[s] else ""
	return {
		"equipment_slot": slots,
	}


func load_data(data:Dictionary):
	var slot_data = data.get("equipment_slot", null)
	if slot_data is Dictionary:
		equipment_slot = {}
		for s in slot_data:
			var val = slot_data[s]
			if val is String and not val.is_empty():
				equipment_slot[StringName(s)] = StringName(val)
			else:
				equipment_slot[StringName(s)] = null
	dirty = false
