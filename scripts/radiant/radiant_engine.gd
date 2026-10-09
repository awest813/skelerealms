class_name RadiantEngine
extends RefCounted
## Pure-logic dispenser of instanced radiant quests. No scene-tree access.
##
## The engine matches game events against registered templates, plans
## issuances (cooldown + active-cap gates), and tracks instances. The
## [RadiantSystem] autoload owns execution (instancing, activation,
## signals) and the game clock. Inject a stub quest engine and manual
## clock in tests.


## template_id -> RadiantTemplate. Templates persist across resets.
var templates: Dictionary = {}
## Quest engine used for active-status reads. Set by the owner.
var quest_engine: QuestGraphEngine
## template_id -> issued count (drives instance numbering, never reused).
var _counters: Dictionary = {}
## template_id -> game minutes of last issuance.
var _last_issued: Dictionary = {}
## instance_id (StringName) -> template_id (StringName).
var _instances: Dictionary = {}


## Register a radiant template. Re-registering replaces it.
func register_template(t: RadiantTemplate) -> void:
	templates[t.id] = t


## Remove a template (mod unloading, test isolation). Issued instances and
## their quest definitions are left alone; only future issuance stops.
func unregister_template(template_id: StringName) -> void:
	templates.erase(template_id)


## Evaluate one game event. Returns an Array of issuance plans —
## {template: RadiantTemplate, instance_id: StringName, params: Dictionary} —
## for templates whose trigger matches and whose gates pass. Planning is
## side-effect free; the owner executes plans and calls record_issuance.
func plan_issuance(event: QuestEvent, now_minutes: int) -> Array:
	var plans: Array = []
	var previewed := {}
	for tid in templates:
		var t: RadiantTemplate = templates[tid]
		if t.quest_template == null or t.trigger_type.is_empty():
			continue
		if t.trigger_type != event.type:
			continue
		if t.trigger_target != &"" and t.trigger_target != event.target_id:
			continue
		var last := int(_last_issued.get(tid, -999999999))
		if now_minutes - last < t.cooldown_minutes:
			continue
		if active_count(tid) >= maxi(1, t.max_active):
			continue
		var n := int(_counters.get(tid, 0)) + int(previewed.get(tid, 0)) + 1
		previewed[tid] = int(previewed.get(tid, 0)) + 1
		plans.append({
			"template": t,
			"instance_id": StringName("%s_%03d" % [tid, n]),
			"params": (t.extra_params as Dictionary).duplicate(),
		})
	return plans


## Commit a successfully executed plan: bump numbering, stamp cooldown,
## and track the instance. Call only after the instance quest activated.
func record_issuance(template_id: StringName, instance_id: StringName, now_minutes: int) -> void:
	_counters[template_id] = int(_counters.get(template_id, 0)) + 1
	_last_issued[template_id] = now_minutes
	_instances[instance_id] = template_id


## Active (non-completed, non-failed) instances of one template.
## Without a quest engine the cap cannot be enforced, so all count as closed.
func active_count(template_id: StringName) -> int:
	if quest_engine == null:
		return 0
	var count := 0
	for iid in _instances:
		if _instances[iid] == template_id and quest_engine.get_quest_status(StringName(iid)) == "active":
			count += 1
	return count


## Copy of the instance map (instance_id -> template_id).
func get_instances() -> Dictionary:
	return _instances.duplicate()


## Validate a template without registering it. Combines alias/stage checks
## with trigger sanity. Returns issue dicts with a "source" key
## ("trigger", "aliases", or "stages").
func validate_template(t: RadiantTemplate) -> Array:
	var issues: Array = []
	if t.quest_template == null:
		issues.append({"source": "template", "type": "missing_quest", "detail": "Template '%s' has no quest." % t.id})
		return issues
	if t.trigger_type.is_empty():
		issues.append({"source": "trigger", "type": "empty_trigger", "detail": "Template '%s' names no event type." % t.id})
	var qe := quest_engine if quest_engine else QuestGraphEngine.new()
	for issue in qe.validate_aliases(t.quest_template):
		var tagged := (issue as Dictionary).duplicate()
		tagged["source"] = "aliases"
		issues.append(tagged)
	for issue in qe.validate_stages(t.quest_template):
		var tagged := (issue as Dictionary).duplicate()
		tagged["source"] = "stages"
		issues.append(tagged)
	return issues


## Serialize cooldowns, counters, and the instance map for saving.
## Instance quest states travel in the radiant system's own snapshot.
func get_snapshot() -> Dictionary:
	var counters := {}
	for k in _counters:
		counters[str(k)] = int(_counters[k])
	var issued := {}
	for k in _last_issued:
		issued[str(k)] = int(_last_issued[k])
	var inst := {}
	for k in _instances:
		inst[str(k)] = str(_instances[k])
	return {"counters": counters, "last_issued": issued, "instances": inst}


## Restore cooldowns, counters, and the instance map.
func restore_snapshot(snapshot: Dictionary) -> void:
	_counters.clear()
	_last_issued.clear()
	_instances.clear()
	for k in (snapshot.get("counters", {}) as Dictionary):
		_counters[StringName(str(k))] = int((snapshot["counters"] as Dictionary)[k])
	for k in (snapshot.get("last_issued", {}) as Dictionary):
		_last_issued[StringName(str(k))] = int((snapshot["last_issued"] as Dictionary)[k])
	for k in (snapshot.get("instances", {}) as Dictionary):
		_instances[StringName(str(k))] = StringName(str((snapshot["instances"] as Dictionary)[k]))


## Clear runtime (cooldowns, counters, instances). Templates survive,
## mirroring QuestGraphEngine.reset_all_state keeping definitions.
func reset_runtime() -> void:
	_counters.clear()
	_last_issued.clear()
	_instances.clear()
