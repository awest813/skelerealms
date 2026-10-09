class_name BarkEngine
extends RefCounted
## Picks one-liner barks for game events. Pure logic, no scene-tree access.
##
## Query with a trigger channel and a speaker; the winner is the eligible
## bark with the highest priority (registration order breaks ties, so picks
## are deterministic). Eligibility is trigger match, speaker match (generic
## barks match anyone), passing conditions, an expired cooldown, and the
## chance roll. Cooldowns are real seconds and intentionally not saved —
## barks are flavor, not quest state.


## Seconds source, for deterministic tests. When invalid, wall clock is used.
var clock: Callable
## Roll source for chance. Override with a seeded instance in tests.
var rng := RandomNumberGenerator.new()

var _barks: Dictionary = {}
var _last_said: Dictionary = {}


## Register a bark. Re-registering replaces it.
func register_bark(bark: DialogueBark) -> void:
	_barks[bark.id] = bark


## Remove a bark.
func unregister_bark(bark_id: StringName) -> void:
	_barks.erase(bark_id)
	_last_said.erase(bark_id)


## Returns true if a bark is registered.
func has_bark(bark_id: StringName) -> bool:
	return _barks.has(bark_id)


## Current time in seconds (injected clock or wall clock).
func _now() -> float:
	if clock.is_valid():
		return float(clock.call())
	return Time.get_ticks_msec() / 1000.0


## Pick the winning bark for a trigger/speaker, or null. Records cooldowns
## for winners only — queries with no eligible bark change nothing.
func query(trigger: StringName, speaker: StringName, context: DialogueContext) -> DialogueBark:
	var winner: DialogueBark = null
	for bark_id in _barks:
		var bark: DialogueBark = _barks[bark_id]
		if bark.trigger != trigger:
			continue
		if not bark.speaker.is_empty() and bark.speaker != speaker:
			continue
		if not DialogueConditions.passes_all(bark.conditions, context):
			continue
		var last := float(_last_said.get(bark_id, -999999999.0))
		if _now() - last < bark.cooldown_seconds:
			continue
		if rng.randf() >= clampf(bark.chance, 0.0, 1.0):
			continue
		if winner == null or bark.priority > winner.priority:
			winner = bark
	if winner:
		_last_said[winner.id] = _now()
	return winner


## Validate a bark without registering it. Returns issue dicts with keys
## "type" and "detail". Empty means sound.
func validate_bark(bark: DialogueBark) -> Array:
	var issues: Array = []
	if bark.trigger.is_empty():
		issues.append({"type": "empty_trigger", "detail": "Bark '%s' names no trigger." % bark.id})
	if bark.text.is_empty():
		issues.append({"type": "empty_text", "detail": "Bark '%s' has no text." % bark.id})
	if bark.chance < 0.0 or bark.chance > 1.0:
		issues.append({"type": "bad_chance", "detail": "Bark '%s' chance must be 0..1." % bark.id})
	if bark.cooldown_seconds < 0.0:
		issues.append({"type": "bad_cooldown", "detail": "Bark '%s' cooldown must not be negative." % bark.id})
	return issues


## Clear barks and cooldowns (keeps nothing, unlike definition registries —
## barks are content, re-registered at startup like dialogue trees).
func reset() -> void:
	_barks.clear()
	_last_said.clear()
