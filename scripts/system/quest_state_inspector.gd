class_name QuestStateInspector
extends CanvasLayer
## Runtime debugging panel that shows the current state of all registered quests.
## Displays each quest's status (inactive / active / completed) and, for active
## quests, the per-node progress (waiting / active / done).
## [br]
## Add this node anywhere in your scene tree. Toggle with [member toggle_key]
## (default F9). Use [member active_only] to filter the list to active quests only.


## Key that toggles overlay visibility.
@export var toggle_key: Key = KEY_F9
## Seconds between data refreshes.
@export var update_interval: float = 1.0
## When true only active quests are shown; when false all registered quests appear.
@export var active_only: bool = false

var _content: VBoxContainer
var _scroll: ScrollContainer
var _active_check: CheckButton
var _timer: float = 0.0


func _ready() -> void:
	layer = 99
	_build_ui()
	visible = false


func _build_ui() -> void:
	var root := PanelContainer.new()
	root.position = Vector2(8.0, 8.0)
	root.custom_minimum_size = Vector2(480.0, 0.0)
	add_child(root)

	var vbox := VBoxContainer.new()
	root.add_child(vbox)

	var title := Label.new()
	title.text = "Quest State Inspector  [%s to close]" % OS.get_keycode_string(toggle_key)
	title.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.5))
	vbox.add_child(title)

	# ── Filter bar ──
	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)
	var filter_lbl := Label.new()
	filter_lbl.text = "  Active only:"
	hbox.add_child(filter_lbl)
	_active_check = CheckButton.new()
	_active_check.button_pressed = active_only
	_active_check.toggled.connect(func(pressed: bool) -> void:
		active_only = pressed
		_timer = update_interval  # force immediate refresh
	)
	hbox.add_child(_active_check)

	vbox.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(480.0, 500.0)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey \
			and (event as InputEventKey).keycode == toggle_key \
			and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		visible = not visible


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	_refresh()


func _refresh() -> void:
	for child in _content.get_children():
		child.queue_free()

	var qs: Node = get_node_or_null("/root/QuestSystem")
	if not qs:
		_content.add_child(_make_label("QuestSystem autoload not available.", Color(1.0, 0.4, 0.4)))
		return

	var quest_ids: Array[StringName] = qs.get_registered_quest_ids()
	if quest_ids.is_empty():
		_content.add_child(_make_label("(no quests registered)", Color(0.6, 0.6, 0.6)))
		return

	var shown := 0
	for quest_id: StringName in quest_ids:
		var status: String = qs.get_quest_status(quest_id)
		if active_only and status != "active":
			continue
		_add_quest_panel(qs, quest_id, status)
		shown += 1

	if shown == 0:
		_content.add_child(_make_label("(no active quests)", Color(0.6, 0.6, 0.6)))


func _add_quest_panel(qs: Node, quest_id: StringName, status: String) -> void:
	var frame := PanelContainer.new()
	var inner := VBoxContainer.new()
	frame.add_child(inner)
	_content.add_child(frame)

	var status_col: Color
	match status:
		"active":    status_col = Color(0.4, 1.0, 0.4)
		"completed": status_col = Color(0.6, 0.6, 1.0)
		_:           status_col = Color(0.6, 0.6, 0.6)

	inner.add_child(_make_label("▶ %s  [%s]" % [quest_id, status.to_upper()], status_col))

	if status == "active":
		var state: QuestGraphEngine.QuestRuntimeState = qs.get_quest_state(quest_id)
		if state:
			for node_id: StringName in state.nodes:
				var ns: QuestGraphEngine.QuestNodeState = state.nodes[node_id]
				var node_col: Color
				if ns.completed:
					node_col = Color(0.5, 0.9, 0.5)
				elif ns.active:
					node_col = Color(1.0, 0.85, 0.3)
				else:
					node_col = Color(0.5, 0.5, 0.5)
				var node_status: String
				if ns.completed:
					node_status = "done"
				elif ns.active:
					node_status = "active"
				else:
					node_status = "waiting"
				inner.add_child(_make_label(
					"  ● %s — %s  (progress: %d)" % [node_id, node_status, ns.progress],
					node_col
				))


func _make_label(text: String, col: Color = Color.WHITE) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override(&"font_color", col)
	return lbl
