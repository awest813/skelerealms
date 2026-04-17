class_name AIStateOverlay
extends CanvasLayer
## Runtime debugging overlay that displays real-time NPC AI state.
## Shows each active NPC's GOAP debug info (current objective, active action,
## action queue) and perception-memory awareness levels.
## [br]
## Add this node anywhere in your scene tree to enable it.
## Toggle visibility with [member toggle_key] (default F10) or by setting
## [member visible] from code.
## [br]
## The overlay refreshes at [member update_interval] to reduce CPU overhead.


## Key that toggles overlay visibility.
@export var toggle_key: Key = KEY_F10
## Seconds between data refreshes.
@export var update_interval: float = 0.5
## Maximum number of NPC entries to display simultaneously.
@export var max_display_count: int = 8

var _panel: PanelContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _timer: float = 0.0


func _ready() -> void:
	layer = 100
	_build_ui()
	visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(8.0, 8.0)
	_panel.custom_minimum_size = Vector2(460.0, 0.0)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "AI State Overlay  [%s to close]" % OS.get_keycode_string(toggle_key)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.2))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(460.0, 500.0)
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

	if not is_instance_valid(SKEntityManager.instance):
		_content.add_child(_make_label("SKEntityManager not available.", Color(1.0, 0.4, 0.4)))
		return

	var count := 0
	for entity_id: StringName in SKEntityManager.instance.entities:
		if count >= max_display_count:
			var remaining: int = SKEntityManager.instance.entities.size() - count
			_content.add_child(_make_label("…and %d more NPCs" % remaining, Color(0.6, 0.6, 0.6)))
			break

		var entity: SKEntity = SKEntityManager.instance.entities[entity_id]
		var npc: NPCComponent = entity.get_component("NPCComponent") as NPCComponent
		if not npc:
			continue
		var goap: GOAPComponent = entity.get_component("GOAPComponent") as GOAPComponent
		_add_npc_panel(entity_id, npc, goap)
		count += 1

	if count == 0:
		_content.add_child(_make_label("(no active NPCs)", Color(0.6, 0.6, 0.6)))


func _add_npc_panel(entity_id: StringName, npc: NPCComponent, goap: GOAPComponent) -> void:
	var frame := PanelContainer.new()
	var inner := VBoxContainer.new()
	frame.add_child(inner)
	_content.add_child(frame)

	inner.add_child(_make_label("▶ %s" % entity_id, Color(0.4, 0.9, 1.0)))

	if goap:
		# Reuse the existing gather_debug_info() helper which formats all GOAP state.
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.text = goap.gather_debug_info()
		inner.add_child(rtl)

	if not npc.perception_memory.is_empty():
		inner.add_child(_make_label("  Tracking:", Color(0.85, 0.85, 0.3)))
		for tracked_id: StringName in npc.perception_memory:
			var vis: float = npc.perception_memory[tracked_id].get(&"visibility", 0.0)
			var col: Color
			if vis > 0.5:
				col = Color(1.0, 0.3, 0.3)
			elif vis > 0.0:
				col = Color(1.0, 0.75, 0.2)
			else:
				col = Color(0.55, 0.55, 0.55)
			inner.add_child(_make_label("    • %s  vis=%.2f" % [tracked_id, vis], col))


func _make_label(text: String, col: Color = Color.WHITE) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override(&"font_color", col)
	return lbl
