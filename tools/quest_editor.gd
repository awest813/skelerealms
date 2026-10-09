@tool
extends Control
## Visual graph editor for [QuestDefinition] resources.
## Each [QuestNodeDefinition] appears as a [GraphNode].
## Connections between nodes represent [member QuestNodeDefinition.next_node_ids] links.
## Opened by the [QuestEditorPlugin] inspector plugin.


const _COLOR_IN := Color(0.35, 0.85, 0.45)
const _COLOR_OUT := Color(0.85, 0.45, 0.35)

var _graph: GraphEdit
var _editing: QuestDefinition
## Maps safe node name (String) → QuestNodeDefinition id (StringName).
var _name_to_id: Dictionary[String, StringName] = {}
## Reverse map: definition id → safe node name. All node-name computation
## must go through this (never raw _safe), or ids like "a b" and "a_b"
## will misroute connections.
var _id_to_name: Dictionary = {}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# ── Toolbar ──
	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	var title_lbl := Label.new()
	title_lbl.text = "  Quest Graph Editor"
	toolbar.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var add_btn := Button.new()
	add_btn.text = "+ Add Node"
	add_btn.pressed.connect(_add_node)
	toolbar.add_child(add_btn)

	var validate_btn := Button.new()
	validate_btn.text = "Validate"
	validate_btn.pressed.connect(_validate)
	toolbar.add_child(validate_btn)

	var save_btn := Button.new()
	save_btn.text = "Save Resource"
	save_btn.pressed.connect(_save)
	toolbar.add_child(save_btn)

	# ── Graph ──
	_graph = GraphEdit.new()
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)
	vbox.add_child(_graph)


## Open a [QuestDefinition] for editing.
func edit(definition: QuestDefinition) -> void:
	_editing = definition
	_rebuild()


func _rebuild() -> void:
	_name_to_id.clear()
	_id_to_name.clear()
	# Remove existing GraphNodes.
	var to_remove: Array[Node] = []
	for child: Node in _graph.get_children():
		if child is GraphNode:
			to_remove.append(child)
	for n: Node in to_remove:
		_graph.remove_child(n)
		n.queue_free()
	_graph.clear_connections()

	if not _editing:
		return

	# Use stored layout when any node has one; otherwise grid auto-layout.
	# (Stored positions are never (0,0): the grid starts at (40,40).)
	var use_stored := false
	for nd: QuestNodeDefinition in _editing.nodes:
		if nd.editor_position != Vector2.ZERO:
			use_stored = true
			break
	var cols := maxi(1, ceili(sqrt(_editing.nodes.size())))
	for i: int in range(_editing.nodes.size()):
		var nd: QuestNodeDefinition = _editing.nodes[i]
		var pos := nd.editor_position if use_stored else Vector2(i % cols * 320 + 40, i / cols * 220 + 40)
		_create_graph_node(nd, pos)

	# Draw prerequisite/next-node connections after all nodes are placed.
	# Dangling targets (unknown ids) are skipped here and reported by Validate.
	for nd: QuestNodeDefinition in _editing.nodes:
		var from_name: StringName = _id_to_name.get(nd.id, StringName(_safe(nd.id)))
		for next_id: StringName in nd.next_node_ids:
			if _id_to_name.has(next_id):
				_graph.connect_node(from_name, 0, StringName(_id_to_name[next_id]), 0)


func _create_graph_node(nd: QuestNodeDefinition, pos: Vector2) -> void:
	var gn := GraphNode.new()
	var safe_name := _unique_safe(nd.id)
	gn.name = safe_name
	gn.title = str(nd.id) if nd.id else "(unnamed)"
	gn.position_offset = pos
	nd.editor_position = pos
	gn.position_offset_changed.connect(func() -> void: nd.editor_position = gn.position_offset)
	_name_to_id[safe_name] = nd.id
	_id_to_name[nd.id] = safe_name

	# ── Row 0: trigger type selector + description ──
	var row0 := HBoxContainer.new()
	gn.add_child(row0)

	var trigger_opt := OptionButton.new()
	var trigger_types := _trigger_types()
	for t: String in trigger_types:
		trigger_opt.add_item(t)
	var ti := trigger_types.find(nd.trigger_type)
	trigger_opt.select(maxi(0, ti))
	trigger_opt.item_selected.connect(func(idx: int) -> void:
		nd.trigger_type = trigger_opt.get_item_text(idx))
	trigger_opt.custom_minimum_size.x = 80
	row0.add_child(trigger_opt)

	var desc_edit := LineEdit.new()
	desc_edit.placeholder_text = "Description..."
	desc_edit.text = nd.description
	desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_edit.text_changed.connect(func(t: String) -> void: nd.description = t)
	row0.add_child(desc_edit)

	# Slot 0 carries both the left (in) and right (out) connection ports.
	gn.set_slot(0, true, 0, _COLOR_IN, true, 0, _COLOR_OUT)

	# ── Row 1: target entity ID + required count ──
	var row1 := HBoxContainer.new()
	gn.add_child(row1)

	var tgt_edit := LineEdit.new()
	tgt_edit.placeholder_text = "Target ID"
	tgt_edit.text = str(nd.target_id)
	tgt_edit.custom_minimum_size.x = 110
	tgt_edit.text_changed.connect(func(t: String) -> void: nd.target_id = StringName(t))
	row1.add_child(tgt_edit)

	var x_lbl := Label.new()
	x_lbl.text = "  ×"
	row1.add_child(x_lbl)

	var count_spin := SpinBox.new()
	count_spin.min_value = 1
	count_spin.max_value = 9999
	count_spin.value = nd.required_count
	count_spin.custom_minimum_size.x = 70
	count_spin.value_changed.connect(func(v: float) -> void: nd.required_count = int(v))
	row1.add_child(count_spin)

	_graph.add_child(gn)


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not _editing:
		return
	_graph.connect_node(from_node, from_port, to_node, to_port)
	var from_id: StringName = _name_to_id.get(str(from_node), StringName(str(from_node)))
	var to_id: StringName = _name_to_id.get(str(to_node), StringName(str(to_node)))
	for nd: QuestNodeDefinition in _editing.nodes:
		if nd.id == from_id and not nd.next_node_ids.has(to_id):
			nd.next_node_ids.append(to_id)
			break


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not _editing:
		return
	_graph.disconnect_node(from_node, from_port, to_node, to_port)
	var from_id: StringName = _name_to_id.get(str(from_node), StringName(str(from_node)))
	var to_id: StringName = _name_to_id.get(str(to_node), StringName(str(to_node)))
	for nd: QuestNodeDefinition in _editing.nodes:
		if nd.id == from_id:
			nd.next_node_ids.erase(to_id)
			break


func _add_node() -> void:
	if not _editing:
		return
	var nd := QuestNodeDefinition.new()
	nd.id = _next_node_id()
	nd.description = ""
	nd.trigger_type = "custom"
	nd.required_count = 1
	_editing.nodes.append(nd)
	_create_graph_node(nd, _graph.scroll_offset + Vector2(80.0 + _editing.nodes.size() * 10.0, 80.0))


## Delete-selected-nodes support: removes the nodes, scrubs every
## next_node_ids reference to them, then rebuilds to keep ports in sync.
func _on_delete_nodes_request(node_names: Array) -> void:
	if not _editing:
		return
	var doomed := {}
	for node_name: Variant in node_names:
		var doomed_id: StringName = _name_to_id.get(str(node_name), StringName(str(node_name)))
		doomed[doomed_id] = true
		_name_to_id.erase(str(node_name))
		_id_to_name.erase(doomed_id)
	if doomed.is_empty():
		return
	for nd: QuestNodeDefinition in _editing.nodes:
		for dead_id: Variant in doomed:
			nd.next_node_ids.erase(dead_id)
	var kept: Array[QuestNodeDefinition] = []
	for nd: QuestNodeDefinition in _editing.nodes:
		if not doomed.has(nd.id):
			kept.append(nd)
	_editing.nodes = kept
	_rebuild()


## First unused "node_N" id, robust against deletions.
func _next_node_id() -> StringName:
	var taken := {}
	for nd: QuestNodeDefinition in _editing.nodes:
		taken[nd.id] = true
	var n := _editing.nodes.size()
	while taken.has(StringName("node_%d" % n)):
		n += 1
	return StringName("node_%d" % n)


func _validate() -> void:
	if not _editing:
		return
	var engine := QuestGraphEngine.new()
	engine.register_quest(_editing)
	var report := engine.validate_graph(_editing.id)
	# The engine checks reachability, dead ends, and cycles — but not links
	# to unknown nodes, so the editor reports those itself.
	var known := {}
	for nd: QuestNodeDefinition in _editing.nodes:
		known[nd.id] = true
	var extra: Array[QuestGraphEngine.QuestValidationIssue] = []
	for nd: QuestNodeDefinition in _editing.nodes:
		for next_id: StringName in nd.next_node_ids:
			if not known.has(next_id):
				var dangling := QuestGraphEngine.QuestValidationIssue.new()
				dangling.type = "dangling_link"
				dangling.node_id = nd.id
				dangling.detail = "Node '%s' links to unknown node '%s'." % [nd.id, next_id]
				extra.append(dangling)
	var dlg := AcceptDialog.new()
	add_child(dlg)
	if report.valid and extra.is_empty():
		dlg.title = "Validation Passed"
		dlg.dialog_text = "Quest '%s' graph is valid." % str(_editing.id)
	else:
		var lines: PackedStringArray
		for issue: QuestGraphEngine.QuestValidationIssue in report.issues:
			lines.append("• [%s] node '%s': %s" % [issue.type, str(issue.node_id), issue.detail])
		for issue: QuestGraphEngine.QuestValidationIssue in extra:
			lines.append("• [%s] node '%s': %s" % [issue.type, str(issue.node_id), issue.detail])
		dlg.title = "Validation Issues (%d)" % (report.issues.size() + extra.size())
		dlg.dialog_text = "\n".join(lines)
	dlg.popup_centered()
	_free_dialog_on_close(dlg)


func _save() -> void:
	if not _editing:
		return
	if _editing.resource_path.is_empty():
		_alert("Resource has no file path. Save it from the FileSystem dock first.", "Cannot Save")
		return
	ResourceSaver.save(_editing)
	EditorInterface.get_resource_filesystem().scan()


func _alert(msg: String, title: String) -> void:
	var dlg := AcceptDialog.new()
	add_child(dlg)
	dlg.title = title
	dlg.dialog_text = msg
	dlg.popup_centered()
	_free_dialog_on_close(dlg)


## AcceptDialog has no `cancelled` signal (only ConfirmationDialog does), so
## hook OK plus the window's own close request — otherwise every X-close
## leaks a dialog.
func _free_dialog_on_close(dlg: AcceptDialog) -> void:
	dlg.confirmed.connect(dlg.queue_free)
	dlg.close_requested.connect(dlg.queue_free)


## Convert a node [StringName] id to a valid Godot node name (no spaces or slashes).
func _safe(id: StringName) -> String:
	return str(id).replace(" ", "_").replace("/", "_")


## Trigger types straight from the QuestNodeDefinition export hint, so the
## editor can never drift out of sync with the runtime. Static for tests.
static func _trigger_types() -> Array:
	for prop: Dictionary in ClassDB.class_get_property_list("QuestNodeDefinition"):
		if str(prop.get("name", "")) == "trigger_type":
			var options := str(prop.get("hint_string", "")).split(",", false)
			if not options.is_empty():
				return options
	return ["kill", "pickup", "talk", "custom"]


## Collision-proof variant: "a b" and "a_b" must not share a GraphNode name,
## or connections would misroute.
func _unique_safe(id: StringName) -> String:
	var base := _safe(id)
	var candidate := base
	var suffix := 1
	while _name_to_id.has(candidate):
		suffix += 1
		candidate = "%s_%d" % [base, suffix]
	return candidate
