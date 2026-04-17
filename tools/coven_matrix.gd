@tool
extends Control
## Editor tool showing a grid of all inter-coven opinion values.
##
## Rows are the "subject" coven (whose opinion we read), columns are the "object" coven.
## Each cell shows a [SpinBox] for the opinion score and is colour-coded by disposition:
##   red = hostile, white/gray = neutral, green = friendly, blue = allied.
## Diagonal cells (self-opinion) are disabled.
##
## Opened by the [CovenMatrixPlugin] inspector plugin.
## All [Coven] resources are loaded from the [code]skelerealms/covens_path[/code] project setting.


var _covens: Array[Coven] = []
var _grid: GridContainer
var _status_lbl: Label


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
	title_lbl.text = "  Coven Relationship Matrix"
	toolbar.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var refresh_btn := Button.new()
	refresh_btn.text = "↺ Reload Covens"
	refresh_btn.pressed.connect(refresh)
	toolbar.add_child(refresh_btn)

	var save_btn := Button.new()
	save_btn.text = "Save All Covens"
	save_btn.pressed.connect(_save_all)
	toolbar.add_child(save_btn)

	_status_lbl = Label.new()
	_status_lbl.text = ""
	_status_lbl.add_theme_color_override(&"font_color", Color(0.7, 0.9, 0.7))
	toolbar.add_child(_status_lbl)

	# ── Legend ──
	var legend := HBoxContainer.new()
	vbox.add_child(legend)
	for pair: Array in [
		["hostile", Color(1.0, 0.4, 0.4, 0.3)],
		["neutral", Color(0.8, 0.8, 0.8, 0.15)],
		["friendly", Color(0.4, 1.0, 0.5, 0.3)],
		["allied", Color(0.4, 0.7, 1.0, 0.3)],
	]:
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(14, 14)
		sw.color = pair[1]
		legend.add_child(sw)
		var lbl := Label.new()
		lbl.text = " %s  " % pair[0]
		legend.add_child(lbl)

	# ── Scrollable grid ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	scroll.add_child(_grid)

	refresh()


## Reload all covens and rebuild the matrix.
func refresh() -> void:
	_load_covens()
	_rebuild_grid()


func _load_covens() -> void:
	_covens.clear()
	var path: String = ProjectSettings.get_setting("skelerealms/covens_path", "res://covens")
	_scan_dir(path)


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := "%s/%s" % [path, name]
		if dir.current_is_dir():
			_scan_dir(full)
		else:
			var load_path := full.trim_suffix(".remap")
			if load_path.ends_with(".tres") or load_path.ends_with(".res"):
				var res := load(load_path)
				if res is Coven:
					_covens.append(res as Coven)
		name = dir.get_next()
	dir.list_dir_end()


func _rebuild_grid() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	if _covens.is_empty():
		_grid.columns = 1
		var lbl := Label.new()
		lbl.text = "No covens found in '%s'." % ProjectSettings.get_setting("skelerealms/covens_path", "res://covens")
		_grid.add_child(lbl)
		return

	var n := _covens.size()
	_grid.columns = n + 1

	# ── Header row: blank corner + column labels ──
	_grid.add_child(_make_label("", true))
	for col_coven: Coven in _covens:
		var hdr := _make_label(str(col_coven.coven_id), true)
		hdr.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.6))
		_grid.add_child(hdr)

	# ── Data rows ──
	for row_coven: Coven in _covens:
		# Row header
		var row_hdr := _make_label(str(row_coven.coven_id), true)
		row_hdr.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.6))
		_grid.add_child(row_hdr)

		for col_coven: Coven in _covens:
			if row_coven == col_coven:
				# Diagonal: self-opinion — disabled placeholder.
				var diag := Label.new()
				diag.text = " — "
				diag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				diag.custom_minimum_size = Vector2(80, 0)
				_grid.add_child(diag)
			else:
				_grid.add_child(_make_opinion_cell(row_coven, col_coven))


func _make_opinion_cell(subject: Coven, obj: Coven) -> Control:
	var current_opinion: int = subject.other_coven_opinions.get(obj.coven_id, 0)
	var bg := PanelContainer.new()
	bg.custom_minimum_size = Vector2(80, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = _disposition_color(subject, current_opinion)
	bg.add_theme_stylebox_override(&"panel", style)

	var spin := SpinBox.new()
	spin.min_value = -999
	spin.max_value = 999
	spin.value = current_opinion
	spin.value_changed.connect(func(v: float) -> void:
		var iv := int(v)
		subject.other_coven_opinions[obj.coven_id] = iv
		style.bg_color = _disposition_color(subject, iv))
	bg.add_child(spin)

	return bg


func _make_label(text: String, bold: bool) -> Label:
	var lbl := Label.new()
	lbl.text = " %s " % text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(80, 28)
	if bold:
		lbl.add_theme_font_size_override(&"font_size", 12)
	return lbl


func _disposition_color(coven: Coven, opinion: int) -> Color:
	match coven.get_disposition(opinion):
		Coven.Disposition.HOSTILE:
			return Color(1.0, 0.4, 0.4, 0.3)
		Coven.Disposition.FRIENDLY:
			return Color(0.4, 1.0, 0.5, 0.3)
		Coven.Disposition.ALLIED:
			return Color(0.4, 0.7, 1.0, 0.3)
		_:
			return Color(0.8, 0.8, 0.8, 0.15)


func _save_all() -> void:
	var saved := 0
	var skipped := 0
	for coven: Coven in _covens:
		if coven.resource_path.is_empty():
			skipped += 1
			continue
		ResourceSaver.save(coven)
		saved += 1
	EditorInterface.get_resource_filesystem().scan()
	_status_lbl.text = "Saved %d coven(s)%s" % [
		saved,
		(" (%d skipped — no path)" % skipped) if skipped > 0 else "",
	]
