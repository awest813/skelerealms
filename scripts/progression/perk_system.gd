extends Node
## Autoload singleton: the perk registry, grant rules, and live effect queries.
##
## Perk definitions live here (registered at startup, like templates);
## grants live on [PerkComponent] (saved with their entity), so this system
## keeps no save data and cannot drift.
## NOTE: intentionally no class_name — like GameInfo and SaveSystem, the
## autoload instance is referenced dynamically by name.


## Emitted when a perk is granted: entity ref-ID and perk id.
signal perk_granted(ref_id: StringName, perk_id: StringName)


## perk_id -> Perk. Templates persist across resets.
var _perks: Dictionary = {}


## Register a [Perk] definition. Re-registering replaces it.
func register_perk(perk: Perk) -> void:
	_perks[perk.id] = perk


## Remove a perk definition (mod unloading, test isolation).
func unregister_perk(perk_id: StringName) -> void:
	_perks.erase(perk_id)


## Returns true if a perk is registered.
func has_perk(perk_id: StringName) -> bool:
	return _perks.has(perk_id)


## Whether an entity currently holds a granted perk.
func entity_has_perk(entity: SKEntity, perk_id: StringName) -> bool:
	if entity == null or not entity.has_component("PerkComponent"):
		return false
	return ((entity.get_component("PerkComponent") as PerkComponent).granted as Array).has(perk_id)


## Can this entity take this perk? Returns {ok: bool, reason: String}
## for UI display ("requires level 5", "already granted", ...).
func can_take(entity: SKEntity, perk_id: StringName) -> Dictionary:
	if entity == null:
		return {"ok": false, "reason": "No entity."}
	if not _perks.has(perk_id):
		return {"ok": false, "reason": "Unknown perk."}
	if not entity.has_component("PerkComponent"):
		return {"ok": false, "reason": "No perk tracking."}
	var comp := entity.get_component("PerkComponent") as PerkComponent
	if comp == null:
		return {"ok": false, "reason": "No perk tracking."}
	if (comp.granted as Array).has(perk_id):
		return {"ok": false, "reason": "Already granted."}
	if comp.perk_points < 1:
		return {"ok": false, "reason": "No perk points."}
	var def: Perk = _perks[perk_id]
	if entity.has_component("SkillsComponent"):
		var skills := entity.get_component("SkillsComponent") as SkillsComponent
		if skills and skills.level < def.required_level:
			return {"ok": false, "reason": "Requires character level %d." % def.required_level}
		for skill_id in def.required_skills:
			var have := int((skills.skills as Dictionary).get(StringName(skill_id), 0)) if skills else 0
			if have < int(def.required_skills[skill_id]):
				return {"ok": false, "reason": "Requires %s %d." % [skill_id, int(def.required_skills[skill_id])]}
	elif def.required_level > 0 or not (def.required_skills as Dictionary).is_empty():
		return {"ok": false, "reason": "No skills to qualify with."}
	for req in def.required_perks:
		if not (comp.granted as Array).has(req):
			return {"ok": false, "reason": "Requires perk '%s'." % req}
	return {"ok": true, "reason": ""}


## Grant a perk: spend a point, record it, apply immediate effects.
## Returns false (with a warning) when can_take fails.
func grant(entity: SKEntity, perk_id: StringName) -> bool:
	var check := can_take(entity, perk_id)
	if not bool(check["ok"]):
		push_warning("PerkSystem: cannot grant '%s': %s" % [perk_id, str(check["reason"])])
		return false
	var comp := entity.get_component("PerkComponent") as PerkComponent
	comp.perk_points -= 1
	(comp.granted as Array).append(perk_id)
	apply_effects(entity, perk_id)
	perk_granted.emit(entity.name, perk_id)
	return true


## Apply the immediate (non-passive) effects of a perk: vital_max raises
## the max and heals alongside. Passive skill_xp_rate/flag effects are
## read live, never snapshotted. Unknown perks are ignored.
func apply_effects(entity: SKEntity, perk_id: StringName) -> void:
	var def: Perk = _perks.get(perk_id)
	if entity == null or def == null:
		return
	_apply_grant_effects(entity, def)


## Apply the immediate (non-passive) effects of a grant.
## Passive skill_xp_rate/flag effects are read live, never snapshotted.
func _apply_grant_effects(entity: SKEntity, def: Perk) -> void:
	if not entity.has_component("VitalsComponent"):
		return
	var vitals := entity.get_component("VitalsComponent") as VitalsComponent
	if vitals == null:
		return
	for effect: PerkEffect in def.effects:
		if effect.type != "vital_max":
			continue
		var key := "max_%s" % effect.vital
		(vitals.vitals as Dictionary)[key] = float((vitals.vitals as Dictionary).get(key, 100.0)) + effect.amount
		if effect.vital == "health":
			vitals.change_health(effect.amount)
		elif effect.vital == "moxie":
			vitals.change_moxie(effect.amount)
		elif effect.vital == "will":
			vitals.change_will(effect.amount)


## Multiplied skill-XP rate from granted perks (1.0 baseline).
## Consulted by SkillsComponent on every award.
func skill_xp_rate(entity: SKEntity, skill: StringName) -> float:
	if entity == null or not entity.has_component("PerkComponent"):
		return 1.0
	var comp := entity.get_component("PerkComponent") as PerkComponent
	if comp == null:
		return 1.0
	var mult := 1.0
	for pid in (comp.granted as Array):
		var def: Perk = _perks.get(pid)
		if def == null:
			continue
		for effect: PerkEffect in def.effects:
			if effect.type == "skill_xp_rate" and (effect.skill_id == &"" or effect.skill_id == skill):
				mult *= effect.multiplier
	return mult


## Whether any granted perk carries a flag marker.
func has_flag(entity: SKEntity, flag: StringName) -> bool:
	if entity == null or not entity.has_component("PerkComponent"):
		return false
	var comp := entity.get_component("PerkComponent") as PerkComponent
	if comp == null:
		return false
	for pid in (comp.granted as Array):
		var def: Perk = _perks.get(pid)
		if def == null:
			continue
		for effect: PerkEffect in def.effects:
			if effect.type == "flag" and effect.flag == flag:
				return true
	return false


## Validate a perk without registering it. Returns issue dicts with keys
## "type" and "detail". Empty means sound.
func validate_perk(def: Perk) -> Array:
	var issues: Array = []
	if def.id.is_empty():
		issues.append({"type": "missing_id", "detail": "Perk has no id."})
	for effect: PerkEffect in def.effects:
		if effect.type != "vital_max" and effect.type != "skill_xp_rate" and effect.type != "flag":
			issues.append({"type": "bad_effect", "detail": "Perk '%s' has unknown effect type '%s'." % [def.id, effect.type]})
		elif effect.type == "vital_max" and effect.vital != "health" and effect.vital != "moxie" and effect.vital != "will":
			issues.append({"type": "bad_vital", "detail": "Perk '%s' targets unknown vital '%s'." % [def.id, effect.vital]})
		elif effect.type == "skill_xp_rate" and effect.multiplier <= 0.0:
			issues.append({"type": "bad_multiplier", "detail": "Perk '%s' multiplier must be above zero." % def.id})
	return issues
