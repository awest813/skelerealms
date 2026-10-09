## Integration tests for character progression (WS-E: XP, perks, origins).
## Run with the GUT framework (https://github.com/bitwes/Gut).
extends GutTest


class _ManagerFixture extends SKEntityManager:
	func _ready() -> void:
		pass


class _EntityFixture extends SKEntity:
	func _process(_delta: float) -> void:
		pass

	func get_component(type: String) -> SKEntityComponent:
		return get_node_or_null(type) as SKEntityComponent


var _manager: SKEntityManager
var _old_config = null
var _owned_perks: Array = []


func before_each() -> void:
	_manager = _ManagerFixture.new()
	add_child_autofree(_manager)
	_old_config = SkeleRealmsGlobal.config
	if SkeleRealmsGlobal.config == null:
		SkeleRealmsGlobal.config = load("res://sk_config.tres")
	SkeleRealmsGlobal.config.compile()


func after_each() -> void:
	SkeleRealmsGlobal.config = _old_config
	for pid in _owned_perks:
		PerkSystem.unregister_perk(StringName(pid))
	_owned_perks.clear()


# ── Fixture builders ─────────────────────────────────────────────────────


func _make_entity(ref: StringName, with_perks := true) -> SKEntity:
	var e := _EntityFixture.new()
	e.name = ref
	e.form_id = &"npc"
	e.world = &"w"
	e.position = Vector3.ZERO
	var skills := SkillsComponent.new()
	skills.skills = {&"sneak": 1} as Dictionary
	e.add_child(skills)
	var attrs := AttributesComponent.new()
	attrs.attributes = {&"strength": 5} as Dictionary
	e.add_child(attrs)
	e.add_child(VitalsComponent.new())
	if with_perks:
		e.add_child(PerkComponent.new())
	for c in e.get_children():
		(c as Node).set_process(false)
		(c as Node).set_physics_process(false)
	_manager._add_entity_raw(e)
	return e


func _skills_of(ref: StringName) -> SkillsComponent:
	return (_manager.entities[ref] as SKEntity).get_component("SkillsComponent") as SkillsComponent


func _fx_vital(amount: float) -> PerkEffect:
	var fx := PerkEffect.new()
	fx.type = "vital_max"
	fx.vital = "health"
	fx.amount = amount
	return fx


func _fx_rate(skill: StringName, mult: float) -> PerkEffect:
	var fx := PerkEffect.new()
	fx.type = "skill_xp_rate"
	fx.skill_id = skill
	fx.multiplier = mult
	return fx


func _fx_flag(flag: StringName) -> PerkEffect:
	var fx := PerkEffect.new()
	fx.type = "flag"
	fx.flag = flag
	return fx


func _perk(id: StringName, level := 0, skills: Dictionary = {}, prereqs: Array = [], effects: Array = []) -> Perk:
	var p := Perk.new()
	p.id = id
	p.perk_name = "Test %s" % id
	p.required_level = level
	for k in skills:
		p.required_skills[k] = skills[k]
	for r in prereqs:
		p.required_perks.append(r)
	for fx in effects:
		p.effects.append(fx)
	_owned_perks.append(StringName(id))
	PerkSystem.register_perk(p)
	return p


# ── Skill and character XP ───────────────────────────────────────────────


func test_skill_xp_levels_with_carryover() -> void:
	_make_entity(&"e1")
	var skills := _skills_of(&"e1")
	watch_signals(skills)
	skills.add_skill_xp(&"sneak", 125)
	assert_eq(skills.skills[&"sneak"], 2, "125 XP must level sneak 1→2 (formula 100+25/L).")
	assert_eq(int(skills.skill_xp[&"sneak"]), 0, "Exact costs must leave no remainder.")
	assert_signal_emit_count(skills, "skill_levelled_up", 1, "Level-up must emit.")
	skills.add_skill_xp(&"sneak", 500)
	assert_eq(skills.skills[&"sneak"], 4, "500 XP must climb two more levels.")
	assert_eq(int(skills.skill_xp[&"sneak"]), 175, "Remainder must carry forward.")
	assert_signal_emit_count(skills, "skill_levelled_up", 3, "Each level must emit.")


func test_skill_xp_rejects_unknown_and_negatives() -> void:
	_make_entity(&"e1")
	var skills := _skills_of(&"e1")
	skills.add_skill_xp(&"nope", 100)
	assert_false(skills.skill_xp.has(&"nope"), "Unknown skills must not ledger.")
	skills.add_skill_xp(&"sneak", -50)
	assert_eq(int(skills.skill_xp.get(&"sneak", 0)), 0, "Negative awards must not drain.")


func test_character_xp_levels_and_funds_points() -> void:
	_make_entity(&"e1")
	var skills := _skills_of(&"e1")
	watch_signals(skills)
	skills.add_character_xp(200)
	assert_eq(skills.level, 1, "200 XP must level 0→1 (formula 200+50/L).")
	assert_signal_emit_count(skills, "character_levelled_up", 1, "Character level must emit.")
	var perks := (_manager.entities[&"e1"] as SKEntity).get_component("PerkComponent") as PerkComponent
	assert_eq(perks.perk_points, 1, "Levels must fund perk points.")


func test_xp_banks_without_config() -> void:
	_make_entity(&"e1")
	SkeleRealmsGlobal.config = null
	var skills := _skills_of(&"e1")
	skills.add_skill_xp(&"sneak", 500)
	skills.add_character_xp(500)
	assert_eq(int(skills.skill_xp[&"sneak"]), 500, "XP must bank, not crash.")
	assert_eq(skills.skills[&"sneak"], 1, "No leveling without formulas.")
	assert_eq(skills.level, 0, "No character leveling without formulas.")
	SkeleRealmsGlobal.config = _old_config
	if SkeleRealmsGlobal.config == null:
		SkeleRealmsGlobal.config = load("res://sk_config.tres")
	SkeleRealmsGlobal.config.compile()


# ── Perk rules ───────────────────────────────────────────────────────────


func test_can_take_matrix() -> void:
	_make_entity(&"e1")
	var e := _manager.entities[&"e1"] as SKEntity
	_perk(&"open")
	_perk(&"veteran", 5)
	_perk(&"sneaky", 0, {&"sneak": 5})
	_perk(&"combo", 0, {}, [&"open"])
	assert_eq(PerkSystem.can_take(e, &"missing")["ok"], false, "Unknown perks must fail.")
	assert_eq(PerkSystem.can_take(e, &"open")["ok"], false, "Broke takes must fail.")
	var comp := e.get_component("PerkComponent") as PerkComponent
	comp.perk_points = 10
	assert_eq(PerkSystem.can_take(e, &"open")["ok"], true, "Funded takes must pass.")
	assert_eq(PerkSystem.can_take(e, &"veteran")["ok"], false, "Level gates must hold.")
	assert_eq(PerkSystem.can_take(e, &"sneaky")["ok"], false, "Skill gates must hold.")
	assert_eq(PerkSystem.can_take(e, &"combo")["ok"], false, "Prereq chains must hold.")
	assert_eq(PerkSystem.can_take(null, &"open")["ok"], false, "Null entities must fail.")


func test_grant_spends_and_applies() -> void:
	_make_entity(&"e1")
	var e := _manager.entities[&"e1"] as SKEntity
	var comp := e.get_component("PerkComponent") as PerkComponent
	var vitals := e.get_component("VitalsComponent") as VitalsComponent
	_perk(&"tough", 0, {}, [], [_fx_vital(25.0), _fx_flag(&"scary")])
	comp.perk_points = 1
	watch_signals(PerkSystem)
	assert_true(PerkSystem.grant(e, &"tough"), "Funded grants must succeed.")
	assert_eq(comp.perk_points, 0, "Grants must spend the point.")
	assert_true(comp.granted.has(&"tough"), "Grants must record.")
	assert_eq(vitals.vitals["max_health"], 125.0, "Vital max must rise.")
	assert_eq(vitals.vitals["health"], 125.0, "Grant must heal alongside.")
	assert_true(PerkSystem.has_flag(e, &"scary"), "Flags must read back.")
	assert_false(PerkSystem.has_flag(e, &"nope"), "Missing flags must read false.")
	assert_signal_emit_count(PerkSystem, "perk_granted", 1, "Grants must emit.")
	assert_false(PerkSystem.grant(e, &"tough"), "Duplicates must fail.")
	comp.perk_points = 0
	_perk(&"other")
	assert_false(PerkSystem.grant(e, &"other"), "Broke grants must fail.")


func test_xp_rate_perks_shape_awards() -> void:
	_make_entity(&"e1")
	_make_entity(&"e2")
	var e1 := _manager.entities[&"e1"] as SKEntity
	_perk(&"fast", 0, {}, [], [_fx_rate(&"sneak", 2.0)])
	var comp := e1.get_component("PerkComponent") as PerkComponent
	comp.perk_points = 1
	assert_true(PerkSystem.grant(e1, &"fast"))
	(_skills_of(&"e1")).add_skill_xp(&"sneak", 100)
	(_skills_of(&"e2")).add_skill_xp(&"sneak", 100)
	assert_eq((_skills_of(&"e1")).skills[&"sneak"], 2, "Doubled awards must level (125-cost level).")
	assert_eq(int((_skills_of(&"e1")).skill_xp[&"sneak"]), 75, "Remainder must carry after the level.")
	assert_eq((_skills_of(&"e2")).skills[&"sneak"], 1, "Flat awards must not level.")
	assert_eq(int((_skills_of(&"e2")).skill_xp[&"sneak"]), 100, "Unperked awards stay flat.")
	assert_eq(PerkSystem.skill_xp_rate(null, &"sneak"), 1.0, "Null entities read baseline.")


func test_validate_perk() -> void:
	var bad := Perk.new()
	bad.id = &"bad"
	var fx1 := PerkEffect.new()
	fx1.type = "mystery"
	var fx2 := PerkEffect.new()
	fx2.type = "vital_max"
	fx2.vital = "luck"
	var fx3 := PerkEffect.new()
	fx3.type = "skill_xp_rate"
	fx3.multiplier = -2.0
	bad.effects = [fx1, fx2, fx3]
	var issues: Array = PerkSystem.validate_perk(bad)
	assert_eq(issues.size(), 3, "Each defect must report.")
	var kinds := {}
	for issue in issues:
		kinds[str(issue["type"])] = true
	assert_true(kinds.has("bad_effect") and kinds.has("bad_vital") and kinds.has("bad_multiplier"), "Types must be named.")
	var empty_id := Perk.new()
	assert_eq(str(PerkSystem.validate_perk(empty_id)[0]["type"]), "missing_id", "Missing ids must flag.")
	assert_eq(PerkSystem.validate_perk(_perk(&"clean")), [], "Sound perks validate clean.")


# ── Origins and persistence ──────────────────────────────────────────────


func test_origin_applies_starting_package() -> void:
	_make_entity(&"e1")
	var e := _manager.entities[&"e1"] as SKEntity
	var origin := Origin.new()
	origin.id = &"ashlander"
	origin.attribute_mods = {&"strength": 2, &"agility": 3}
	origin.skill_levels = {&"sneak": 5, &"alchemy": 2}
	origin.starting_perks = [&"tough"]
	_perk(&"tough", 0, {}, [], [_fx_vital(10.0)])
	assert_true(origin.apply_to(e), "Complete sheets must apply.")
	var attrs := e.get_component("AttributesComponent") as AttributesComponent
	assert_eq(int(attrs.attributes[&"strength"]), 7, "Attribute mods must stack.")
	assert_eq(int(attrs.attributes[&"agility"]), 3, "Missing attributes must seed from zero.")
	var skills := _skills_of(&"e1")
	assert_eq(int(skills.skills[&"sneak"]), 5, "Skill minimums must raise.")
	assert_eq(int(skills.skills[&"alchemy"]), 2, "New skills must seed.")
	var vitals := e.get_component("VitalsComponent") as VitalsComponent
	assert_eq(vitals.vitals["max_health"], 110.0, "Origin perks must apply effects.")
	assert_true((e.get_component("PerkComponent") as PerkComponent).granted.has(&"tough"), "Origin perks must record.")


func test_origin_rejects_bare_entities() -> void:
	var bare := _EntityFixture.new()
	bare.name = &"bare"
	_manager._add_entity_raw(bare)
	var origin := Origin.new()
	origin.id = &"oops"
	assert_false(origin.apply_to(null), "Null entities must fail.")
	assert_false(origin.apply_to(bare), "Sheets without stats must fail.")


func test_perk_component_save_load() -> void:
	_make_entity(&"e1")
	var comp := (_manager.entities[&"e1"] as SKEntity).get_component("PerkComponent") as PerkComponent
	comp.granted = [&"a", &"b"] as Array[StringName]
	comp.perk_points = 3
	var fresh := PerkComponent.new()
	fresh.load_data(comp.save())
	assert_eq(fresh.granted, [&"a", &"b"], "Grants must persist.")
	assert_eq(fresh.perk_points, 3, "Points must persist.")
	fresh.load_data({"granted": ["x"], "perk_points": -5})
	assert_eq(fresh.granted, [&"x"], "String ids must restore.")
	assert_eq(fresh.perk_points, 0, "Points must clamp.")
