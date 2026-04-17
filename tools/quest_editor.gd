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
var _name_to_id: Dictionary = {}


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
	vbox.add_child(_graph)


## Open a [QuestDefinition] for editing.
func edit(definition: QuestDefinition) -> void:
	_editing = definition
	_rebuild()


func _rebuild() -> void:
	_name_to_id.clear()
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

	# Lay out nodes in a grid pattern.
	var cols := maxi(1, ceili(sqrt(_editing.nodes.size())))
	for i: int in range(_editing.nodes.size()):
		var nd: QuestNodeDefinition = _editing.nodes[i]
		var col := i % cols
		var row := i / cols
		_create_graph_node(nd, Vector2(col * 320 + 40, row * 220 + 40))

	# Draw prerequisite/next-node connections after all nodes are placed.
	for nd: QuestNodeDefinition in _editing.nodes:
		var from_name := _safe(nd.id)
		for next_id: StringName in nd.next_node_ids:
			var to_name := _safe(next_id)
			if _name_to_id.has(to_name):
				_graph.connect_node(StringName(from_name), 0, StringName(to_name), 0)


func _create_graph_node(nd: QuestNodeDefinition, pos: Vector2) -> void:
	var gn := GraphNode.new()
	var safe_name := _safe(nd.id)
	gn.name = safe_name
	gn.title = str(nd.id) if nd.id else "(unnamed)"
	gn.position_offset = pos
	_name_to_id[safe_name] = nd.id

	# ── Row 0: trigger type selector + description ──
	var row0 := HBoxContainer.new()
	gn.add_child(row0)

	var trigger_opt := OptionButton.new()
	var trigger_types := ["kill", "pickup", "talk", "custom"]
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
	nd.id = StringName("node_%d" % _editing.nodes.size())
	nd.description = ""
	nd.trigger_type = "custom"
	nd.required_count = 1
	_editing.nodes.append(nd)
	_create_graph_node(nd, _graph.scroll_offset + Vector2(80.0 + _editing.nodes.size() * 10.0, 80.0))


func _validate() -> void:
	if not _editing:
		return
	var engine := QuestGraphEngine.new()
	engine.register_quest(_editing)
	var report := engine.validate_graph(_editing.id)
	var dlg := AcceptDialog.new()
	add_child(dlg)
	if report.valid:
		dlg.title = "Validation Passed"
		dlg.dialog_text = "Quest '%s' graph is valid." % str(_editing.id)
	else:
		var lines: PackedStringArray
		for issue: QuestGraphEngine.QuestValidationIssue in report.issues:
			lines.append("• [%s] node '%s': %s" % [issue.type, str(issue.node_id), issue.detail])
		dlg.title = "Validation Issues (%d)" % report.issues.size()
		dlg.dialog_text = "\n".join(lines)
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)


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
	dlg.confirmed.connect(dlg.queue_free)


## Convert a node [StringName] id to a valid Godot node name (no spaces or slashes).
func _safe(id: StringName) -> String:
	return str(id).replace(" ", "_").replace("/", "_")
