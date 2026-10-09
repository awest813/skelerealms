class_name PerkComponent
extends SKEntityComponent
## Tracks granted perks and spendable perk points for one entity.
## Gains a point on every sibling character level-up. Pair with
## PerkSystem, which enforces requirements and applies effects.


## Granted perk ids.
var granted: Array[StringName] = []
## Unspent perk points.
var perk_points: int = 0


## Emitted when the point total changes.
signal perk_points_changed(count: int)


func _init() -> void:
	name = "PerkComponent"


func _ready() -> void:
	super._ready()
	if parent_entity and parent_entity.has_component("SkillsComponent"):
		var skills := parent_entity.get_component("SkillsComponent") as SkillsComponent
		if skills and not skills.character_levelled_up.is_connected(_on_character_levelled_up.bind()):
			skills.character_levelled_up.connect(_on_character_levelled_up.bind())


func _on_character_levelled_up(_new_level: int) -> void:
	perk_points += 1
	perk_points_changed.emit(perk_points)


func save() -> Dictionary:
	return {
		"granted": granted.duplicate(),
		"perk_points": perk_points,
	}


func load_data(data: Dictionary) -> void:
	granted.clear()
	for pid in (data.get("granted", []) as Array):
		granted.append(StringName(str(pid)))
	perk_points = maxi(0, int(data.get("perk_points", 0)))
	dirty = false
