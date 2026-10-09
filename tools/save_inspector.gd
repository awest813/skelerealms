@tool
class_name SaveInspector
extends VBoxContainer
## Editor tool that opens, parses, and inspects SkeleRealms save files (.dat).
## Shows the full JSON contents as a browsable [Tree], reports the schema version,
## checksum validity, entity count, and other top-level stats.
## [br]
## Opened via the "Save Inspector" tab in the Godot bottom panel
## (added automatically when the SkeleRealms plugin is enabled).


var _path_field: LineEdit
var _status_label: Label
var _tree: Tree
var _file_dialog: FileDialog


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# ── Toolbar ──
	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	var path_lbl := Label.new()
	path_lbl.text = "Save file: "
	toolbar.add_child(path_lbl)

	_path_field = LineEdit.new()
	_path_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_field.placeholder_text = "user://saves/slot_1.dat"
	toolbar.add_child(_path_field)

	var browse_btn := Button.new()
	browse_btn.text = "Browse…"
	browse_btn.pressed.connect(_on_browse)
	toolbar.add_child(browse_btn)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_on_load)
	toolbar.add_child(load_btn)

	var latest_btn := Button.new()
	latest_btn.text = "Latest"
	latest_btn.tooltip_text = "Load the most recently modified save in user://saves/."
	latest_btn.pressed.connect(_on_load_latest)
	toolbar.add_child(latest_btn)

	# ── Status bar ──
	_status_label = Label.new()
	_status_label.text = "No file loaded."
	add_child(_status_label)

	add_child(HSeparator.new())

	# ── Tree view ──
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.columns = 2
	_tree.set_column_title(0, "Key / Index")
	_tree.set_column_title(1, "Value")
	_tree.set_column_titles_visible(true)
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, true)
	add_child(_tree)

	# ── File dialog ──
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.dat ; SkeleRealms Save Files", "* ; All Files"])
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_selected.connect(func(path: String) -> void:
		_path_field.text = path
		_on_load()
	)
	add_child(_file_dialog)


func _on_browse() -> void:
	# Open in the user saves folder when it exists.
	var saves_dir := OS.get_user_data_dir().path_join("saves")
	if DirAccess.dir_exists_absolute(saves_dir):
		_file_dialog.current_dir = saves_dir
	else:
		_file_dialog.current_dir = OS.get_user_data_dir()
	_file_dialog.popup_centered(Vector2i(900, 600))


func _on_load_latest() -> void:
	var saves_dir := OS.get_user_data_dir().path_join("saves")
	var latest := find_latest_save(saves_dir)
	if latest.is_empty():
		_set_status("No save files found in user://saves/.", Color(1.0, 0.6, 0.2))
		return
	_path_field.text = "user://saves/%s" % latest
	_on_load()


## File name (not path) of the most recently modified .dat save in a
## directory, or "" when there are none. Static so tests can drive it
## against throwaway directories.
static func find_latest_save(dir_path: String) -> String:
	if not DirAccess.dir_exists_absolute(dir_path):
		return ""
	var latest := ""
	var latest_mtime := 0
	for file_name in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".dat"):
			continue
		var modified := FileAccess.get_modified_time(dir_path.path_join(file_name))
		if latest.is_empty() or modified > latest_mtime:
			latest = file_name
			latest_mtime = modified
	return latest


func _on_load() -> void:
	var raw_path: String = _path_field.text.strip_edges()
	if raw_path.is_empty():
		_set_status("No file path entered.", Color(1.0, 0.5, 0.3))
		return

	# Resolve virtual paths to absolute paths.
	var abs_path: String = raw_path
	if raw_path.begins_with("user://"):
		abs_path = OS.get_user_data_dir().path_join(raw_path.trim_prefix("user://"))
	elif raw_path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(raw_path)

	if not FileAccess.file_exists(abs_path):
		_set_status("File not found: %s" % abs_path, Color(1.0, 0.3, 0.3))
		return

	var file := FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		_set_status("Could not open: %s" % abs_path, Color(1.0, 0.3, 0.3))
		return

	var raw_text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		_set_status("Failed to parse JSON from: %s" % abs_path, Color(1.0, 0.3, 0.3))
		return

	_inspect(parsed as Dictionary, raw_text, abs_path)


func _inspect(data: Dictionary, raw_text: String, path: String) -> void:
	_tree.clear()
	var root: TreeItem = _tree.create_item()

	var schema_ver: int = data.get("schema_version", -1)
	var checksum_ok: bool = _verify_checksum(data, raw_text)
	var entity_count: int = (data.get("entity_data", {}) as Dictionary).size()
	var game_info_keys: int = (data.get("game_info", {}) as Dictionary).size()
	var other_keys: int = (data.get("other_data", {}) as Dictionary).size()

	var parts: Array[String] = [
		"%s" % path.get_file(),
		"Schema v%d" % schema_ver,
		"Entities: %d" % entity_count,
		"GameInfo keys: %d" % game_info_keys,
		"Other keys: %d" % other_keys,
		"Checksum: %s" % ("✓ valid" if checksum_ok else "✗ MISMATCH"),
	]
	_set_status("  |  ".join(parts), Color(0.3, 1.0, 0.4) if checksum_ok else Color(1.0, 0.6, 0.2))

	_populate_tree(root, data)


## Returns true if the embedded checksum matches a freshly-computed one,
## or true when no checksum field is present (old format).
## The indent must mirror SaveSystem._serialize exactly, including the
## skelerealms/savegame_indents setting — a hardcoded "\t" reported a
## permanent MISMATCH for projects that save without indentation.
func _verify_checksum(data: Dictionary, _raw_text: String) -> bool:
	if not data.has("checksum"):
		return true
	var stored: String = data["checksum"]
	var check_data: Dictionary = data.duplicate(true)
	check_data.erase("checksum")
	var indent := "\t" if ProjectSettings.get_setting("skelerealms/savegame_indents", true) else ""
	var recalc: String = _compute_checksum(
		JSON.stringify(check_data, indent, true, true)
	)
	return recalc == stored


## FNV-1a 32-bit checksum — mirrors the algorithm in SaveSystem.
func _compute_checksum(text: String) -> String:
	var h: int = 0x811c9dc5
	for i in range(text.length()):
		h = h ^ text.unicode_at(i)
		h = (h * 0x01000193) & 0xFFFFFFFF
	return "%08x" % h


func _populate_tree(parent_item: TreeItem, value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var child: TreeItem = _tree.create_item(parent_item)
			child.set_text(0, str(key))
			var child_val: Variant = value[key]
			if child_val is Dictionary or child_val is Array:
				child.set_text(1, _container_size_text(child_val))
				child.collapsed = true
				_populate_tree(child, child_val)
			else:
				child.set_text(1, str(child_val))
	elif value is Array:
		for i in range((value as Array).size()):
			var child: TreeItem = _tree.create_item(parent_item)
			child.set_text(0, "[%d]" % i)
			var child_val: Variant = (value as Array)[i]
			if child_val is Dictionary or child_val is Array:
				child.set_text(1, _container_size_text(child_val))
				child.collapsed = true
				_populate_tree(child, child_val)
			else:
				child.set_text(1, str(child_val))


## Returns a human-readable size description for a Dictionary or Array.
func _container_size_text(val: Variant) -> String:
	if val is Array:
		return "(%d items)" % (val as Array).size()
	return "(%d keys)" % (val as Dictionary).size()


func _set_status(text: String, col: Color = Color.WHITE) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override(&"font_color", col)
