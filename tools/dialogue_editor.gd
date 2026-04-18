@tool
extends Control
## Visual graph editor for [DialogueDefinition] resources.
##
## Each [DialogueNode] appears as a [GraphNode]:
##   - Slot 0 (row "▷ in"):  left port only  → incoming connections.
##   - Slot 2+ (choice rows): right port only → outgoing connections, one per choice.
##     Right port index P corresponds to [member DialogueNode.choices][P].
##
## Connecting from node A port P to node B sets
## [member DialogueChoice.next_node_id] on choice P of A to B's id.
## Disconnecting clears [member DialogueChoice.next_node_id] (keeps the choice text).
##
## The right-hand panel shows full properties and choices for the selected node.
## Opened by the [DialogueEditorPlugin] inspector plugin.


const _COLOR_IN := Color(0.4, 0.7, 1.0)
const _COLOR_OUT := Color(1.0, 0.75, 0.2)

var _graph: GraphEdit
var _props_scroll: ScrollContainer
var _props: VBoxContainer
var _editing: DialogueDefinition
var _selected_id: StringName = &""
## Maps safe node name (String) → DialogueNode id (StringName).
var _name_to_id: Dictionary[String, StringName] = {}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	# ── Toolbar ──
	var toolbar := HBoxContainer.new()
	root_vbox.add_child(toolbar)

	var title_lbl := Label.new()
	title_lbl.text = "  Dialogue Tree Editor"
	toolbar.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var add_btn := Button.new()
	add_btn.text = "+ Add Node"
	add_btn.pressed.connect(_add_node)
	toolbar.add_child(add_btn)

	var save_btn := Button.new()
	save_btn.text = "Save Resource"
	save_btn.pressed.connect(_save)
	toolbar.add_child(save_btn)

	# ── Main area: graph + properties panel ──
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 800
	root_vbox.add_child(split)

	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.node_selected.connect(_on_node_selected)
	split.add_child(_graph)

	_props_scroll = ScrollContainer.new()
	_props_scroll.custom_minimum_size.x = 300
	_props_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_props_scroll)

	_props = VBoxContainer.new()
	_props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_props_scroll.add_child(_props)

	_show_props_placeholder()


## Open a [DialogueDefinition] for editing.
func edit(definition: DialogueDefinition) -> void:
	_editing = definition
	_selected_id = &""
	_rebuild()
	_show_props_placeholder()


func _rebuild() -> void:
	_name_to_id.clear()
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

	var cols := maxi(1, ceili(sqrt(_editing.nodes.size())))
	for i: int in range(_editing.nodes.size()):
		var nd: DialogueNode = _editing.nodes[i]
		var col := i % cols
		var row := i / cols
		_create_graph_node(nd, Vector2(col * 340 + 40, row * 240 + 40))

	# Draw connections: for each node's choice that has a next_node_id.
	for nd: DialogueNode in _editing.nodes:
		var from_name := _safe(nd.id)
		for p: int in range(nd.choices.size()):
			var ch: DialogueChoice = nd.choices[p]
			if ch.next_node_id == &"":
				continue
			var to_name := _safe(ch.next_node_id)
			if _name_to_id.has(to_name):
				_graph.connect_node(StringName(from_name), p, StringName(to_name), 0)


func _create_graph_node(nd: DialogueNode, pos: Vector2) -> void:
	var gn := GraphNode.new()
	var safe_name := _safe(nd.id)
	gn.name = safe_name
	gn.title = str(nd.id) if nd.id else "(unnamed)"
	gn.position_offset = pos
	_name_to_id[safe_name] = nd.id

	# ── Slot 0: input row ──
	var in_row := Label.new()
	in_row.text = " ▷  in"
	gn.add_child(in_row)
	gn.set_slot(0, true, 0, _COLOR_IN, false, 0, _COLOR_OUT)

	# ── Slot 1: speaker + text preview (display only, no ports) ──
	var info_box := VBoxContainer.new()
	gn.add_child(info_box)
	var speaker_lbl := Label.new()
	speaker_lbl.text = nd.speaker if nd.speaker != "" else "(no speaker)"
	speaker_lbl.add_theme_color_override(&"font_color", Color(0.8, 0.8, 0.5))
	info_box.add_child(speaker_lbl)
	var text_lbl := Label.new()
	var preview := nd.text.left(48) + ("…" if nd.text.length() > 48 else "")
	text_lbl.text = preview if preview != "" else "(no text)"
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.custom_minimum_size.x = 200
	info_box.add_child(text_lbl)
	if nd.terminal:
		var term_lbl := Label.new()
		term_lbl.text = "[ terminal ]"
		term_lbl.add_theme_color_override(&"font_color", Color(1.0, 0.5, 0.5))
		info_box.add_child(term_lbl)
	gn.set_slot(1, false, 0, _COLOR_IN, false, 0, _COLOR_OUT)

	# ── Slots 2+: one row per choice (right port only) ──
	_add_choice_slots(gn, nd)

	_graph.add_child(gn)


func _add_choice_slots(gn: GraphNode, nd: DialogueNode) -> void:
	for p: int in range(nd.choices.size()):
		var ch: DialogueChoice = nd.choices[p]
		var ch_row := Label.new()
		var ch_preview := ch.text.left(32) + ("…" if ch.text.length() > 32 else "")
		ch_row.text = "[%d] %s" % [p, ch_preview if ch_preview != "" else "(empty)"]
		gn.add_child(ch_row)
		var slot_idx := p + 2
		gn.set_slot(slot_idx, false, 0, _COLOR_IN, true, 0, _COLOR_OUT)


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not _editing:
		return
	var from_id: StringName = _name_to_id.get(str(from_node), StringName(str(from_node)))
	var to_id: StringName = _name_to_id.get(str(to_node), StringName(str(to_node)))

	# Find the source DialogueNode.
	var src_nd: DialogueNode = _find_dialogue_node(from_id)
	if not src_nd:
		return

	# from_port corresponds to choice index.
	if from_port < 0 or from_port >= src_nd.choices.size():
		return

	# Remove any existing connection from this port before adding the new one.
	var old_target := _safe(src_nd.choices[from_port].next_node_id)
	if old_target != "":
		_graph.disconnect_node(from_node, from_port, StringName(old_target), 0)

	src_nd.choices[from_port].next_node_id = to_id
	_graph.connect_node(from_node, from_port, to_node, to_port)

	if _selected_id == from_id:
		_refresh_props()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not _editing:
		return
	var from_id: StringName = _name_to_id.get(str(from_node), StringName(str(from_node)))
	var src_nd: DialogueNode = _find_dialogue_node(from_id)
	if src_nd and from_port < src_nd.choices.size():
		src_nd.choices[from_port].next_node_id = &""
	_graph.disconnect_node(from_node, from_port, to_node, to_port)

	if _selected_id == from_id:
		_refresh_props()


func _on_node_selected(node: Node) -> void:
	if not (node is GraphNode):
		return
	var safe_name := node.name as String
	_selected_id = _name_to_id.get(safe_name, &"")
	_refresh_props()


func _refresh_props() -> void:
	if _selected_id == &"":
		_show_props_placeholder()
		return
	var nd := _find_dialogue_node(_selected_id)
	if not nd:
		_show_props_placeholder()
		return
	_show_props_for_node(nd)


func _show_props_placeholder() -> void:
	_clear_props()
	var lbl := Label.new()
	lbl.text = "Select a node in the graph\nto edit its properties."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))
	_props.add_child(lbl)


func _show_props_for_node(nd: DialogueNode) -> void:
	_clear_props()

	var id_lbl := Label.new()
	id_lbl.text = "Node: %s" % str(nd.id)
	id_lbl.add_theme_font_size_override(&"font_size", 14)
	_props.add_child(id_lbl)

	_props.add_child(HSeparator.new())

	# Speaker
	var spk_lbl := Label.new()
	spk_lbl.text = "Speaker"
	_props.add_child(spk_lbl)
	var spk_edit := LineEdit.new()
	spk_edit.text = nd.speaker
	spk_edit.text_changed.connect(func(t: String) -> void:
		nd.speaker = t
		_refresh_graph_node_preview(nd))
	_props.add_child(spk_edit)

	# Text
	var txt_lbl := Label.new()
	txt_lbl.text = "Text"
	_props.add_child(txt_lbl)
	var txt_edit := TextEdit.new()
	txt_edit.text = nd.text
	txt_edit.custom_minimum_size = Vector2(0, 80)
	txt_edit.text_changed.connect(func() -> void:
		nd.text = txt_edit.text
		_refresh_graph_node_preview(nd))
	_props.add_child(txt_edit)

	# Terminal flag
	var term_box := CheckBox.new()
	term_box.text = "Terminal (ends dialogue)"
	term_box.button_pressed = nd.terminal
	term_box.toggled.connect(func(on: bool) -> void:
		nd.terminal = on
		_refresh_graph_node_preview(nd))
	_props.add_child(term_box)

	_props.add_child(HSeparator.new())

	# Choices
	var ch_hdr := Label.new()
	ch_hdr.text = "Choices"
	ch_hdr.add_theme_font_size_override(&"font_size", 13)
	_props.add_child(ch_hdr)

	for p: int in range(nd.choices.size()):
		var ch: DialogueChoice = nd.choices[p]
		_props.add_child(_build_choice_row(nd, ch, p))

	var add_ch_btn := Button.new()
	add_ch_btn.text = "+ Add Choice"
	add_ch_btn.pressed.connect(func() -> void: _add_choice(nd))
	_props.add_child(add_ch_btn)


func _build_choice_row(nd: DialogueNode, ch: DialogueChoice, p: int) -> Control:
	var panel := PanelContainer.new()
	var inner := VBoxContainer.new()
	panel.add_child(inner)

	var header := HBoxContainer.new()
	inner.add_child(header)

	var idx_lbl := Label.new()
	idx_lbl.text = "[%d]" % p
	idx_lbl.custom_minimum_size.x = 24
	header.add_child(idx_lbl)

	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size.x = 28
	del_btn.pressed.connect(func() -> void: _remove_choice(nd, p))
	header.add_child(del_btn)

	var ch_txt_edit := LineEdit.new()
	ch_txt_edit.placeholder_text = "Choice text…"
	ch_txt_edit.text = ch.text
	ch_txt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch_txt_edit.text_changed.connect(func(t: String) -> void:
		ch.text = t
		_rebuild_graph_node_slots(nd))
	inner.add_child(ch_txt_edit)

	var next_lbl := Label.new()
	next_lbl.text = "→ next node id"
	inner.add_child(next_lbl)

	var next_edit := LineEdit.new()
	next_edit.placeholder_text = "target node id (blank = end)"
	next_edit.text = str(ch.next_node_id)
	next_edit.text_submitted.connect(func(t: String) -> void:
		_update_choice_target(nd, ch, p, StringName(t)))
	inner.add_child(next_edit)

	# Conditions / effects summary
	if not ch.conditions.is_empty():
		var cond_lbl := Label.new()
		cond_lbl.text = "  Conditions: %d" % ch.conditions.size()
		cond_lbl.add_theme_color_override(&"font_color", Color(0.6, 0.9, 0.6))
		inner.add_child(cond_lbl)
	if not ch.effects.is_empty():
		var eff_lbl := Label.new()
		eff_lbl.text = "  Effects: %d" % ch.effects.size()
		eff_lbl.add_theme_color_override(&"font_color", Color(0.9, 0.7, 0.4))
		inner.add_child(eff_lbl)

	return panel


func _update_choice_target(nd: DialogueNode, ch: DialogueChoice, port: int, new_id: StringName) -> void:
	var safe_from := _safe(nd.id)
	# Remove old connection.
	if ch.next_node_id != &"":
		var old_safe := _safe(ch.next_node_id)
		_graph.disconnect_node(StringName(safe_from), port, StringName(old_safe), 0)
	ch.next_node_id = new_id
	# Add new connection if target exists.
	if new_id != &"":
		var to_safe := _safe(new_id)
		if _name_to_id.has(to_safe):
			_graph.connect_node(StringName(safe_from), port, StringName(to_safe), 0)


func _add_choice(nd: DialogueNode) -> void:
	var ch := DialogueChoice.new()
	ch.id = StringName("choice_%d" % nd.choices.size())
	ch.text = ""
	nd.choices.append(ch)
	_rebuild_graph_node_slots(nd)
	_show_props_for_node(nd)


func _remove_choice(nd: DialogueNode, idx: int) -> void:
	if idx < 0 or idx >= nd.choices.size():
		return
	var ch: DialogueChoice = nd.choices[idx]
	# Clear graph connection for this choice.
	if ch.next_node_id != &"":
		var safe_from := _safe(nd.id)
		var safe_to := _safe(ch.next_node_id)
		_graph.disconnect_node(StringName(safe_from), idx, StringName(safe_to), 0)
	nd.choices.remove_at(idx)
	# Rebuild remaining connections (port indices shifted).
	_rebuild_graph_node_connections(nd)
	_rebuild_graph_node_slots(nd)
	_show_props_for_node(nd)


## Rebuild only the choice slots on an existing [GraphNode] without recreating it.
func _rebuild_graph_node_slots(nd: DialogueNode) -> void:
	var safe_name := _safe(nd.id)
	var gn: GraphNode = _graph.get_node_or_null(NodePath(safe_name)) as GraphNode
	if not gn:
		return
	# Remove all children after slot 1 (keep slot 0 = in row, slot 1 = info box).
	while gn.get_child_count() > 2:
		var last: Node = gn.get_child(gn.get_child_count() - 1)
		gn.remove_child(last)
		last.queue_free()
	# Re-add choice rows.
	_add_choice_slots(gn, nd)


## Refresh the speaker/text preview label on a [GraphNode].
func _refresh_graph_node_preview(nd: DialogueNode) -> void:
	var safe_name := _safe(nd.id)
	var gn: GraphNode = _graph.get_node_or_null(NodePath(safe_name)) as GraphNode
	if not gn:
		return
	# Info box is child 1, speaker is info_box.get_child(0).
	var info_box: Node = gn.get_child(1)
	if info_box and info_box.get_child_count() >= 2:
		(info_box.get_child(0) as Label).text = nd.speaker if nd.speaker != "" else "(no speaker)"
		var preview := nd.text.left(48) + ("…" if nd.text.length() > 48 else "")
		(info_box.get_child(1) as Label).text = preview if preview != "" else "(no text)"


## Reconnect all choice connections for a node after choice indices shift.
func _rebuild_graph_node_connections(nd: DialogueNode) -> void:
	var safe_from := _safe(nd.id)
	# Clear all outgoing connections from this node.
	var conns := _graph.get_connection_list()
	for conn: Dictionary in conns:
		if str(conn.from_node) == safe_from:
			_graph.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	# Re-add connections based on current choice array.
	for p: int in range(nd.choices.size()):
		var ch: DialogueChoice = nd.choices[p]
		if ch.next_node_id == &"":
			continue
		var to_safe := _safe(ch.next_node_id)
		if _name_to_id.has(to_safe):
			_graph.connect_node(StringName(safe_from), p, StringName(to_safe), 0)


func _add_node() -> void:
	if not _editing:
		return
	var nd := DialogueNode.new()
	nd.id = StringName("node_%d" % _editing.nodes.size())
	nd.speaker = ""
	nd.text = ""
	_editing.nodes.append(nd)
	_create_graph_node(nd, _graph.scroll_offset + Vector2(80.0 + _editing.nodes.size() * 10.0, 80.0))


func _save() -> void:
	if not _editing:
		return
	if _editing.resource_path.is_empty():
		_alert("Resource has no file path. Save it from the FileSystem dock first.", "Cannot Save")
		return
	ResourceSaver.save(_editing)
	EditorInterface.get_resource_filesystem().scan()


func _clear_props() -> void:
	for child: Node in _props.get_children():
		_props.remove_child(child)
		child.queue_free()


func _find_dialogue_node(id: StringName) -> DialogueNode:
	if not _editing:
		return null
	for nd: DialogueNode in _editing.nodes:
		if nd.id == id:
			return nd
	return null


func _alert(msg: String, title: String) -> void:
	var dlg := AcceptDialog.new()
	add_child(dlg)
	dlg.title = title
	dlg.dialog_text = msg
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)


## Convert a node [StringName] id to a valid Godot node name.
func _safe(id: StringName) -> String:
	return str(id).replace(" ", "_").replace("/", "_")
