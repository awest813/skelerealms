class_name Origin
extends Resource
## One playable origin (race, background, upbringing) for character creation.
## Origins are starting packages, not classes: attribute modifiers stack onto
## existing values, skills set minimums, and listed perks grant free.
## Apply once at character creation via [method apply_to].


## Unique ID, e.g. &"ashlander".
@export var id: StringName
## Display name.
@export var origin_name: String
## Flavour text for the creation menu.
@export_multiline var description: String
## Attribute adjustments added to current values (may be negative).
@export var attribute_mods: Dictionary = {}
## Starting skill minimums: skill id String -> level int.
@export var skill_levels: Dictionary = {}
## Perk ids granted free (no point cost, no requirement checks).
@export var starting_perks: Array[StringName] = []


## Apply this origin to an entity. Requires AttributesComponent and
## SkillsComponent; perks apply when a PerkComponent is present (warns
## without one). Returns false when the character sheet is incomplete.
func apply_to(entity: SKEntity) -> bool:
	if entity == null:
		return false
	if not entity.has_component("AttributesComponent") or not entity.has_component("SkillsComponent"):
		push_warning("Origin: '%s' needs AttributesComponent and SkillsComponent." % id)
		return false
	var attrs := entity.get_component("AttributesComponent") as AttributesComponent
	if attrs:
		for key in attribute_mods:
			(attrs.attributes as Dictionary)[key] = int((attrs.attributes as Dictionary).get(key, 0)) + int(attribute_mods[key])
		attrs.dirty = true
	var skills := entity.get_component("SkillsComponent") as SkillsComponent
	if skills:
		for key in skill_levels:
			var want := int(skill_levels[key])
			(skills.skills as Dictionary)[key] = maxi(int((skills.skills as Dictionary).get(key, 0)), want)
		skills.dirty = true
	if starting_perks.is_empty():
		return true
	if not entity.has_component("PerkComponent"):
		push_warning("Origin: '%s' lists starting perks but '%s' has no PerkComponent." % [id, entity.name])
		return true
	var perks := entity.get_component("PerkComponent") as PerkComponent
	if perks == null:
		return true
	for pid in starting_perks:
		if not (perks.granted as Array).has(pid):
			(perks.granted as Array).append(pid)
			PerkSystem.apply_effects(entity, pid)
	return true
