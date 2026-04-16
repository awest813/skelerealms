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

	func serialize() -> Dictionary:
		var node_data := {}
		for node_id: StringName in nodes:
			node_data[node_id] = (nodes[node_id] as QuestNodeState).serialize()
		return {
			"status": status,
			"nodes": node_data,
		}

	static func deserialize(data: Dictionary) -> QuestRuntimeState:
		var s := QuestRuntimeState.new()
		s.status = data.get("status", "inactive")
		for node_id: String in data.get("nodes", {}):
			s.nodes[StringName(node_id)] = QuestNodeState.deserialize(data["nodes"][node_id])
		return s


## Result returned by [method apply_event] for each affected quest.
class QuestEventResult extends RefCounted:
	var quest_id: StringName
	var activated_node_ids: Array[StringName] = []
	var completed_node_ids: Array[StringName] = []
	var quest_completed: bool = false
	var xp_reward: int = 0


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
var _definitions: Dictionary = {}
## quest_id -> QuestRuntimeState
var _states: Dictionary = {}


# ── Public API ──────────────────────────────────────────────────────────────


## Register a quest definition. Validates the definition and creates empty runtime state.
func register_quest(definition: QuestDefinition) -> void:
	_validate_definition(definition)
	_definitions[definition.id] = definition
	_states[definition.id] = _create_empty_runtime_state(definition)


## Activate a quest. Returns true if the quest was activated.
func activate_quest(quest_id: StringName) -> bool:
	var definition: QuestDefinition = _definitions.get(quest_id)
	var state: QuestRuntimeState = _states.get(quest_id)
	if not definition or not state or state.status == "completed":
		return false

	state.status = "active"
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
		var delta := max(1, event.amount)

		for node: QuestNodeDefinition in definition.nodes:
			var node_state: QuestNodeState = state.nodes.get(node.id)
			if not node_state or not node_state.active or node_state.completed:
				continue
			if node.trigger_type != event.type or node.target_id != event.target_id:
				continue

			node_state.progress = min(node.required_count, node_state.progress + delta)
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

		if completed_ids.is_empty() and activated_ids.is_empty():
			continue

		var quest_completed := _is_quest_completed(definition, state.nodes)
		if quest_completed:
			state.status = "completed"

		# Also activate any implicit nodes whose prerequisites are now satisfied
		_activate_implicit_nodes(definition, state.nodes, activated_ids)

		var result := QuestEventResult.new()
		result.quest_id = quest_id
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
		result.xp_reward = definition.xp_reward if quest_completed else 0
		results.append(result)

	return results


## Serialize all quest state for saving.
func get_snapshot() -> Dictionary:
	var quests := {}
	for quest_id: StringName in _states:
		quests[quest_id] = (_states[quest_id] as QuestRuntimeState).serialize()
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


## Reset all runtime state while keeping definitions. Re-creates empty state for each quest.
func reset_all_state() -> void:
	var defs := _definitions.duplicate()
	_definitions.clear()
	_states.clear()
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
	# Implicit: any node that lists this node as a prerequisite
	var ids: Array[StringName] = []
	for candidate: QuestNodeDefinition in definition.nodes:
		if candidate.prerequisites.has(node.id):
			ids.append(candidate.id)
	return ids


func _are_prerequisites_completed(node_id: StringName, definition: QuestDefinition, states: Dictionary) -> bool:
	for node: QuestNodeDefinition in definition.nodes:
		if node.id == node_id:
			if node.prerequisites.is_empty():
				return true
			for prereq: StringName in node.prerequisites:
				var ps: QuestNodeState = states.get(prereq)
				if not ps or not ps.completed:
					return false
			return true
	return false


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
func _get_all_successors(node_id: StringName, definition: QuestDefinition) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen := {}
	# Find the node
	for node: QuestNodeDefinition in definition.nodes:
		if node.id == node_id:
			for nid: StringName in node.next_node_ids:
				if not seen.has(nid):
					seen[nid] = true
					result.append(nid)
			break
	# Implicit successors: nodes whose prerequisites include node_id
	for node: QuestNodeDefinition in definition.nodes:
		if node.prerequisites.has(node_id) and not seen.has(node.id):
			seen[node.id] = true
			result.append(node.id)
	return result


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
