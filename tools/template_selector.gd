@tool
extends PanelContainer


const FILE_INHERIT = 1

@onready var option_button: OptionButton = $VBoxContainer/HBoxContainer/OptionButton
@onready var file_dialog: FileDialog = $FileDialog

var editing:SKWorldEntity


# life will be pain until this gets merged https://github.com/godotengine/godot/pull/90057


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var templates:PackedStringArray = ProjectSettings.get_setting("skelerealms/entity_archetypes", PackedStringArray())
	option_button.clear()
	for t:String in templates:
		option_button.add_item(t)


func edit(what:SKWorldEntity) -> void:
	editing = what


func _on_button_pressed() -> void:
	if option_button.item_count == 0:
		push_error("TemplateSelector: no entity archetypes configured (skelerealms/entity_archetypes).")
		return
	file_dialog.popup_centered()


func _grab_uid(path:String) -> String:
	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		push_warning("TemplateSelector: '%s' has no registered UID; writing scene without ext_resource uid." % path)
		return ""
	return ResourceUID.id_to_text(uid)


func _generate_inherited_scene_id() -> String:
	return "1_%s" % SKIDGenerator.generate_id(5).to_lower()


func _format_scene(from:String, entity_name:String) -> String:
	var id:String = _generate_inherited_scene_id()
	var uid:String = ResourceUID.id_to_text(ResourceUID.create_id())
	var from_uid := _grab_uid(from)
	var ext_line := "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"%s\"]" % [from, id]
	if not from_uid.is_empty():
		ext_line = "[ext_resource type=\"PackedScene\" uid=\"%s\" path=\"%s\" id=\"%s\"]" % [from_uid, from, id]
	return """
[gd_scene load_steps=2 format=3 uid=\"%s\"]

%s

[node name=\"%s\" instance=ExtResource(\"%s\")]
""" % [
	uid,
	ext_line,
	entity_name,
	id
]


func _on_file_dialog_file_selected(path: String) -> void:
	_make_manually(path)


func _make_manually(path:String) -> void:
	if editing == null:
		push_error("TemplateSelector: no world entity is being edited.")
		return
	var p:String = option_button.get_item_text(option_button.selected)
	# Name the instance after the destination file, not a hardcoded placeholder.
	var entity_name := path.get_file().get_basename().to_pascal_case()
	if entity_name.is_empty():
		entity_name = "NewEntity"
	var contents:String = _format_scene(p, entity_name)
	var fh := FileAccess.open(path, FileAccess.WRITE)
	if fh == null:
		push_error("TemplateSelector: Failed to open '%s' for writing: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	fh.store_string(contents)
	fh.close()
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.get_resource_filesystem().update_file(path)
	EditorInterface.get_resource_previewer().queue_resource_preview(path, self, &"receive_thumbnail", null)
	editing.entity = ResourceLoader.load(path)


func _create_using_editor() -> void:
	EditorInterface.get_file_system_dock().navigate_to_path(option_button.get_item_text(option_button.selected))
	
	var popup:PopupMenu = EditorInterface.get_file_system_dock().get_children()\
		.filter(func(n:Node)->bool:return n is PopupMenu)\
		.filter(func(p:PopupMenu) -> bool: return p.item_count > 0)\
		.filter(func(p:PopupMenu) -> bool: return p.get_item_text(0) == "Open Scene")\
		[0]
	
	if popup:
		popup.id_pressed.emit(FILE_INHERIT)


func _create_using_instantiation(path:String) -> void:
	var p:String = option_button.get_item_text(option_button.selected)
	var new_scene:Node = (ResourceLoader.load(p) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	new_scene.scene_file_path = p
	var new_ps := PackedScene.new()
	new_ps.pack(new_scene)
	ResourceSaver.save(new_ps, path)


func receive_thumbnail(_path:String, _preview:Texture2D, _thumbnail_preview:Texture2D, _userdata:Variant) -> void:
	return
