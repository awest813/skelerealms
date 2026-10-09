extends Node
## Autoload singleton: the companion roster, follow orders, and affinity.
##
## Companion state itself lives on [CompanionComponent] (saved with its
## entity), so this system keeps no save data — the roster is always derived
## live from the entity manager, which also means it can never drift.
## NOTE: intentionally no class_name — like GameInfo and SaveSystem, the
## autoload instance is referenced dynamically by name.


## Emitted when an NPC joins the party.
signal companion_recruited(ref_id: StringName)
## Emitted on dismissal. sent_home is false when no home was set.
signal companion_dismissed(ref_id: StringName, sent_home: bool)
## Emitted when follow/wait orders change.
signal follow_state_changed(ref_id: StringName, following: bool)
## Emitted on every affinity change: companion, old, new, reason.
signal affinity_changed(ref_id: StringName, old_value: int, new_value: int, reason: String)
## Emitted when affinity crosses a band boundary (see LEVELS).
signal affinity_milestone(ref_id: StringName, level: String)
## Emitted when affinity bottoms out and the companion walks away.
signal companion_left(ref_id: StringName)


## Affinity bands, lowest first: [ceiling_exclusive_upper... ] — see level_for().
## FRACTURED: -100..-50 (walks away), WARY: -49..-1, NEUTRAL: 0..24,
## TRUSTED: 25..59 (perk hook), SWORN: 60..100 (companion-quest hook).
const LEVELS := ["FRACTURED", "WARY", "NEUTRAL", "TRUSTED", "SWORN"]

## Max simultaneously recruited companions. Games override per party design.
var max_party_size: int = 2


## Band name for an affinity value.
static func level_for(affinity: int) -> String:
	if affinity <= -50:
		return "FRACTURED"
	if affinity < 0:
		return "WARY"
	if affinity < 25:
		return "NEUTRAL"
	if affinity < 60:
		return "TRUSTED"
	return "SWORN"


## CompanionComponent for a ref, or null (unknown ref, no component).
## Uses entities.has() first so misses stay silent (no warning spam).
func get_companion(ref_id: StringName) -> CompanionComponent:
	var manager := SKEntityManager.instance
	if manager == null or not manager.entities.has(ref_id):
		return null
	var entity: SKEntity = manager.entities[ref_id]
	if entity == null or not is_instance_valid(entity):
		return null
	if not entity.has_component("CompanionComponent"):
		return null
	return entity.get_component("CompanionComponent") as CompanionComponent


## Currently recruited companion refs, in registry order.
func get_party() -> Array:
	var party := []
	var manager := SKEntityManager.instance
	if manager == null:
		return party
	for ref in manager.entities:
		var comp := get_companion(ref)
		if comp and comp.recruited:
			party.append(ref)
	return party


## Recruit an NPC. Captures home (world + position) when unset.
## Returns false for unknown/non-companion refs and full parties.
func recruit(ref_id: StringName) -> bool:
	var comp := get_companion(ref_id)
	if comp == null:
		push_warning("CompanionSystem: cannot recruit unknown '%s'." % ref_id)
		return false
	if comp.recruited:
		return true
	if get_party().size() >= max_party_size:
		return false
	var entity: SKEntity = comp.parent_entity
	if comp.home_world.is_empty() and entity:
		comp.home_world = entity.world
		comp.home_position = entity.position
	comp.recruited = true
	comp.following = true
	companion_recruited.emit(ref_id)
	return true


## Dismiss back home when a home is set. Returns false when not recruited.
func dismiss(ref_id: StringName, send_home: bool = true) -> bool:
	var comp := get_companion(ref_id)
	if comp == null or not comp.recruited:
		return false
	comp.recruited = false
	comp.following = false
	var went_home := false
	if send_home and not comp.home_world.is_empty():
		var entity: SKEntity = comp.parent_entity
		if entity:
			if entity.has_component("TeleportComponent"):
				(entity.get_component("TeleportComponent") as TeleportComponent).teleport(comp.home_world, comp.home_position)
			else:
				entity.world = comp.home_world
				entity.position = comp.home_position
			went_home = true
	companion_dismissed.emit(ref_id, went_home)
	return true


## Order a recruited companion to follow (true) or wait (false).
func set_following(ref_id: StringName, following: bool) -> bool:
	var comp := get_companion(ref_id)
	if comp == null or not comp.recruited:
		return false
	if comp.following == following:
		return true
	comp.following = following
	follow_state_changed.emit(ref_id, following)
	return true


## Current affinity (0 for unknown refs).
func get_affinity(ref_id: StringName) -> int:
	var comp := get_companion(ref_id)
	return comp.affinity if comp else 0


## Affinity band name ("NEUTRAL" for unknown refs).
func get_affinity_level(ref_id: StringName) -> String:
	return level_for(get_affinity(ref_id))


## Adjust affinity, clamped to -100..100. Entering FRACTURED dismisses
## the companion home and emits companion_left. Milestone crossings emit
## affinity_milestone — the game applies perk/quest hooks there.
func adjust_affinity(ref_id: StringName, delta: int, reason: String = "") -> bool:
	var comp := get_companion(ref_id)
	if comp == null:
		return false
	var old := comp.affinity
	var new_value := clampi(old + delta, -100, 100)
	if new_value == old:
		return true
	comp.affinity = new_value
	affinity_changed.emit(ref_id, old, new_value, reason)
	if level_for(old) != level_for(new_value):
		affinity_milestone.emit(ref_id, level_for(new_value))
	if level_for(new_value) == "FRACTURED" and level_for(old) != "FRACTURED":
		dismiss(ref_id, true)
		companion_left.emit(ref_id)
	return true
