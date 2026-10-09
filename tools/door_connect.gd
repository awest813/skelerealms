extends EditorInspectorPlugin


const NODE_3D_VIEWPORT_CLASS_NAME = "Node3DEditorViewport"

var p:EditorPlugin
var _viewports:Array[Node] = []
var _cams:Array[Camera3D] = []


func _can_handle(object:Object) -> bool:
	return object is Door


func _parse_begin(obj:Object) -> void:
	var go_to_button:Button = Button.new()
	go_to_button.text = "Jump to door location"
	go_to_button.pressed.connect(func(): _jump_to_door_location(obj as Door))
	add_custom_control(go_to_button)
	var set_position_button:Button = Button.new()
	set_position_button.text = "Set position data"
	set_position_button.pressed.connect(func(): _set_position(obj as Door))
	add_custom_control(set_position_button)


func _jump_to_door_location(obj:Door) -> void:
	var path = ProjectSettings.get_setting("skelerealms/worlds_path")
	var res = _find_world(path, obj.destination_instance.world)
	if res == "":
		push_warning("DoorConnect: destination world '%s' not found under '%s'." % [obj.destination_instance.world, path])
		return
	# Workaround from https://github.com/godotengine/godot/issues/75669#issuecomment-1621230016
	p.get_editor_interface().open_scene_from_path.call_deferred(res)
	p.get_editor_interface().edit_resource.call_deferred(load(res)) # switch tab
	p.get_editor_interface().set_main_screen_editor.call_deferred("3D")


func _set_position(obj:Door) -> void:
	obj.instance.position = obj.global_position
	# obj.owner is null when the Door itself is the edited scene root.
	var scene_root := p.get_editor_interface().get_edited_scene_root()
	if scene_root:
		obj.instance.world = scene_root.name
	elif obj.owner:
		obj.instance.world = obj.owner.name
	else:
		obj.instance.world = ""


## Static: pure directory search, no editor state needed (unit-testable).
static func _find_world(path:String, target:String) -> String:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir(): # if is directory, search subdirectory
				# Recurse with the full path — passing the bare name loses
				# the parent directory and breaks subdirectory searches.
				var res = _find_world("%s/%s" % [path, file_name], target)
				if not res == "":
					return res
			else: # if filename, cache filename
				var result = file_name.contains(target)
				if result:
					return "%s/%s" % [path, file_name] 
			file_name = dir.get_next()
		dir.list_dir_end()
	return ""


func _init(plug:EditorPlugin) -> void:
	p = plug
	_populate_data()


func _populate_data() -> void:
	_find_viewports(p.get_editor_interface().get_base_control())
	for v in _viewports:
		_find_cameras(v)


func _find_viewports(n:Node) -> void:
	if n.get_class() == NODE_3D_VIEWPORT_CLASS_NAME:
		_viewports.append(n)
		return
	
	for c in n.get_children():
		_find_viewports(c)


func _find_cameras(n:Node) -> void:
	if n is Camera3D:
		_cams.append(n)
		return
	
	for c in n.get_children():
		_find_cameras(c)
