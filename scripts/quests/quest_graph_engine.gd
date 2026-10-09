class_name QuestGraphEngine
extends RefCounted
## Manages quest definitions and runtime state. Ported from Camelot's QuestGraphEngine.
## This is a pure-logic class with no Godot scene-tree dependencies.
## Use [QuestSystem] (the autoload) for game integration.


## Runtime state for a single quest node.
class QuestNodeState extends RefCounted:
	var active: bool = false
	var completed: bool = false
	var progress: int = 0

	func duplicate_state() -> QuestNodeState:
		var s := QuestNodeState.new()
		s.active = active
		s.completed = completed
		s.progress = progress
		return s

	func serialize() -> Dictionary:
		return {
			"active": active,
			"completed": completed,
			"progress": progress,
		}

	static func deserialize(data: Dictionary) -> QuestNodeState:
		var s := QuestNodeState.new()
		s.active = data.get("active", false)
		s.completed = data.get("completed", false)
		s.progress = data.get("progress", 0)
		return s


## Runtime state for a whole quest.
class QuestRuntimeState extends RefCounted:
	## "inactive", "active", or "completed"
	var status: String = "inactive"
	## node_id -> QuestNodeState
	var nodes: Dictionary = {}
	## alias_id (StringName) -> filled entity ref-ID (StringName).
	var alias_refs: Dictionary = {}
	## Current journal stage index, or -1 when stageless / not yet staged.
	var current_stage: int = -1
	## Journal entries in log order: [{stage: int, text: String}].
	var journal: Array = []

	func serialize() -> Dictionary:
		var node_data := {}
		for node_id: StringName in nodes:
			node_data[str(node_id)] = (nodes[node_id] as QuestNodeState).serialize()
		var alias_data := {}
		for alias_id: StringName in alias_refs:
			alias_data[str(alias_id)] = str(alias_refs[alias_id])
		return {
			"status": status,
			"nodes": node_data,
			"aliases": alias_data,
			"current_stage": current_stage,
			"journal": journal.duplicate(true),
		}

	static func deserialize(data: Dictionary) -> QuestRuntimeState:
		var s := QuestRuntimeState.new()
		s.status = data.get("status", "inactive")
		for node_id: String in data.get("nodes", {}):
			s.nodes[StringName(node_id)] = QuestNodeState.deserialize(data["nodes"][node_id])
		for alias_id: String in data.get("aliases", {}):
			s.alias_refs[StringName(alias_id)] = StringName(str(data["aliases"][alias_id]))
		s.current_stage = int(data.get("current_stage", -1))
		s.journal = (data.get("journal", []) as Array).duplicate(true)
		return s


## Result returned by [method apply_event] for each affected quest.
class QuestEventResult extends RefCounted:
	var quest_id: StringName
	var activated_node_ids: Array[StringName] = []
	var completed_node_ids: Array[StringName] = []
	var quest_completed: bool = false
	var quest_failed: bool = false
	var stages_advanced: Array[int] = []
	var xp_reward: int = 0


## Explicitly move a quest to a journal stage. The quest must be active and
## the stage must exist, otherwise returns "" (unknown stages push_error).
## Returns "advanced", "completed", or "failed". Stages with no flags still
## log and become current. Re-setting the current stage is a silent no-op.
func set_stage(quest_id: StringName, index: int) -> String:
	var definition: QuestDefinition = _definitions.get(quest_id)
	var state: QuestRuntimeState = _states.get(quest_id)
	if not definition or not state or state.status != "active":
		return ""
	if _stage_by_index(definition, index) == null:
		push_error("QuestGraphEngine: Quest '%s' has no stage %d." % [quest_id, index])
		return ""
	if state.current_stage == index:
		return ""
	return _apply_stage(definition, state, index)


## Validation issue found by [method validate_graph].
class QuestValidationIssue extends RefCounted:
	## "dead_end", "unreachable", "cycle", or "not_found"
	var type: String
	var node_id: StringName
	var detail: String


## Validation report returned by [method validate_graph].
class QuestValidationReport extends RefCounted:
	var quest_id: StringName
	var valid: bool
	var issues: Array[QuestValidationIssue] = []


# ── Internal state ──────────────────────────────────────────────────────────

## quest_id -> QuestDefinition
var _definitions: Dictionary[StringName, QuestDefinition] = {}
## quest_id -> QuestRuntimeState
var _states: Dictionary[StringName, QuestRuntimeState] = {}
## quest_id -> { node_id -> QuestNodeDefinition } — O(1) node lookup per quest.
var _node_maps: Dictionary[StringName, Dictionary] = {}
## quest_id -> { node_id -> Array[StringName] } — precomputed forward edges (explicit + implicit).
var _successor_maps: Dictionary[StringName, Dictionary] = {}
## Entity lookup for alias filling. Called with a filter Dictionary
## ({must_be_npc: bool, required_coven: StringName, required_form: StringName,
## exclude_ids: Array, world: StringName}) and returns an Array of candidate
## Dictionaries ({ref: StringName, position: Vector3, world: StringName}).
## Unset means alias quests cannot activate; QuestSystem installs a default
## backed by SKEntityManager. Inject a stub in tests.
var entity_finder: Callable
## Human-readable reason the last [method fill_aliases] call failed.
var last_alias_error: String = ""


# ── Public API ──────────────────────────────────────────────────────────────


## Register a quest definition. Validates the definition and creates empty runtime state.
func register_quest(definition: QuestDefinition) -> void:
	_validate_definition(definition)
	_definitions[definition.id] = definition
	_states[definition.id] = _create_empty_runtime_state(definition)
	# Build O(1) lookup structures
	var node_map: Dictionary = {}
	for node: QuestNodeDefinition in definition.nodes:
		node_map[node.id] = node
	_node_maps[definition.id] = node_map
	_successor_maps[definition.id] = _build_successor_map(definition, node_map)


## Activate a quest. Returns true if the quest was activated.
func activate_quest(quest_id: StringName) -> bool:
	return activate_quest_with_params(quest_id, {})


## Activate a quest with template parameter overrides.
##
## [param params] is merged on top of the quest's [member QuestDefinition.parameters]
## defaults.  Every [code]{key}[/code] placeholder in [member QuestDefinition.quest_name],
## [member QuestDefinition.description], [member QuestNodeDefinition.description],
## and [member QuestNodeDefinition.target_id] is replaced with the matching value.
##
## [param context] carries fill-time data for quest aliases
## ([code]{"player_position": Vector3, "world": StringName}[/code]).
## Aliases fill before params apply, so explicit params take precedence over
## generated fills. Returns [code]true[/code] if the quest was activated.
func activate_quest_with_params(quest_id: StringName, params: Dictionary = {}, context: Dictionary = {}) -> bool:
	var definition: QuestDefinition = _definitions.get(quest_id)
	var state: QuestRuntimeState = _states.get(quest_id)
	if not definition or not state or state.status == "completed" or state.status == "failed":
		return false

	# Fill alias slots first; a failed required alias blocks activation.
	if not fill_aliases(quest_id, context):
		return false

	# Merge defaults with caller overrides and apply to the definition
	if not definition.parameters.is_empty() or not params.is_empty():
		var merged := definition.parameters.duplicate()
		merged.merge(params, true)
		_apply_template_params(definition, merged)

	state.status = "active"
	# Staged quests open their journal on the lowest stage.
	if not definition.stages.is_empty():
		_apply_stage(definition, state, _lowest_stage_index(definition))
	var start_ids := _get_start_node_ids(definition)
	for node_id: StringName in start_ids:
		var node_state: QuestNodeState = state.nodes.get(node_id)
		if node_state and not node_state.completed:
			node_state.active = true
	return true


## Get the status of a quest ("inactive", "active", "completed").
func get_quest_status(quest_id: StringName) -> String:
	var state: QuestRuntimeState = _states.get(quest_id)
	return state.status if state else "inactive"


## Find a stage by index, or null.
func _stage_by_index(definition: QuestDefinition, index: int) -> QuestStage:
	for stage: QuestStage in definition.stages:
		if stage.index == index:
			return stage
	return null


## Lowest stage index, or -1 for stageless quests.
func _lowest_stage_index(definition: QuestDefinition) -> int:
	var best := -1
	for stage: QuestStage in definition.stages:
		if best < 0 or stage.index < best:
			best = stage.index
	return best


## Alias fills as a plain String->String template table.
func _alias_params(state: QuestRuntimeState) -> Dictionary:
	var out := {}
	for k in state.alias_refs:
		out[str(k)] = str(state.alias_refs[k])
	return out


## Move to a stage, log its (alias-resolved) entry, and apply completion
## or failure flags. Returns "advanced", "completed", or "failed".
## A consecutive duplicate log line is skipped, so repeats stay quiet.
func _apply_stage(definition: QuestDefinition, state: QuestRuntimeState, index: int) -> String:
	var stage := _stage_by_index(definition, index)
	if stage == null:
		return ""
	state.current_stage = index
	var text := _resolve_variables(stage.log_entry, _alias_params(state))
	if state.journal.is_empty() or (state.journal.back() as Dictionary).get("stage", -9999) != index or str((state.journal.back() as Dictionary).get("text", "")) != text:
		state.journal.append({"stage": index, "text": text})
	if stage.fails_quest:
		state.status = "failed"
		return "failed"
	if stage.completes_quest:
		state.status = "completed"
		return "completed"
	return "advanced"


## Evaluate stage auto-triggers after node progress. Stages with empty
## trigger lists never auto-fire (initial rule + explicit set_stage only).
## Returns {"stages": Array[int] fired this pass, "finished": ""/"completed"/"failed"}.
func _advance_stages(definition: QuestDefinition, state: QuestRuntimeState) -> Dictionary:
	var seen := {}
	for entry in state.journal:
		seen[int((entry as Dictionary).get("stage", -9999))] = true
	var advanced: Array[int] = []
	var finished := ""
	for stage: QuestStage in definition.stages:
		if stage.trigger_nodes.is_empty() or seen.has(stage.index):
			continue
		var all_done := true
		for nid: StringName in stage.trigger_nodes:
			var ns: QuestNodeState = state.nodes.get(nid)
			if ns == null or not ns.completed:
				all_done = false
				break
		if not all_done:
			continue
		var outcome := _apply_stage(definition, state, stage.index)
		advanced.append(stage.index)
		seen[stage.index] = true
		if outcome == "failed":
			finished = "failed"
		elif outcome != "" and finished == "":
			finished = outcome
	return {"stages": advanced, "finished": finished}


## Journal view for UI: name, status, current stage, objectives with
## done-flags, and the full log. Stageless quests fall back to node progress.
func get_journal(quest_id: StringName) -> Dictionary:
	var definition: QuestDefinition = _definitions.get(quest_id)
	var state: QuestRuntimeState = _states.get(quest_id)
	if not definition or not state:
		return {}
	var objectives: Array = []
	if definition.stages.is_empty():
		for node: QuestNodeDefinition in definition.nodes:
			var ns: QuestNodeState = state.nodes.get(node.id)
			if ns and (ns.active or ns.completed):
				objectives.append({"text": node.description, "done": ns.completed, "stage": -1})
	else:
		var ordered: Array = []
		for entry in state.journal:
			var s := int((entry as Dictionary).get("stage", -1))
			if not ordered.has(s):
				ordered.append(s)
		for s: int in ordered:
			var st := _stage_by_index(definition, s)
			if st == null:
				continue
			var done := state.status == "completed" or (state.status == "active" and s != state.current_stage)
			objectives.append({"text": st.objective, "done": done, "stage": s})
	return {
		"name": definition.quest_name,
		"status": state.status,
		"current_stage": state.current_stage,
		"objectives": objectives,
		"log": (state.journal as Array).duplicate(true),
	}


## One-line current objective for HUD use ("" when nothing is current).
func get_current_objective(quest_id: StringName) -> String:
	var definition: QuestDefinition = _definitions.get(quest_id)
	var state: QuestRuntimeState = _states.get(quest_id)
	if not definition or not state or state.status != "active":
		return ""
	if not definition.stages.is_empty():
		var st := _stage_by_index(definition, state.current_stage)
		return st.objective if st else ""
	for node: QuestNodeDefinition in definition.nodes:
		var ns: QuestNodeState = state.nodes.get(node.id)
		if ns and ns.active and not ns.completed:
			return node.description
	return ""


## Quest XP reward, or 0 for unknown quests.
func get_quest_xp(quest_id: StringName) -> int:
	var definition: QuestDefinition = _definitions.get(quest_id)
	return definition.xp_reward if definition else 0


## Validate stage declarations without registering anything.
## Returns an Array of Dictionaries with keys [code]type[/code],
## [code]stage[/code] (int) and [code]detail[/code] (String).
func validate_stages(definition: QuestDefinition) -> Array:
	var issues: Array = []
	var seen := {}
	for stage: QuestStage in definition.stages:
		if seen.has(stage.index):
			issues.append({
				"type": "duplicate_stage",
				"stage": stage.index,
				"detail": "Duplicate stage index %d." % stage.index,
			})
		seen[stage.index] = true
	var node_ids := {}
	for node: QuestNodeDefinition in definition.nodes:
		node_ids[node.id] = true
	for stage: QuestStage in definition.stages:
		for nid: StringName in stage.trigger_nodes:
			if not node_ids.has(nid):
				issues.append({
					"type": "bad_stage_trigger",
					"stage": stage.index,
					"detail": "Stage %d triggers on unknown node '%s'." % [stage.index, nid],
				})
	return issues


## Fill this quest's alias slots from live entities. Called automatically by
## [method activate_quest_with_params]; call directly to pre-check or refill.
## Returns false (with [member last_alias_error] set) when a required alias
## has no candidate, the anchor is unknown, or no finder is installed.
## Filled refs land in runtime state, so they survive save/load.
func fill_aliases(quest_id: StringName, context: Dictionary = {}) -> bool:
	last_alias_error = ""
	var definition: QuestDefinition = _definitions.get(quest_id)
	var state: QuestRuntimeState = _states.get(quest_id)
	if not definition or not state:
		last_alias_error = "Quest '%s' is not registered." % quest_id
		return false
	if definition.aliases.is_empty():
		return true
	if not entity_finder.is_valid():
		last_alias_error = "Quest '%s' needs aliases but no entity finder is set." % quest_id
		return false
	var filled_pos := {}
	var filled_refs := {}
	var player_pos: Vector3 = context.get("player_position", Vector3.ZERO)
	for alias: QuestAlias in definition.aliases:
		var candidates: Array = entity_finder.call({
			"must_be_npc": alias.must_be_npc,
			"required_coven": alias.required_coven,
			"required_form": alias.required_form,
			"exclude_ids": alias.exclude_ids.duplicate(),
		})
		if candidates.is_empty():
			if alias.optional:
				continue
			last_alias_error = "Quest '%s': no candidate for required alias '%s'." % [quest_id, alias.id]
			return false
		var pick: Dictionary = candidates[0]
		if not alias.nearest_to.is_empty():
			var anchor := Vector3.ZERO
			var anchor_world := StringName(context.get("world", ""))
			if alias.nearest_to == &"player":
				anchor = player_pos
			elif filled_pos.has(alias.nearest_to):
				anchor = filled_pos[alias.nearest_to]["position"]
				anchor_world = filled_pos[alias.nearest_to]["world"]
			else:
				last_alias_error = "Quest '%s': alias '%s' anchors to unknown '%s' (must be &\"player\" or an earlier alias)." % [quest_id, alias.id, alias.nearest_to]
				return false
			var best_i := -1
			var best_d := INF
			for i in candidates.size():
				var candidate: Dictionary = candidates[i]
				if anchor_world != &"" and StringName(candidate.get("world", "")) != anchor_world:
					continue
				var d := (candidate.get("position", Vector3.ZERO) as Vector3).distance_squared_to(anchor)
				if d < best_d:
					best_d = d
					best_i = i
			if best_i < 0:
				if alias.optional:
					continue
				last_alias_error = "Quest '%s': no candidate for required alias '%s' in the anchor's world." % [quest_id, alias.id]
				return false
			pick = candidates[best_i]
		var ref := StringName(pick.get("ref", ""))
		if ref == &"":
			if alias.optional:
				continue
			last_alias_error = "Quest '%s': alias '%s' resolved to an empty ref." % [quest_id, alias.id]
			return false
		filled_refs[alias.id] = ref
		filled_pos[alias.id] = {
			"position": pick.get("position", Vector3.ZERO),
			"world": StringName(pick.get("world", "")),
		}
	# Commit only after every required slot succeeds; replace optional misses.
	state.alias_refs = filled_refs
	return true


## Get one filled alias ref, or &"" when the quest/alias is unknown or unfilled.
func get_alias_ref(quest_id: StringName, alias_id: StringName) -> StringName:
	var state: QuestRuntimeState = _states.get(quest_id)
	if not state:
		return &""
	return StringName(state.alias_refs.get(alias_id, &""))


## Get a copy of all filled alias refs for a quest (alias_id -> entity ref).
func get_alias_refs(quest_id: StringName) -> Dictionary:
	var state: QuestRuntimeState = _states.get(quest_id)
	if not state:
		return {}
	return (state.alias_refs as Dictionary).duplicate()


## Resolve a node's target ref, substituting whole-field {AliasId}
## placeholders from this quest's fills. Anything else — literals and
## unfilled placeholders — passes through unchanged so plain matching and
## explicit template params keep working untouched.
func _resolve_target(quest_id: StringName, node: QuestNodeDefinition, state: QuestRuntimeState) -> StringName:
	var raw := str(node.target_id)
	if raw.length() > 2 and raw.begins_with("{") and raw.ends_with("}"):
		var key := StringName(raw.substr(1, raw.length() - 2))
		if state.alias_refs.has(key):
			return state.alias_refs[key]
	return node.target_id


## Validate alias declarations without registering or filling anything.
## Returns an Array of Dictionaries with keys [code]type[/code],
## [code]alias_id[/code] ([StringName]) and [code]detail[/code] (String).
## An empty Array means the aliases are sound.
func validate_aliases(definition: QuestDefinition) -> Array:
	var issues: Array = []
	var seen := {}
	for alias: QuestAlias in definition.aliases:
		if seen.has(alias.id):
			issues.append({
				"type": "duplicate_alias",
				"alias_id": alias.id,
				"detail": "Duplicate alias id '%s'." % alias.id,
			})
		seen[alias.id] = true
	for alias: QuestAlias in definition.aliases:
		var anchor := alias.nearest_to
		if anchor.is_empty() or anchor == &"player":
			continue
		if not seen.has(anchor):
			issues.append({
				"type": "bad_anchor",
				"alias_id": alias.id,
				"detail": "Alias '%s' anchors to unknown '%s' (must be &\"player\" or another alias)." % [alias.id, anchor],
			})
			continue
		var self_index := definition.aliases.find(alias)
		var anchor_index := -1
		for i in definition.aliases.size():
			if (definition.aliases[i] as QuestAlias).id == anchor:
				anchor_index = i
				break
		if anchor_index >= self_index:
			issues.append({
				"type": "forward_anchor",
				"alias_id": alias.id,
				"detail": "Alias '%s' anchors to '%s', which fills later. Anchors must target earlier aliases." % [alias.id, anchor],
			})
	return issues


## Get a deep copy of the runtime state for a quest (or null).
func get_quest_state(quest_id: StringName) -> QuestRuntimeState:
	var state: QuestRuntimeState = _states.get(quest_id)
	if not state:
		return null
	return QuestRuntimeState.deserialize(state.serialize())


## Apply a game event (kill, pickup, talk, custom) to all active quests.
## Returns an array of [QuestEventResult] for each quest that was affected.
func apply_event(event: QuestEvent) -> Array[QuestEventResult]:
	var results: Array[QuestEventResult] = []

	for quest_id: StringName in _definitions:
		var definition: QuestDefinition = _definitions[quest_id]
		var state: QuestRuntimeState = _states[quest_id]
		if state.status != "active":
			continue

		var activated_ids: Array[StringName] = []
		var completed_ids: Array[StringName] = []
		var progressed := false
		var delta := max(1, event.amount)

		for node: QuestNodeDefinition in definition.nodes:
			var node_state: QuestNodeState = state.nodes.get(node.id)
			if not node_state or not node_state.active or node_state.completed:
				continue
			if node.trigger_type != event.type:
				continue
			if _resolve_target(quest_id, node, state) != event.target_id:
				continue

			node_state.progress = min(node.required_count, node_state.progress + delta)
			progressed = true
			if node_state.progress >= node.required_count:
				node_state.completed = true
				node_state.active = false
				completed_ids.append(node.id)

				# Activate immediate successors whose prerequisites are now met
				var next_ids := _get_immediate_next_node_ids(node, definition)
				for next_id: StringName in next_ids:
					var next_state: QuestNodeState = state.nodes.get(next_id)
					if not next_state or next_state.completed or next_state.active:
						continue
					if not _are_prerequisites_completed(next_id, definition, state.nodes):
						continue
					next_state.active = true
					activated_ids.append(next_id)

		if not progressed:
			continue

		var stage_outcome := _advance_stages(definition, state)
		var quest_completed := false
		var quest_failed := false
		if stage_outcome["finished"] == "failed":
			state.status = "failed"
			quest_failed = true
		else:
			if stage_outcome["finished"] == "completed":
				state.status = "completed"
				quest_completed = true
			else:
				quest_completed = _is_quest_completed(definition, state.nodes)
				if quest_completed:
					state.status = "completed"

		# Also activate any implicit nodes whose prerequisites are now satisfied
		_activate_implicit_nodes(definition, state.nodes, activated_ids)

		var result := QuestEventResult.new()
		result.quest_id = quest_id
		result.stages_advanced = stage_outcome["stages"]
		# Deduplicate activated_ids
		var unique_activated: Array[StringName] = []
		var seen := {}
		for aid: StringName in activated_ids:
			if not seen.has(aid):
				seen[aid] = true
				unique_activated.append(aid)
		result.activated_node_ids = unique_activated
		result.completed_node_ids = completed_ids
		result.quest_completed = quest_completed
		result.quest_failed = quest_failed
		result.xp_reward = definition.xp_reward if quest_completed else 0
		results.append(result)

	return results


## Serialize all quest state for saving.
func get_snapshot() -> Dictionary:
	var quests := {}
	for quest_id: StringName in _states:
		quests[str(quest_id)] = (_states[quest_id] as QuestRuntimeState).serialize()
	return {"quests": quests}


## Restore quest state from a snapshot. Only restores quests that are registered.
func restore_snapshot(snapshot: Dictionary) -> void:
	var quests: Dictionary = snapshot.get("quests", {})
	for quest_id: String in quests:
		var sid := StringName(quest_id)
		if not _definitions.has(sid):
			continue
		_states[sid] = QuestRuntimeState.deserialize(quests[quest_id])


## Validate the graph structure of a registered quest.
## Checks for unreachable nodes, dead-end nodes, and dependency cycles.
func validate_graph(quest_id: StringName) -> QuestValidationReport:
	var report := QuestValidationReport.new()
	report.quest_id = quest_id

	var definition: QuestDefinition = _definitions.get(quest_id)
	if not definition:
		var issue := QuestValidationIssue.new()
		issue.type = "not_found"
		issue.node_id = &""
		issue.detail = "Quest '%s' is not registered." % quest_id
		report.valid = false
		report.issues.append(issue)
		return report

	var node_map := {}
	for node: QuestNodeDefinition in definition.nodes:
		node_map[node.id] = node

	var start_ids := _get_start_node_ids(definition)
	var start_set := {}
	for sid: StringName in start_ids:
		start_set[sid] = true

	var completion_ids: Array[StringName] = []
	if definition.completion_node_ids.size() > 0:
		completion_ids = definition.completion_node_ids
	else:
		for node: QuestNodeDefinition in definition.nodes:
			completion_ids.append(node.id)
	var completion_set := {}
	for cid: StringName in completion_ids:
		completion_set[cid] = true

	# ── Reachability (BFS from start nodes) ──
	var reachable := {}
	var queue: Array[StringName] = []
	queue.append_array(start_ids)
	while queue.size() > 0:
		var current: StringName = queue.pop_front()
		if reachable.has(current):
			continue
		reachable[current] = true
		for successor: StringName in _get_all_successors(current, definition):
			if not reachable.has(successor):
				queue.append(successor)

	for node: QuestNodeDefinition in definition.nodes:
		if not reachable.has(node.id):
			var issue := QuestValidationIssue.new()
			issue.type = "unreachable"
			issue.node_id = node.id
			issue.detail = "Node '%s' cannot be reached from the quest start nodes." % node.id
			report.issues.append(issue)

	# ── Dead-end check ──
	for node: QuestNodeDefinition in definition.nodes:
		if not reachable.has(node.id):
			continue
		if completion_set.has(node.id):
			continue
		if _get_all_successors(node.id, definition).size() == 0:
			var issue := QuestValidationIssue.new()
			issue.type = "dead_end"
			issue.node_id = node.id
			issue.detail = "Node '%s' has no successors and is not a completion node." % node.id
			report.issues.append(issue)

	# ── Cycle detection (DFS with color marking) ──
	const WHITE = 0
	const GRAY = 1
	const BLACK = 2
	var color := {}
	for node: QuestNodeDefinition in definition.nodes:
		color[node.id] = WHITE

	for node: QuestNodeDefinition in definition.nodes:
		if color[node.id] == WHITE:
			_dfs_cycle_check(node.id, definition, color, report.issues)

	report.valid = report.issues.is_empty()
	return report


## Get all registered quest IDs.
func get_registered_quest_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for k: StringName in _definitions:
		ids.append(k)
	return ids


## Remove a quest entirely: definition, runtime state, and lookup caches.
## Used for failed radiant rollbacks and mod content removal.
func unregister_quest(quest_id: StringName) -> void:
	_definitions.erase(quest_id)
	_states.erase(quest_id)
	_node_maps.erase(quest_id)
	_successor_maps.erase(quest_id)


## Reset all runtime state while keeping definitions. Re-creates empty state for each quest.
func reset_all_state() -> void:
	var defs := _definitions.duplicate()
	_definitions.clear()
	_states.clear()
	_node_maps.clear()
	_successor_maps.clear()
	for quest_id: StringName in defs:
		register_quest(defs[quest_id])


# ── Private helpers ─────────────────────────────────────────────────────────


func _create_empty_runtime_state(definition: QuestDefinition) -> QuestRuntimeState:
	var state := QuestRuntimeState.new()
	for node: QuestNodeDefinition in definition.nodes:
		state.nodes[node.id] = QuestNodeState.new()
	return state


func _validate_definition(definition: QuestDefinition) -> void:
	var node_ids := {}
	for node: QuestNodeDefinition in definition.nodes:
		if node_ids.has(node.id):
			push_error("QuestGraphEngine: Duplicate node id '%s' in quest '%s'." % [node.id, definition.id])
		node_ids[node.id] = true

	for node: QuestNodeDefinition in definition.nodes:
		for prereq: StringName in node.prerequisites:
			if not node_ids.has(prereq):
				push_error("QuestGraphEngine: Unknown prerequisite '%s' in node '%s' of quest '%s'." % [prereq, node.id, definition.id])
		for nid: StringName in node.next_node_ids:
			if not node_ids.has(nid):
				push_error("QuestGraphEngine: Unknown next_node_id '%s' in node '%s' of quest '%s'." % [nid, node.id, definition.id])

	for sid: StringName in definition.start_node_ids:
		if not node_ids.has(sid):
			push_error("QuestGraphEngine: Unknown start_node_id '%s' in quest '%s'." % [sid, definition.id])
	for cid: StringName in definition.completion_node_ids:
		if not node_ids.has(cid):
			push_error("QuestGraphEngine: Unknown completion_node_id '%s' in quest '%s'." % [cid, definition.id])


func _get_start_node_ids(definition: QuestDefinition) -> Array[StringName]:
	if definition.start_node_ids.size() > 0:
		return definition.start_node_ids
	var ids: Array[StringName] = []
	for node: QuestNodeDefinition in definition.nodes:
		if node.prerequisites.is_empty():
			ids.append(node.id)
	return ids


func _get_immediate_next_node_ids(node: QuestNodeDefinition, definition: QuestDefinition) -> Array[StringName]:
	if node.next_node_ids.size() > 0:
		return node.next_node_ids
	# Implicit: use precomputed successor map (O(1) lookup)
	var quest_successors: Dictionary = _successor_maps.get(definition.id, {})
	return quest_successors.get(node.id, [] as Array[StringName])


func _are_prerequisites_completed(node_id: StringName, definition: QuestDefinition, states: Dictionary) -> bool:
	# O(1) node lookup via cached node map
	var node_map: Dictionary = _node_maps.get(definition.id, {})
	var node: QuestNodeDefinition = node_map.get(node_id)
	if not node:
		return false
	if node.prerequisites.is_empty():
		return true

	if node.join_mode == QuestNodeDefinition.JoinMode.ANY:
		# OR-join: at least one prerequisite must be completed
		for prereq: StringName in node.prerequisites:
			var ps: QuestNodeState = states.get(prereq)
			if ps and ps.completed:
				return true
		return false

	# Default ALL (AND-join): every prerequisite must be completed
	for prereq: StringName in node.prerequisites:
		var ps: QuestNodeState = states.get(prereq)
		if not ps or not ps.completed:
			return false
	return true


func _activate_implicit_nodes(definition: QuestDefinition, states: Dictionary, activated_ids: Array[StringName]) -> void:
	for node: QuestNodeDefinition in definition.nodes:
		var node_state: QuestNodeState = states.get(node.id)
		if not node_state or node_state.completed or node_state.active:
			continue
		if not _are_prerequisites_completed(node.id, definition, states):
			continue
		node_state.active = true
		activated_ids.append(node.id)


func _is_quest_completed(definition: QuestDefinition, states: Dictionary) -> bool:
	var completion_ids: Array[StringName] = []
	if definition.completion_node_ids.size() > 0:
		completion_ids = definition.completion_node_ids
	else:
		for node: QuestNodeDefinition in definition.nodes:
			completion_ids.append(node.id)
	for cid: StringName in completion_ids:
		var ns: QuestNodeState = states.get(cid)
		if not ns or not ns.completed:
			return false
	return true


## Returns all successors (explicit next + implicit prerequisite-based) for validation.
## Uses the precomputed successor map for O(1) access.
func _get_all_successors(node_id: StringName, definition: QuestDefinition) -> Array[StringName]:
	var quest_successors: Dictionary = _successor_maps.get(definition.id, {})
	return quest_successors.get(node_id, [] as Array[StringName])


## Build forward-edge successor map for a quest.
## For each node, the successors are: its explicit next_node_ids, plus any node
## whose prerequisites list includes this node (implicit edges).
func _build_successor_map(definition: QuestDefinition, node_map: Dictionary) -> Dictionary:
	# Pre-index prerequisite reverse edges: node_id -> [nodes_that_have_it_as_prereq]
	var prereq_reverse: Dictionary = {}
	for node: QuestNodeDefinition in definition.nodes:
		for prereq: StringName in node.prerequisites:
			if not prereq_reverse.has(prereq):
				prereq_reverse[prereq] = []
			(prereq_reverse[prereq] as Array).append(node.id)

	var successor_map: Dictionary = {}
	for node: QuestNodeDefinition in definition.nodes:
		var successors: Array[StringName] = []
		var seen: Dictionary = {}
		for nid: StringName in node.next_node_ids:
			if not seen.has(nid):
				seen[nid] = true
				successors.append(nid)
		var implicit: Array = prereq_reverse.get(node.id, [])
		for implicit_id: StringName in implicit:
			if not seen.has(implicit_id):
				seen[implicit_id] = true
				successors.append(implicit_id)
		successor_map[node.id] = successors
	return successor_map


func _dfs_cycle_check(node_id: StringName, definition: QuestDefinition, color: Dictionary, issues: Array[QuestValidationIssue]) -> bool:
	const GRAY = 1
	const BLACK = 2
	color[node_id] = GRAY
	for successor: StringName in _get_all_successors(node_id, definition):
		if color.get(successor, 0) == GRAY:
			var issue := QuestValidationIssue.new()
			issue.type = "cycle"
			issue.node_id = node_id
			issue.detail = "Cycle detected: node '%s' has a path back to '%s'." % [node_id, successor]
			issues.append(issue)
			color[node_id] = BLACK
			return true
		if color.get(successor, 0) == 0: # WHITE
			if _dfs_cycle_check(successor, definition, color, issues):
				color[node_id] = BLACK
				return true
	color[node_id] = BLACK
	return false


## Replace [code]{key}[/code] placeholders in a string with values from [param params].
static func _resolve_variables(text: String, params: Dictionary) -> String:
	var result := text
	for key: String in params:
		result = result.replace("{%s}" % key, str(params[key]))
	return result


## Apply template parameters to a quest definition's display text and node target IDs.
func _apply_template_params(definition: QuestDefinition, params: Dictionary) -> void:
	if params.is_empty():
		return

	definition.quest_name = _resolve_variables(definition.quest_name, params)
	definition.description = _resolve_variables(definition.description, params)

	for node: QuestNodeDefinition in definition.nodes:
		node.description = _resolve_variables(node.description, params)
		var resolved_target := _resolve_variables(str(node.target_id), params)
		node.target_id = StringName(resolved_target)

	for stage: QuestStage in definition.stages:
		stage.log_entry = _resolve_variables(stage.log_entry, params)
		stage.objective = _resolve_variables(stage.objective, params)
