## Unit tests for the Skelerealms combat subsystem.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## Tests cover:
##   - CombatAction: damage packet building, crit multiplier, affordability, cost payment
##   - CombatantComponent: poise damage, poise restore, resistance application,
##     invincibility/blocking/parrying state, block and poise multipliers
##   - CombatStateMachine: state transitions, apply_stagger/knockdown/die,
##     can_act, queue_combo, is_in_combo_window
extends GutTest


# ── Helpers ───────────────────────────────────────────────────────────────


## Build a minimal CombatAction with configurable fields.
func _make_action(
	action_type: CombatAction.ActionType = CombatAction.ActionType.MELEE,
	base_damage: Dictionary = {&"blunt": 10.0},
	startup: float = 0.1,
	active: float = 0.1,
	recovery: float = 0.2,
	poise: float = 20.0,
) -> CombatAction:
	var a := CombatAction.new()
	a.action_type = action_type
	a.base_damage = base_damage
	a.startup_duration = startup
	a.active_duration = active
	a.recovery_duration = recovery
	a.poise_damage = poise
	a.crit_chance = 0.0  # deterministic by default
	return a


## Build a VitalsComponent stub with set values.
class _StubVitals extends Node:
	var vitals: Dictionary = {
		"health": 100.0,
		"moxie": 50.0,
		"will": 50.0,
		"max_health": 100.0,
		"max_moxie": 100.0,
		"max_will": 100.0,
		"return_to_will": 0.0,
	}

	func change_moxie(delta: float) -> void:
		vitals["moxie"] = clampf(vitals["moxie"] + delta, 0.0, vitals["max_moxie"])

	func change_will(delta: float) -> void:
		vitals["will"] = clampf(vitals["will"] + delta, 0.0, vitals["max_will"])


func _make_vitals(moxie: float = 50.0, will: float = 50.0) -> _StubVitals:
	var v := _StubVitals.new()
	v.vitals["moxie"] = moxie
	v.vitals["will"] = will
	add_child(v)
	return v


## Build a standalone CombatantComponent (no scene tree entity required).
func _make_combatant(max_poise: float = 100.0) -> CombatantComponent:
	var c := CombatantComponent.new()
	c.max_poise = max_poise
	c.poise_regen_rate = 10.0
	c.poise_regen_delay = 3.0
	add_child_autofree(c)
	c.poise = max_poise  # manually set since _entity_ready won't fire
	return c


# ── CombatAction: build_damage_packet ────────────────────────────────────


func test_action_damage_packet_contains_expected_effects() -> void:
	var action := _make_action(CombatAction.ActionType.MELEE, {&"blunt": 15.0})
	var packet := action.build_damage_packet("attacker")
	assert_eq(packet.damage_effects[&"blunt"], 15.0)


func test_action_damage_packet_no_crit_when_chance_zero() -> void:
	var action := _make_action()
	action.crit_chance = 0.0
	action.base_damage = {&"blunt": 10.0}
	var packet := action.build_damage_packet("attacker")
	assert_false(packet.is_critical)
	assert_eq(packet.damage_effects[&"blunt"], 10.0)


func test_action_damage_packet_always_crit_when_chance_one() -> void:
	var action := _make_action()
	action.crit_chance = 1.0
	action.crit_multiplier = 2.0
	action.base_damage = {&"blunt": 10.0}
	var packet := action.build_damage_packet("attacker")
	assert_true(packet.is_critical)
	assert_almost_eq(packet.damage_effects[&"blunt"], 20.0, 0.001)


func test_action_total_duration() -> void:
	var action := _make_action(CombatAction.ActionType.MELEE, {}, 0.2, 0.15, 0.3)
	assert_almost_eq(action.get_total_duration(), 0.65, 0.001)


func test_action_offender_name_in_packet() -> void:
	var action := _make_action()
	var packet := action.build_damage_packet("player_hero")
	assert_eq(packet.offender, "player_hero")


func test_action_source_weapon_in_packet() -> void:
	var action := _make_action()
	var packet := action.build_damage_packet("attacker", &"iron_sword")
	assert_eq(packet.source_weapon, &"iron_sword")


# ── CombatAction: can_afford / pay_cost ──────────────────────────────────


func test_action_can_afford_when_no_cost() -> void:
	var action := _make_action()
	action.stamina_cost = 0.0
	action.mana_cost = 0.0
	var vitals := _make_vitals(0.0, 0.0)
	# Cast to VitalsComponent for the API — duck-typing allowed here.
	assert_true(action.can_afford(vitals as VitalsComponent))


func test_action_cannot_afford_when_moxie_low() -> void:
	var action := _make_action()
	action.stamina_cost = 30.0
	var vitals := _make_vitals(20.0, 50.0)
	assert_false(action.can_afford(vitals as VitalsComponent))


func test_action_cannot_afford_when_will_low() -> void:
	var action := _make_action()
	action.mana_cost = 60.0
	var vitals := _make_vitals(50.0, 30.0)
	assert_false(action.can_afford(vitals as VitalsComponent))


func test_action_pay_cost_deducts_moxie() -> void:
	var action := _make_action()
	action.stamina_cost = 10.0
	var vitals := _make_vitals(50.0, 50.0)
	action.pay_cost(vitals as VitalsComponent)
	assert_almost_eq(vitals.vitals["moxie"], 40.0, 0.001)


func test_action_pay_cost_deducts_will() -> void:
	var action := _make_action()
	action.mana_cost = 20.0
	var vitals := _make_vitals(50.0, 50.0)
	action.pay_cost(vitals as VitalsComponent)
	assert_almost_eq(vitals.vitals["will"], 30.0, 0.001)


# ── CombatantComponent: poise ─────────────────────────────────────────────


func test_combatant_poise_starts_at_max() -> void:
	var c := _make_combatant(100.0)
	assert_almost_eq(c.poise, 100.0, 0.001)


func test_combatant_apply_poise_damage_reduces_poise() -> void:
	var c := _make_combatant(100.0)
	c.apply_poise_damage(30.0)
	assert_almost_eq(c.poise, 70.0, 0.001)


func test_combatant_poise_break_returns_true() -> void:
	var c := _make_combatant(50.0)
	var broken := c.apply_poise_damage(60.0)
	assert_true(broken)


func test_combatant_poise_break_only_once() -> void:
	var c := _make_combatant(50.0)
	c.apply_poise_damage(60.0) # breaks poise
	var second_break := c.apply_poise_damage(10.0) # should not break again
	assert_false(second_break)


func test_combatant_poise_break_emits_signal() -> void:
	var c := _make_combatant(50.0)
	watch_signals(c)
	c.apply_poise_damage(60.0)
	assert_signal_emitted(c, "poise_broken")


func test_combatant_restore_poise_resets_to_max() -> void:
	var c := _make_combatant(100.0)
	c.apply_poise_damage(60.0)
	c.restore_poise()
	assert_almost_eq(c.poise, 100.0, 0.001)


func test_combatant_restore_poise_emits_signal() -> void:
	var c := _make_combatant(100.0)
	c.apply_poise_damage(110.0)
	watch_signals(c)
	c.restore_poise()
	assert_signal_emitted(c, "poise_restored")


# ── CombatantComponent: resistances ───────────────────────────────────────


func test_combatant_default_resistance_is_one() -> void:
	var c := _make_combatant()
	assert_almost_eq(c.get_resistance(&"fire"), 1.0, 0.001)


func test_combatant_custom_resistance_applied() -> void:
	var c := _make_combatant()
	c.resistances[&"fire"] = 0.5
	assert_almost_eq(c.get_resistance(&"fire"), 0.5, 0.001)


func test_combatant_apply_resistances_modifies_packet() -> void:
	var c := _make_combatant()
	c.resistances[&"blunt"] = 0.5
	var action := _make_action(CombatAction.ActionType.MELEE, {&"blunt": 20.0})
	var packet := action.build_damage_packet("attacker")
	var modified := c.apply_resistances(packet)
	assert_almost_eq(modified.damage_effects[&"blunt"], 10.0, 0.001)


func test_combatant_apply_resistances_does_not_mutate_original() -> void:
	var c := _make_combatant()
	c.resistances[&"blunt"] = 0.0
	var action := _make_action(CombatAction.ActionType.MELEE, {&"blunt": 20.0})
	var packet := action.build_damage_packet("attacker")
	c.apply_resistances(packet)
	assert_almost_eq(packet.damage_effects[&"blunt"], 20.0, 0.001, "Original packet must be unchanged.")


# ── CombatantComponent: state flags ───────────────────────────────────────


func test_combatant_invincibility_signal() -> void:
	var c := _make_combatant()
	watch_signals(c)
	c.invincible = true
	assert_signal_emitted(c, "invincibility_changed")


func test_combatant_blocking_signal() -> void:
	var c := _make_combatant()
	watch_signals(c)
	c.blocking = true
	assert_signal_emitted(c, "block_state_changed")


func test_combatant_parrying_signal() -> void:
	var c := _make_combatant()
	watch_signals(c)
	c.parrying = true
	assert_signal_emitted(c, "parry_state_changed")


func test_combatant_invincibility_no_duplicate_signal() -> void:
	var c := _make_combatant()
	c.invincible = true
	watch_signals(c)
	c.invincible = true  # same value — should NOT re-emit
	assert_signal_not_emitted(c, "invincibility_changed")


# ── CombatStateMachine: states ────────────────────────────────────────────


## Build a minimal CombatStateMachine with a dummy entity stub.
class _StubEntity extends Node:
	func get_component(_name: String) -> Node:
		return null


func _make_csm() -> CombatStateMachine:
	var entity := _StubEntity.new()
	entity.name = "stub_entity"
	add_child_autofree(entity)
	var csm := CombatStateMachine.new()
	entity.add_child(csm)
	csm.initialize(entity as SKEntity)
	return csm


func test_csm_starts_in_idle() -> void:
	var csm := _make_csm()
	assert_eq(csm.get_current_state_name(), &"Idle")


func test_csm_can_act_in_idle() -> void:
	var csm := _make_csm()
	assert_true(csm.can_act())


func test_csm_apply_stagger_transitions_to_stagger() -> void:
	var csm := _make_csm()
	csm.apply_stagger(0.3)
	assert_eq(csm.get_current_state_name(), &"Stagger")


func test_csm_apply_knockdown_transitions_to_knockdown() -> void:
	var csm := _make_csm()
	csm.apply_knockdown(0.5)
	assert_eq(csm.get_current_state_name(), &"Knockdown")


func test_csm_die_transitions_to_death() -> void:
	var csm := _make_csm()
	csm.die()
	assert_eq(csm.get_current_state_name(), &"Death")


func test_csm_cannot_stagger_from_death() -> void:
	var csm := _make_csm()
	csm.die()
	csm.apply_stagger(0.3)
	assert_eq(csm.get_current_state_name(), &"Death",
		"Stagger should not interrupt death state.")


func test_csm_cannot_knockdown_from_death() -> void:
	var csm := _make_csm()
	csm.die()
	csm.apply_knockdown(0.5)
	assert_eq(csm.get_current_state_name(), &"Death",
		"Knockdown should not interrupt death state.")


func test_csm_cannot_act_after_death() -> void:
	var csm := _make_csm()
	csm.die()
	assert_false(csm.can_act())


func test_csm_apply_stagger_clears_current_action() -> void:
	var csm := _make_csm()
	csm._current_action = _make_action()
	csm.apply_stagger()
	assert_null(csm._current_action)


func test_csm_apply_knockdown_clears_current_action() -> void:
	var csm := _make_csm()
	csm._current_action = _make_action()
	csm.apply_knockdown()
	assert_null(csm._current_action)


func test_csm_die_clears_current_action() -> void:
	var csm := _make_csm()
	csm._current_action = _make_action()
	csm.die()
	assert_null(csm._current_action)


func test_csm_not_in_combo_window_when_idle() -> void:
	var csm := _make_csm()
	assert_false(csm.is_in_combo_window())


func test_csm_queue_combo_returns_false_when_idle() -> void:
	var csm := _make_csm()
	var ok := csm.queue_combo(_make_action())
	assert_false(ok)
