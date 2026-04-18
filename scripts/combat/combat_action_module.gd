class_name CombatActionModule
extends AIModule
## AI module that selects which [CombatAction] to execute during combat.
##
## Evaluates available actions based on distance to target, resource
## availability, and target state to choose the best combat move.
## Feeds the chosen action into the entity's [CombatStateMachine].


## Pool of actions this NPC can perform.
@export var available_actions:Array[CombatAction] = []
## Preferred engagement range — below this, prefer melee.
@export var melee_range:float = 3.0
## Seconds between action decisions.
@export var decision_interval:float = 0.5

var _decision_timer:float = 0.0
var _combat_state_machine:CombatStateMachine


func initialize() -> void:
	# Find or create the combat state machine
	_combat_state_machine = _npc.parent_entity.get_node_or_null("CombatStateMachine") as CombatStateMachine
	if not _combat_state_machine:
		_combat_state_machine = CombatStateMachine.new()
		_npc.parent_entity.add_child(_combat_state_machine)
		_combat_state_machine.initialize(_npc.parent_entity)

	# Wire death
	var vitals:VitalsComponent = _npc.parent_entity.get_component("VitalsComponent") as VitalsComponent
	if vitals:
		vitals.dies.connect(_on_entity_died)

	# Wire poise break
	var combatant:CombatantComponent = _npc.parent_entity.get_component("CombatantComponent") as CombatantComponent
	if combatant:
		combatant.poise_broken.connect(_on_poise_broken)


func _process(delta:float) -> void:
	if not _npc:
		return
	if not _npc.in_combat:
		return
	if not _npc.parent_entity or not _npc.parent_entity.in_scene:
		return
	if not _combat_state_machine:
		return

	_decision_timer += delta
	if _decision_timer < decision_interval:
		return
	_decision_timer = 0.0

	_select_and_execute_action()


func _select_and_execute_action() -> void:
	if not _combat_state_machine.can_act():
		return

	var vitals:VitalsComponent = _npc.parent_entity.get_component("VitalsComponent") as VitalsComponent
	if not vitals:
		return

	# Determine distance to combat target
	var target_distance := _get_distance_to_target()

	# Filter affordable actions
	var candidates:Array[CombatAction] = []
	for action in available_actions:
		if action.can_afford(vitals):
			candidates.append(action)

	if candidates.is_empty():
		return

	# Score each candidate
	var best_action:CombatAction = null
	var best_score:float = -1.0

	for action in candidates:
		var score := _score_action(action, target_distance)
		if score > best_score:
			best_score = score
			best_action = action

	if best_action:
		_combat_state_machine.execute_action(best_action)


## Score an action based on context. Higher is better.
func _score_action(action:CombatAction, target_distance:float) -> float:
	var score:float = 1.0

	match action.action_type:
		CombatAction.ActionType.MELEE:
			if target_distance <= melee_range:
				score += 2.0
			else:
				score -= 2.0
		CombatAction.ActionType.RANGED:
			if target_distance > melee_range:
				score += 2.0
			if target_distance <= action.hitscan_range:
				score += 1.0
			else:
				score -= 5.0
		CombatAction.ActionType.SPELL:
			# Spells are generally good at any range
			score += 1.0

	# Prefer actions that cost less when low on resources
	var vitals:VitalsComponent = _npc.parent_entity.get_component("VitalsComponent") as VitalsComponent
	if vitals:
		var moxie_ratio:float = vitals.vitals.get("moxie", 0.0) / maxf(vitals.vitals.get("max_moxie", 1.0), 1.0)
		if moxie_ratio < 0.3 and action.stamina_cost > 0:
			score -= 1.0

	# Add some randomness to prevent predictability
	score += randf() * 0.5

	return score


func _get_distance_to_target() -> float:
	if _npc._combat_target.is_empty():
		return INF
	var target_entity := SKEntityManager.instance.get_entity(StringName(_npc._combat_target))
	if not target_entity:
		return INF
	return _npc.parent_entity.position.distance_to(target_entity.position)


func _on_entity_died() -> void:
	if _combat_state_machine:
		_combat_state_machine.die()


func _on_poise_broken() -> void:
	if _combat_state_machine:
		_combat_state_machine.apply_stagger()


func get_type() -> String:
	return "DefaultCombatActionModule"
