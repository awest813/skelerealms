extends Node
## Autoload singleton: the Radiant Story Manager.
## NOTE: intentionally no class_name — like GameInfo and SaveSystem, the
## autoload instance is referenced dynamically by name. A class_name would
## shadow the singleton and break instance member access.
##
## Listens to every quest event (forwarded by [QuestSystem.apply_event]),
## issues instanced radiant quests from registered templates, and keeps
## their cooldowns across saves. Template quest instances persist through
## this system's own snapshot, independent of [QuestSystem] save ordering.


## Emitted for every issued radiant instance.
signal radiant_quest_issued(quest_id: StringName, template_id: StringName)


## Set false to stop auto-forwarding (manual notify_event only).
var auto_forward := true
## Game minutes elapsed (ticks on GameInfo.minute_incremented).
var ticks: int = 0

## The underlying radiant engine.
var engine := RadiantEngine.new()


func _ready() -> void:
	add_to_group("savegame_gameinfo")
	engine.quest_engine = QuestSystem.engine
	GameInfo.minute_incremented.connect(_on_minute)


func _on_minute() -> void:
	ticks += 1


## Register a [RadiantTemplate]. Templates persist across resets.
func register_template(t: RadiantTemplate) -> void:
	engine.register_template(t)


## Evaluate one game event for radiant issuance. Returns issued quest ids.
## Called automatically by QuestSystem; call directly for custom triggers.
## Suspended while the game is loading.
func notify_event(event: QuestEvent) -> Array:
	if GameInfo.is_loading:
		return []
	var issued: Array = []
	for plan in engine.plan_issuance(event, ticks):
		var t: RadiantTemplate = plan["template"]
		var inst: QuestDefinition = (t.quest_template as QuestDefinition).duplicate(true)
		inst.id = plan["instance_id"]
		QuestSystem.register_quest(inst)
		if QuestSystem.activate_quest_with_params(inst.id, plan["params"]):
			engine.record_issuance(t.id, inst.id, ticks)
			issued.append(inst.id)
			radiant_quest_issued.emit(inst.id, t.id)
		else:
			QuestSystem.unregister_quest(inst.id)
	return issued


# ── Save integration ────────────────────────────────────────────────────────


## Save instance map, instance quest states, radiant state, and clock.
## Instance states are stored here (not relied on from QuestSystem) so
## restores work regardless of save-group ordering.
func save() -> Dictionary:
	var full: Dictionary = QuestSystem.engine.get_snapshot()
	var inst_states := {}
	for iid in engine.get_instances():
		var key := str(iid)
		if (full.get("quests", {}) as Dictionary).has(key):
			inst_states[key] = (full["quests"] as Dictionary)[key]
	return {
		"templates": engine.get_instances(),
		"states": {"quests": inst_states},
		"radiant": engine.get_snapshot(),
		"ticks": ticks,
	}


## Re-register instance skeletons from templates, then restore states.
## Unknown templates (removed mods) are skipped with a warning.
func load_data(data: Dictionary) -> void:
	engine.restore_snapshot(data.get("radiant", {}))
	for iid_str in (data.get("templates", {}) as Dictionary):
		var tid := StringName(str((data["templates"] as Dictionary)[iid_str]))
		var t: RadiantTemplate = engine.templates.get(tid)
		if t == null or t.quest_template == null:
			push_warning("RadiantSystem: template '%s' for instance '%s' is gone; skipping." % [tid, iid_str])
			continue
		if _is_registered(StringName(iid_str)):
			continue
		var inst: QuestDefinition = (t.quest_template as QuestDefinition).duplicate(true)
		inst.id = StringName(iid_str)
		QuestSystem.register_quest(inst)
	# Restore only re-registered instances: orphaned states (removed mods)
	# must stay down instead of reviving unregistered quests.
	var quest_states := {}
	for iid_str in (data.get("states", {}) as Dictionary).get("quests", {}):
		if _is_registered(StringName(iid_str)):
			quest_states[iid_str] = ((data["states"] as Dictionary)["quests"] as Dictionary)[iid_str]
	QuestSystem.engine.restore_snapshot({"quests": quest_states})
	ticks = int(data.get("ticks", 0))


## True when the quest id is already registered (avoids double registration
## when both save systems restore the same snapshot).
func _is_registered(quest_id: StringName) -> bool:
	return QuestSystem.engine.get_registered_quest_ids().has(quest_id)


func reset_data() -> void:
	ticks = 0
	engine.reset_runtime()
