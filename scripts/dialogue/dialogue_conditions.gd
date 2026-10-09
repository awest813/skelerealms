class_name DialogueConditions
extends RefCounted
## Shared evaluation for [DialogueChoiceCondition] lists.
##
## Extracted from DialogueSession so one-liner bark queries use the exact
## same semantics as tree choices. Pure static functions over an explicit
## [DialogueContext] — no session or tree state involved.


## True when every condition in the list passes (vacuously true when empty).
static func passes_all(conditions: Array[DialogueChoiceCondition], context: DialogueContext) -> bool:
	return first_failure(conditions, context) == null


## First failing condition, or null when all pass.
static func first_failure(conditions: Array[DialogueChoiceCondition], context: DialogueContext) -> DialogueChoiceCondition:
	for condition: DialogueChoiceCondition in conditions:
		if not passes(condition, context):
			return condition
	return null


## Evaluate one condition against game state.
static func passes(condition: DialogueChoiceCondition, context: DialogueContext) -> bool:
	match condition.type:
		"flag":
			return context.get_flag(condition.flag) == condition.flag_equals
		"faction_min":
			return context.get_faction_reputation(condition.faction_id) >= condition.min_value
		"quest_status":
			return context.get_quest_status(condition.quest_id) == condition.quest_status
		"has_item":
			return context.get_inventory_count(condition.item_id) >= condition.min_quantity
		"skill_min":
			return context.get_skill_level(condition.skill_id) >= condition.min_value
		"companion_recruited":
			return CompanionSystem.get_party().has(condition.companion_id)
		"companion_affinity_min":
			return CompanionSystem.get_affinity(condition.companion_id) >= condition.min_value
		_:
			push_warning("DialogueConditions: Unknown condition type '%s'." % condition.type)
			return false
