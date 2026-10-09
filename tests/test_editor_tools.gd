## Regression tests for the Skelerealms editor tools (tools/).
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## The graph editors and inspectors build plain Controls, so their logic is
## exercised headless without an editor session. Editor-only services
## (inspector plugins, gizmos) are covered by code review, not tests.
extends GutTest


const QuestEditorScript := preload("res://addons/skelerealms/tools/quest_editor.gd")
const DialogueEditorScript := preload("res://addons/skelerealms/tools/dialogue_editor.gd")
const SpanScript := preload("res://addons/skelerealms/tools/span.gd")
const DoorConnectScript := preload("res://addons/skelerealms/tools/door_connect.gd")
const TemplateSelectorScript := preload("res://addons/skelerealms/tools/template_selector.gd")
const ScheduleEditorScene := preload("res://addons/skelerealms/tools/schedule_editor.tscn")

const AUDIT_DIR := "user://audit_editor_tools"
const COVEN_DIR := "user://audit_editor_covens"


var _old_indents: Variant = null
var _had_indents := false
var _old_covens_path: Variant = null
var _had_covens_path := false
var _old_minutes: Variant = null
var _had_minutes := false
var _old_hours: Variant = null
var _had_hours := false


func before_each() -> void:
	_had_indents = ProjectSettings.has_setting("skelerealms/savegame_indents")
	_old_indents = ProjectSettings.get_setting("skelerealms/savegame_indents", true)
	_had_covens_path = ProjectSettings.has_setting("skelerealms/covens_path")
	_old_covens_path = ProjectSettings.get_setting("skelerealms/covens_path", "res://covens")
	_had_minutes = ProjectSettings.has_setting("skelerealms/minutes_per_hour")
	_old_minutes = ProjectSettings.get_setting("skelerealms/minutes_per_hour", 31.0)
	_had_hours = ProjectSettings.has_setting("skelerealms/hours_per_day")
	_old_hours = ProjectSettings.get_setting("skelerealms/hours_per_day", 15.0)
	ProjectSettings.set_setting("skelerealms/minutes_per_hour", 31.0)
	ProjectSettings.set_setting("skelerealms/hours_per_day", 15.0)


func after_each() -> void:
	_restore_setting("skelerealms/savegame_indents", _had_indents, _old_indents)
	_restore_setting("skelerealms/covens_path", _had_covens_path, _old_covens_path)
	_restore_setting("skelerealms/minutes_per_hour", _had_minutes, _old_minutes)
	_restore_setting("skelerealms/hours_per_day", _had_hours, _old_hours)
	_rm_rf(AUDIT_DIR)
	_rm_rf(COVEN_DIR)


func _restore_setting(key: StringName, had: bool, old: Variant) -> void:
	if had:
		ProjectSettings.set_setting(key, old)
	else:
		ProjectSettings.set_setting(key, null)


func _rm_rf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for dir_name in DirAccess.get_directories_at(path):
		_rm_rf(path.path_join(dir_name))
	DirAccess.remove_absolute(path)


# ── Span ───────────────────────────────────────────────────────────────────


func test_span_overlap_cases() -> void:
	var base = SpanScript.new(Rect2(0, 0, 10, 0))
	assert_true(base.overlaps(SpanScript.new(Rect2(5, 0, 10, 0))), "Partial overlap must count.")
	assert_true(base.overlaps(SpanScript.new(Rect2(-5, 0, 20, 0))), "Enclosure must count.")
	assert_true(base.overlaps(SpanScript.new(Rect2(10, 0, 5, 0))), "Edge touch must count (inclusive).")
	assert_false(base.overlaps(SpanScript.new(Rect2(20, 0, 5, 0))), "Disjoint spans must not overlap.")
	assert_true(base.contains_point(0.0), "Start edge is inclusive.")
	assert_true(base.contains_point(10.0), "End edge is inclusive.")
	assert_false(base.contains_point(10.1), "Past the end must not contain.")


# ── DialogueEngine.validate_definition ────────────────────────────────────


func _make_dialogue_node(id: StringName, next_id: StringName = &"", terminal := false) -> DialogueNode:
	var nd := DialogueNode.new()
	nd.id = id
	nd.speaker = "Tester"
	nd.text = "Hello."
	nd.terminal = terminal
	if next_id != &"" or not terminal:
		var ch := DialogueChoice.new()
		ch.id = &"next"
		ch.text = "Continue"
		ch.next_node_id = next_id
		nd.choices = [ch]
	return nd


func _make_dialogue(nodes: Array, start: StringName) -> DialogueDefinition:
	var def := DialogueDefinition.new()
	def.id = &"test_dialogue"
	def.start_node_id = start
	var typed: Array[DialogueNode] = []
	for nd in nodes:
		typed.append(nd)
	def.nodes = typed
	return def


func test_validate_definition_accepts_valid_tree() -> void:
	var engine := DialogueEngine.new()
	var def := _make_dialogue(
		[_make_dialogue_node(&"start", &"end"), _make_dialogue_node(&"end", &"", true)],
		&"start"
	)
	assert_eq(engine.validate_definition(def), [], "Valid tree must report no issues.")


func test_validate_definition_reports_all_issue_kinds() -> void:
	var engine := DialogueEngine.new()
	var dup_a := _make_dialogue_node(&"same", &"", true)
	var dup_b := _make_dialogue_node(&"same", &"ghost", false)
	var stuck := DialogueNode.new()
	stuck.id = &"stuck"
	stuck.speaker = "Tester"
	stuck.text = "Nowhere to go."
	var def := _make_dialogue([dup_a, dup_b, stuck], &"missing")
	var issues: Array = engine.validate_definition(def)
	var kinds := {}
	for issue in issues:
		kinds[str(issue["type"])] = true
	assert_true(kinds.has("duplicate_node"), "Duplicate node ids must be reported.")
	assert_true(kinds.has("missing_start"), "Missing start node must be reported.")
	assert_true(kinds.has("dangling_choice"), "Dangling choice targets must be reported.")
	assert_true(kinds.has("dead_end"), "Choiceless non-terminal nodes must be reported.")
	assert_eq(issues.size(), 4, "Exactly one issue per defect.")


func test_validate_definition_reports_duplicate_choices() -> void:
	var engine := DialogueEngine.new()
	var nd := DialogueNode.new()
	nd.id = &"n"
	nd.speaker = "T"
	nd.text = "Pick."
	for i in 2:
		var ch := DialogueChoice.new()
		ch.id = &"same_choice"
		ch.text = "Option"
		nd.choices.append(ch)
	var def := _make_dialogue([nd], &"n")
	var issues: Array = engine.validate_definition(def)
	assert_eq(issues.size(), 1, "Duplicate choice ids collapse to one issue.")
	assert_eq(str(issues[0]["type"]), "duplicate_choice", "Issue must be typed.")


# ── Quest editor ───────────────────────────────────────────────────────────


func _make_quest_node(id: StringName, next: Array = []) -> QuestNodeDefinition:
	var nd := QuestNodeDefinition.new()
	nd.id = id
	nd.trigger_type = "talk"
	nd.target_id = &"npc"
	nd.required_count = 1
	var typed: Array[StringName] = []
	for n in next:
		typed.append(n)
	nd.next_node_ids = typed
	return nd


func _make_quest(nodes: Array) -> QuestDefinition:
	var def := QuestDefinition.new()
	def.id = &"test_quest"
	def.quest_name = "Test Quest"
	var typed: Array[QuestNodeDefinition] = []
	for nd in nodes:
		typed.append(nd)
	def.nodes = typed
	return def


func _make_quest_editor(def: QuestDefinition) -> Control:
	var ed := QuestEditorScript.new()
	add_child_autofree(ed)
	ed.edit(def)
	return ed


func _graph_node_names(ed: Control) -> Array:
	var names := []
	for child in ed._graph.get_children():
		if child is GraphNode:
			names.append(String(child.name))
	return names


func test_quest_editor_draws_nodes_and_links() -> void:
	var def := _make_quest([_make_quest_node(&"a", [&"b"]), _make_quest_node(&"b")])
	var ed := _make_quest_editor(def)
	assert_eq(_graph_node_names(ed).size(), 2, "Both nodes must appear.")
	var conns: Array = ed._graph.get_connection_list()
	assert_eq(conns.size(), 1, "The A→B link must be drawn.")
	assert_eq(String(conns[0]["from_node"]), "a", "Link must start at A.")
	assert_eq(String(conns[0]["to_node"]), "b", "Link must end at B.")


func test_quest_editor_delete_scrubs_references() -> void:
	var def := _make_quest([_make_quest_node(&"a", [&"b"]), _make_quest_node(&"b")])
	var ed := _make_quest_editor(def)
	ed._on_delete_nodes_request([&"b"])
	assert_eq(def.nodes.size(), 1, "Deleted node must leave the definition.")
	assert_true((def.nodes[0] as QuestNodeDefinition).next_node_ids.is_empty(), "Dangling links must be scrubbed.")
	assert_eq(_graph_node_names(ed), ["a"], "Graph must rebuild with one node.")


func test_quest_editor_ids_stay_unique_after_delete() -> void:
	var def := _make_quest([_make_quest_node(&"node_0"), _make_quest_node(&"node_1"), _make_quest_node(&"node_2")])
	var ed := _make_quest_editor(def)
	ed._on_delete_nodes_request([&"node_1"])
	ed._add_node()
	var ids := {}
	for nd in (def.nodes as Array):
		assert_false(ids.has((nd as QuestNodeDefinition).id), "Definition ids must stay unique.")
		ids[(nd as QuestNodeDefinition).id] = true
	var names := _graph_node_names(ed)
	assert_eq(names.size(), 3, "Graph must show three nodes.")
	var unique_names := {}
	for n in names:
		unique_names[n] = true
	assert_eq(unique_names.size(), 3, "GraphNode names must stay unique.")


func test_quest_editor_safe_name_collisions_stay_routed() -> void:
	# "a b" and "a_b" sanitize to the same node name; the editor must disambiguate.
	var def := _make_quest([_make_quest_node(&"a b", [&"a_b"]), _make_quest_node(&"a_b")])
	var ed := _make_quest_editor(def)
	var names := _graph_node_names(ed)
	assert_eq(names.size(), 2, "Both nodes must appear.")
	assert_ne(names[0], names[1], "Sanitized names must be disambiguated.")
	var conns: Array = ed._graph.get_connection_list()
	assert_eq(conns.size(), 1, "The cross link must survive disambiguation.")
	assert_eq(String(conns[0]["to_node"]), String(ed._graph.get_node(NodePath(names[1])).name), "Link must land on the second node.")


func test_quest_editor_persists_layout() -> void:
	var def := _make_quest([_make_quest_node(&"a")])
	var ed := _make_quest_editor(def)
	var gn: GraphNode = ed._graph.get_node(NodePath("a")) as GraphNode
	gn.position_offset = Vector2(500, 300)
	assert_eq((def.nodes[0] as QuestNodeDefinition).editor_position, Vector2(500, 300), "Moves must write back to the resource.")
	var ed2 := _make_quest_editor(def)
	var gn2: GraphNode = ed2._graph.get_node(NodePath("a")) as GraphNode
	assert_eq(gn2.position_offset, Vector2(500, 300), "Stored layout must be reused.")


func _last_accept_dialog(ed: Control) -> AcceptDialog:
	var found: AcceptDialog = null
	for child in ed.get_children():
		if child is AcceptDialog:
			found = child
	return found


func test_quest_editor_validate_dialogs() -> void:
	var bad := _make_quest([_make_quest_node(&"a", [&"ghost"])])
	var ed := _make_quest_editor(bad)
	ed._validate()
	await get_tree().process_frame
	var dlg := _last_accept_dialog(ed)
	assert_ne(dlg, null, "Validate must pop a dialog.")
	if dlg == null:
		return
	assert_true(dlg.title.contains("Issues"), "Dangling links must be reported.")
	assert_true(dlg.dialog_text.contains("dangling_link"), "Issue type must be named.")
	dlg.queue_free()
	await get_tree().process_frame
	var good := _make_quest([_make_quest_node(&"a")])
	var ed2 := _make_quest_editor(good)
	ed2._validate()
	await get_tree().process_frame
	var dlg2 := _last_accept_dialog(ed2)
	assert_ne(dlg2, null, "Validate must pop a dialog.")
	if dlg2 == null:
		return
	assert_true(dlg2.title.contains("Passed"), "Valid quest must pass.")
	dlg2.queue_free()
	await get_tree().process_frame


func test_quest_editor_dialog_frees_on_cancel() -> void:
	var ed := _make_quest_editor(_make_quest([_make_quest_node(&"a")]))
	ed._alert("message", "Title")
	var dlg := _last_accept_dialog(ed)
	assert_ne(dlg, null, "Alert must pop a dialog.")
	if dlg == null:
		return
	# AcceptDialog has no `cancelled` signal — X-close goes through close_requested.
	dlg.close_requested.emit()
	await get_tree().process_frame
	assert_false(is_instance_valid(dlg), "X-close must free the dialog, not leak it.")


# ── Dialogue editor ────────────────────────────────────────────────────────


func _make_dialogue_editor(def: DialogueDefinition) -> Control:
	var ed := DialogueEditorScript.new()
	add_child_autofree(ed)
	ed.edit(def)
	return ed


func test_dialogue_editor_draws_choice_ports() -> void:
	var def := _make_dialogue(
		[_make_dialogue_node(&"start", &"fin"), _make_dialogue_node(&"fin", &"", true)],
		&"start"
	)
	var ed := _make_dialogue_editor(def)
	var conns: Array = ed._graph.get_connection_list()
	assert_eq(conns.size(), 1, "The choice link must be drawn.")
	assert_eq(int(conns[0]["from_port"]), 0, "Port must match the choice index.")


func test_dialogue_editor_delete_scrubs_choices() -> void:
	var def := _make_dialogue(
		[_make_dialogue_node(&"start", &"fin"), _make_dialogue_node(&"fin", &"", true)],
		&"start"
	)
	var ed := _make_dialogue_editor(def)
	ed._on_delete_nodes_request([&"fin"])
	assert_eq(def.nodes.size(), 1, "Deleted node must leave the definition.")
	assert_eq(str((def.nodes[0] as DialogueNode).choices[0].next_node_id), "", "Dangling choice targets must be cleared.")


func test_dialogue_editor_choice_removal_reindexes_ports() -> void:
	var first := _make_dialogue_node(&"n", &"x")
	var extra := DialogueChoice.new()
	extra.id = &"second"
	extra.text = "Second"
	extra.next_node_id = &"x"
	first.choices.append(extra)
	var target := _make_dialogue_node(&"x", &"", true)
	var def := _make_dialogue([first, target], &"n")
	var ed := _make_dialogue_editor(def)
	ed._remove_choice(first, 0)
	assert_eq(first.choices.size(), 1, "One choice must remain.")
	assert_eq(str(first.choices[0].next_node_id), "x", "Surviving choice must keep its target.")
	var conns: Array = ed._graph.get_connection_list()
	assert_eq(conns.size(), 1, "One connection must remain.")
	assert_eq(int(conns[0]["from_port"]), 0, "Surviving connection must shift to port 0.")


func test_dialogue_editor_validate_button() -> void:
	var bad := _make_dialogue([_make_dialogue_node(&"start", &"ghost")], &"start")
	var ed := _make_dialogue_editor(bad)
	ed._validate()
	await get_tree().process_frame
	var dlg := _last_accept_dialog(ed)
	assert_ne(dlg, null, "Validate must pop a dialog.")
	if dlg == null:
		return
	assert_true(dlg.title.contains("Issues"), "Dangling choices must be reported.")
	assert_true(dlg.dialog_text.contains("dangling_choice"), "Issue type must be named.")
	dlg.queue_free()


# ── Save inspector checksum ────────────────────────────────────────────────


func _make_save_blob(indent: String) -> Dictionary:
	var data := {
		"schema_version": 2,
		"entity_data": {"player": {"x": 1}},
		"game_info": {},
		"other_data": {},
	}
	var text := JSON.stringify(data, indent, true, true)
	var h: int = 0x811c9dc5
	for i in range(text.length()):
		h = h ^ text.unicode_at(i)
		h = (h * 0x01000193) & 0xFFFFFFFF
	data["checksum"] = "%08x" % h
	return data


func test_save_inspector_checksum_respects_indent_setting() -> void:
	var inspector := SaveInspector.new()
	add_child_autofree(inspector)
	ProjectSettings.set_setting("skelerealms/savegame_indents", true)
	inspector._inspect(_make_save_blob("\t"), "", "tabbed.dat")
	assert_true(inspector._status_label.text.contains("valid"), "Tab-indented save must verify with indents on.")
	ProjectSettings.set_setting("skelerealms/savegame_indents", false)
	inspector._inspect(_make_save_blob(""), "", "flat.dat")
	assert_true(inspector._status_label.text.contains("valid"), "Flat save must verify with indents off (indent-setting bug).")
	inspector._inspect(_make_save_blob("\t"), "", "tabbed.dat")
	assert_true(inspector._status_label.text.contains("MISMATCH"), "Indent mismatch must be reported, not silently pass.")


# ── door_connect world search ──────────────────────────────────────────────


func test_find_world_searches_subdirectories() -> void:
	DirAccess.make_dir_recursive_absolute(AUDIT_DIR.path_join("sub"))
	FileAccess.open(AUDIT_DIR.path_join("top_world.tscn"), FileAccess.WRITE).store_string("x")
	FileAccess.open(AUDIT_DIR.path_join("sub/nested_world.tscn"), FileAccess.WRITE).store_string("x")
	assert_eq(DoorConnectScript._find_world(AUDIT_DIR, "top_world"), AUDIT_DIR.path_join("top_world.tscn"), "Top-level worlds must resolve.")
	assert_eq(DoorConnectScript._find_world(AUDIT_DIR, "nested_world"), AUDIT_DIR.path_join("sub/nested_world.tscn"), "Nested worlds must resolve with full paths.")
	assert_eq(DoorConnectScript._find_world(AUDIT_DIR, "missing"), "", "Unknown worlds must return empty.")


# ── Schedule editor ────────────────────────────────────────────────────────


func _make_schedule_event(from_hour: int, to_hour: int) -> ScheduleEvent:
	var ev := ScheduleEvent.new()
	ev.name = "Event %d-%d" % [from_hour, to_hour]
	ev.from = Timestamp.new()
	ev.from.hour = from_hour
	ev.from.minute = 0
	ev.to = Timestamp.new()
	ev.to.hour = to_hour
	ev.to.minute = 0
	return ev


func _make_schedule_editor() -> Control:
	var ed := (load("res://addons/skelerealms/tools/schedule_editor.tscn") as PackedScene).instantiate()
	add_child_autofree(ed)
	await get_tree().process_frame
	return ed


func test_schedule_editor_tracks_boxes() -> void:
	var ed := await _make_schedule_editor()
	var first_batch: Array[ScheduleEvent] = [_make_schedule_event(2, 4), _make_schedule_event(6, 8)]
	ed.edit(first_batch)
	await get_tree().process_frame
	var container: Control = ed.get_node("%Container")
	assert_eq(container.get_child_count(), 2, "One box per event.")
	var box = container.get_child(0).get_child(0)
	assert_eq(box.internal_size, int(box.size.x), "Drag base must match laid-out size.")
	var second_batch: Array[ScheduleEvent] = [_make_schedule_event(1, 2)]
	ed.edit(second_batch)
	# Two frames: queued-free boxes leave the tree at the end of frame one,
	# and the tracker's stale-entry sweep runs on frame two.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(container.get_child_count(), 1, "Re-edit must replace boxes.")
	assert_eq(ed.track_index.size(), 1, "Tracking state must reset without stale entries.")


func test_schedule_editor_grows_tracks() -> void:
	var ed := await _make_schedule_editor()
	var events: Array[ScheduleEvent] = []
	for i in 5:
		events.append(_make_schedule_event(2, 4))
	ed.edit(events)
	for i in 6:
		await get_tree().process_frame
	assert_eq(ed.tracks.size(), 5, "Five simultaneous events need five tracks.")
	for t in range(ed.tracks.size()):
		var spans: Array = (ed.tracks[t] as Dictionary).values()
		for a in range(spans.size()):
			for b in range(a + 1, spans.size()):
				assert_false(spans[a].overlaps(spans[b]), "No two boxes may share a track overlapped.")


func test_schedule_editor_time_math() -> void:
	var ed := await _make_schedule_editor()
	# HOUR_SEPARATION=256, minutes_per_hour=31 → minute ≈ 8.26px.
	assert_eq(ed.snap_to_hour(250), 256, "Near-hour positions must snap.")
	assert_eq(ed.snap_to_hour(100), 100, "Far positions must not snap.")
	assert_eq(ed.snap_to_minute(100), 99, "Near-minute positions must snap.")
	assert_eq(ed.position_from_time({"hour": 2, "minute": 0}), 512, "Position math must hold.")
	var round_tripped: Dictionary = ed.get_time_from_position(512)
	assert_eq(round_tripped["hour"], 2, "Hour must round-trip.")
	assert_eq(round_tripped["minute"], 0, "Minute must round-trip.")


# ── Save inspector latest-save search ────────────────────────────────────


func test_find_latest_save() -> void:
	var dir := AUDIT_DIR.path_join("saves")
	DirAccess.make_dir_recursive_absolute(dir)
	assert_eq(SaveInspector.find_latest_save(dir), "", "Empty directories must yield empty.")
	FileAccess.open(dir.path_join("slot_a.dat"), FileAccess.WRITE).store_string("{}")
	assert_eq(SaveInspector.find_latest_save(dir), "slot_a.dat", "Single saves must be found.")
	assert_eq(SaveInspector.find_latest_save(AUDIT_DIR.path_join("nope")), "", "Missing directories must yield empty.")


# ── Quest trigger types ──────────────────────────────────────────────────


func test_trigger_types_match_resource_hint() -> void:
	var types: Array = QuestEditorScript._trigger_types()
	for expected in ["kill", "pickup", "talk", "custom"]:
		assert_true(types.has(expected), "Editor must offer the '%s' trigger." % expected)


# ── Coven matrix ordering ──────────────────────────────────────────────────


func test_coven_matrix_sorts_by_id() -> void:
	DirAccess.make_dir_recursive_absolute(COVEN_DIR)
	for id in [&"zzz", &"aaa"]:
		var coven := Coven.new()
		coven.coven_id = id
		ResourceSaver.save(coven, COVEN_DIR.path_join("%s.tres" % id))
	ProjectSettings.set_setting("skelerealms/covens_path", COVEN_DIR)
	var matrix := preload("res://addons/skelerealms/tools/coven_matrix.gd").new()
	add_child_autofree(matrix)
	await get_tree().process_frame
	var headers: Array = []
	for child in matrix._grid.get_children():
		if child is Label and (child as Label).text.strip_edges() != "" and not (child as Label).text.contains("—"):
			headers.append((child as Label).text.strip_edges())
	assert_true(headers.size() >= 2, "Headers must render.")
	assert_eq(headers[0], "aaa", "Columns must be sorted by coven id.")
	assert_eq(headers[1], "zzz", "Sort order must hold.")


# ── Template selector scene text ───────────────────────────────────────────


func test_format_scene_never_writes_empty_uid() -> void:
	var selector := TemplateSelectorScript.new()
	var text: String = selector._format_scene("res://addons/skelerealms/npc_entity_template.tscn", "MyEntity")
	assert_true(text.contains("MyEntity"), "Instance must carry the requested name.")
	assert_true(text.contains("instance=ExtResource"), "Instance line must exist.")
	assert_false(text.contains('uid=""'), "Empty UID attributes must be omitted.")
	selector.free()
