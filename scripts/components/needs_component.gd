class_name NeedsComponent
extends SKEntityComponent
## Tracks NPC needs (hunger, fatigue, social, etc.) and emits signals when
## thresholds are crossed so that GOAP objectives can be generated dynamically.
##
## Each need is a named float in [0.0, 1.0] (1.0 = fully satisfied).
## Needs decay over time at a per-need rate. When a need drops below its
## threshold, [signal need_critical] fires so an [AIModule] or GOAP action can
## add a goal to satisfy it. When the need rises above its threshold again,
## [signal need_satisfied] fires.
##
## ## Quick-start
## Add a [NeedsComponent] to an NPC entity. In the Inspector, configure
## [member needs], [member decay_rates], and [member thresholds].
##
## In an [AIModule]:
## ```gdscript
## func initialize() -> void:
##     var nc := _npc.parent_entity.get_component("NeedsComponent") as NeedsComponent
##     if nc:
##         nc.need_critical.connect(_on_need_critical)
##
## func _on_need_critical(need_name: StringName, value: float) -> void:
##     _npc.add_objective({"need_%s_satisfied" % need_name: true}, true, 3)
## ```


## Initial values for each named need (StringName → float, 0.0–1.0).
## Example: { &"hunger": 1.0, &"fatigue": 1.0, &"social": 0.8 }
@export var needs: Dictionary[StringName, float] = {
	&"hunger": 1.0,
	&"fatigue": 1.0,
	&"social": 1.0,
}

## Per-need decay rate in units per in-game minute (StringName → float).
## Defaults to 0.01 (1 % per minute) for unlisted needs.
@export var decay_rates: Dictionary[StringName, float] = {}

## Threshold below which a need is considered critical (StringName → float).
## Defaults to 0.2 for unlisted needs.
@export var thresholds: Dictionary[StringName, float] = {}

## Whether to decay needs even when the NPC is off-screen.
@export var decay_off_screen: bool = true

## Tracks which needs are currently below threshold to avoid re-firing.
var _critical_set: Dictionary[StringName, bool] = {}


## Emitted when a need drops below its threshold for the first time.
signal need_critical(need_name: StringName, value: float)
## Emitted when a need rises back above its threshold.
signal need_satisfied(need_name: StringName, value: float)
## Emitted every in-game minute after all needs have been updated.
signal needs_updated


func _init() -> void:
	name = "NeedsComponent"


func _entity_ready() -> void:
	# Decay once per in-game minute.
	GameInfo.minute_incremented.connect(_on_minute)


## Set a need to a new value and check thresholds.
func set_need(need_name: StringName, value: float) -> void:
	needs[need_name] = clampf(value, 0.0, 1.0)
	_check_threshold(need_name)


## Increase a need by [param amount].
func satisfy_need(need_name: StringName, amount: float) -> void:
	set_need(need_name, needs.get(need_name, 0.0) + amount)


## Return the current value of a need (0.0–1.0). Returns 1.0 if not found.
func get_need(need_name: StringName) -> float:
	return needs.get(need_name, 1.0)


func _on_minute() -> void:
	if not decay_off_screen and not parent_entity.in_scene:
		return
	for need_name: StringName in needs:
		var rate: float = decay_rates.get(need_name, 0.01)
		needs[need_name] = clampf(needs[need_name] - rate, 0.0, 1.0)
		_check_threshold(need_name)
	needs_updated.emit()


func _check_threshold(need_name: StringName) -> void:
	var value: float = needs.get(need_name, 1.0)
	var threshold: float = thresholds.get(need_name, 0.2)
	var was_critical: bool = _critical_set.get(need_name, false)
	if value < threshold and not was_critical:
		_critical_set[need_name] = true
		need_critical.emit(need_name, value)
	elif value >= threshold and was_critical:
		_critical_set[need_name] = false
		need_satisfied.emit(need_name, value)


func save() -> Dictionary:
	dirty = false
	return {"needs": needs}


func load_data(data: Dictionary) -> void:
	var saved: Variant = data.get("needs", null)
	if saved is Dictionary:
		for k: StringName in saved:
			needs[k] = clampf(float(saved[k]), 0.0, 1.0)
	dirty = false


func reset_data() -> void:
	for k in needs:
		needs[k] = 1.0
	_critical_set.clear()
	dirty = false
