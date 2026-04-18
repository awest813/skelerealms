@tool
extends EditorPlugin


const DoorJumpPlugin = preload("res://addons/skelerealms/tools/door_connect.gd")
const WorldEntityPlugin = preload("res://addons/skelerealms/tools/world_entity_plugin.gd")
const PointGizmo = preload("res://addons/skelerealms/tools/point_gizmo.gd")
const ScheduleEditorPlugin = preload("res://addons/skelerealms/tools/schedule_editor_plugin.gd")
const ConfigSyncPlugin = preload("res://addons/skelerealms/tools/config_sync_plugin.gd")
const EditInWorldButton = preload("res://addons/skelerealms/tools/edit_button.gd")
const QuestEditorPlugin = preload("res://addons/skelerealms/tools/quest_editor_plugin.gd")
const QuestEditor = preload("res://addons/skelerealms/tools/quest_editor.gd")
const DialogueEditorPlugin = preload("res://addons/skelerealms/tools/dialogue_editor_plugin.gd")
const DialogueEditor = preload("res://addons/skelerealms/tools/dialogue_editor.gd")
const CovenMatrixPlugin = preload("res://addons/skelerealms/tools/coven_matrix_plugin.gd")
const CovenMatrix = preload("res://addons/skelerealms/tools/coven_matrix.gd")
const SaveInspector = preload("res://addons/skelerealms/tools/save_inspector.gd")
const PluginMigrationRegistry = preload("res://addons/skelerealms/scripts/system/plugin_migration_registry.gd")

## Plugin version — keep in sync with plugin.cfg.
const PLUGIN_VERSION := "beta 0.8"

## Container we add the toolbar to
const container = CONTAINER_SPATIAL_EDITOR_MENU
const RAY_LENGTH:float = 500
const SNAP_DISTANCE:float = 0.1

## The active [NetworkEditorUtility].
var utility:NetworkEditorUtility
## Gizmo instance for a [NetworkInstance].
var network_gizmo:NetworkGizmo = NetworkGizmo.new()
## Currently editing network.
var target:Network:
	get:
		return target
	set(val):
		if target == val: # Prevent reinitializing a whole lot. may be redundant.
			return
		if target and target.redraw.is_connected(_redraw_gizmo.bind()):
			# unsubscribe from redraw if we are changing selection
			target.redraw.disconnect(_redraw_gizmo.bind())
		target = val
		if target:
			target.redraw.connect(_redraw_gizmo.bind()) # subscribe to redraw
		_set_toolbar_visibility(not val == null) # set toolbar visibility to true if it isnt null
var _target_node:NetworkInstance


var door_jump_plugin := DoorJumpPlugin.new(self)
var we_plugin := WorldEntityPlugin.new()
var point_gizmo := PointGizmo.new()
var se_plugin := ScheduleEditorPlugin.new()
var cs_plugin := ConfigSyncPlugin.new()
var edit_button := EditInWorldButton.new()
var quest_editor_plugin := QuestEditorPlugin.new()
var dialogue_editor_plugin := DialogueEditorPlugin.new()
var coven_matrix_plugin := CovenMatrixPlugin.new()

var se_w: Window
var se: Control
var _quest_editor_w: Window
var _quest_editor: Control
var _dialogue_editor_w: Window
var _dialogue_editor: Control
var _coven_matrix_w: Window
var _coven_matrix: Control
var _save_inspector: Control


func _enter_tree():
	# Run pending project-level migrations before any other plugin setup so
	# autoloads and inspector plugins see the already-upgraded ProjectSettings.
	_run_plugin_migrations()
	# gizmos
	add_node_3d_gizmo_plugin(point_gizmo)
	add_inspector_plugin(door_jump_plugin)
	add_inspector_plugin(we_plugin)
	add_inspector_plugin(se_plugin)
	add_inspector_plugin(cs_plugin)
	add_inspector_plugin(quest_editor_plugin)
	add_inspector_plugin(dialogue_editor_plugin)
	add_inspector_plugin(coven_matrix_plugin)
	# autoload
	add_autoload_singleton("SkeleRealmsGlobal", "res://addons/skelerealms/scripts/sk_global.gd")
	add_autoload_singleton("CovenSystem", "res://addons/skelerealms/scripts/covens/coven_system.gd")
	add_autoload_singleton("GameInfo", "res://addons/skelerealms/scripts/system/game_info.gd")
	add_autoload_singleton("SaveSystem", "res://addons/skelerealms/scripts/system/save_system.gd")
	add_autoload_singleton("CrimeMaster", "res://addons/skelerealms/scripts/crime/crime_master.gd")
	add_autoload_singleton("DeviceNetwork", "res://addons/skelerealms/scripts/misc/device_network.gd")
	add_autoload_singleton("QuestSystem", "res://addons/skelerealms/scripts/quests/quest_system.gd")
	add_autoload_singleton("DialogueSystem", "res://addons/skelerealms/scripts/dialogue/dialogue_system.gd")
	add_autoload_singleton("SpawnTrackerManager", "res://addons/skelerealms/scripts/system/spawn_tracker_manager.gd")
	add_autoload_singleton("ModLoader", "res://addons/skelerealms/scripts/mods/mod_loader.gd")
	add_autoload_singleton("SKUIManager", "res://addons/skelerealms/scripts/ui/ui_manager.gd")
	
	se_w = Window.new()
	se = ScheduleEditorPlugin.ScheduleEditor.instantiate()
	se_w.add_child(se)
	EditorInterface.get_base_control().add_child(se_w)
	se_w.hide()
	
	se_plugin.request_open.connect(func(events: Array[ScheduleEvent]) -> void:
		se.edit(events)
		se_w.popup_centered(Vector2i(1920, 1080))
		)

	# Quest editor window
	_quest_editor_w = Window.new()
	_quest_editor_w.title = "Quest Graph Editor"
	_quest_editor_w.close_requested.connect(_quest_editor_w.hide)
	_quest_editor = QuestEditor.new()
	_quest_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quest_editor_w.add_child(_quest_editor)
	EditorInterface.get_base_control().add_child(_quest_editor_w)
	_quest_editor_w.hide()

	quest_editor_plugin.request_open.connect(func(definition: QuestDefinition) -> void:
		_quest_editor.edit(definition)
		_quest_editor_w.title = "Quest Graph Editor — %s" % str(definition.id)
		_quest_editor_w.popup_centered(Vector2i(1200, 800))
		)

	# Dialogue editor window
	_dialogue_editor_w = Window.new()
	_dialogue_editor_w.title = "Dialogue Tree Editor"
	_dialogue_editor_w.close_requested.connect(_dialogue_editor_w.hide)
	_dialogue_editor = DialogueEditor.new()
	_dialogue_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_editor_w.add_child(_dialogue_editor)
	EditorInterface.get_base_control().add_child(_dialogue_editor_w)
	_dialogue_editor_w.hide()

	dialogue_editor_plugin.request_open.connect(func(definition: DialogueDefinition) -> void:
		_dialogue_editor.edit(definition)
		_dialogue_editor_w.title = "Dialogue Tree Editor — %s" % str(definition.id)
		_dialogue_editor_w.popup_centered(Vector2i(1400, 900))
		)

	# Coven matrix window
	_coven_matrix_w = Window.new()
	_coven_matrix_w.title = "Coven Relationship Matrix"
	_coven_matrix_w.close_requested.connect(_coven_matrix_w.hide)
	_coven_matrix = CovenMatrix.new()
	_coven_matrix.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_coven_matrix_w.add_child(_coven_matrix)
	EditorInterface.get_base_control().add_child(_coven_matrix_w)
	_coven_matrix_w.hide()

	coven_matrix_plugin.request_open.connect(func() -> void:
		(_coven_matrix as CovenMatrix).refresh()
		_coven_matrix_w.popup_centered(Vector2i(1100, 700))
		)

	# Save inspector bottom panel
	_save_inspector = SaveInspector.new()
	_save_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_control_to_bottom_panel(_save_inspector, "Save Inspector")
	
	# Initialize utility
	utility = load("res://addons/skelerealms/scripts/network/Editor/editor_toolbar.tscn").instantiate()
	add_control_to_container(container, utility) # add to spatial toolbar
	_set_toolbar_visibility(false) # hide by default
	# Connect the buttons
	utility.link.connect(_on_link.bind())
	utility.merge.connect(_on_merge.bind())
	utility.remove.connect(_on_remove.bind())
	utility.dissolve.connect(_on_dissolve.bind())
	utility.subdivide.connect(_on_subdivide.bind())
	utility.unlink.connect(_on_unlink.bind())
	utility.change_cost_accepted.connect(_change_cost.bind())

	# Selection
	get_editor_interface()\
		.get_selection()\
		.selection_changed\
		.connect(_selection_changed.bind())
	
	# Gizmo
	network_gizmo._plugin = self
	add_node_3d_gizmo_plugin(network_gizmo)
	
	# Edit button
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, edit_button)


func _exit_tree():
	# gizmos
	remove_node_3d_gizmo_plugin(point_gizmo)
	remove_inspector_plugin(door_jump_plugin)
	remove_inspector_plugin(we_plugin)
	remove_inspector_plugin(se_plugin)
	remove_inspector_plugin(cs_plugin)
	remove_inspector_plugin(quest_editor_plugin)
	remove_inspector_plugin(dialogue_editor_plugin)
	remove_inspector_plugin(coven_matrix_plugin)
	# autoload
	remove_autoload_singleton("SkeleRealmsGlobal")
	remove_autoload_singleton("CovenSystem")
	remove_autoload_singleton("GameInfo")
	remove_autoload_singleton("SaveSystem")
	remove_autoload_singleton("CrimeMaster")
	remove_autoload_singleton("DeviceNetwork")
	remove_autoload_singleton("QuestSystem")
	remove_autoload_singleton("DialogueSystem")
	remove_autoload_singleton("SpawnTrackerManager")
	remove_autoload_singleton("ModLoader")
	remove_autoload_singleton("SKUIManager")

	remove_control_from_container(container, utility)
	remove_node_3d_gizmo_plugin(network_gizmo)
	
	se_w.queue_free()
	_quest_editor_w.queue_free()
	_dialogue_editor_w.queue_free()
	_coven_matrix_w.queue_free()

	remove_control_from_bottom_panel(_save_inspector)
	_save_inspector.queue_free()

	edit_button.queue_free()


func _enable_plugin() -> void:
	# settings
	ProjectSettings.set_setting("skelerealms/actor_fade_distance", 100.0)
	ProjectSettings.set_setting("skelerealms/entity_cleanup_timer", 300.0)
	ProjectSettings.set_setting("skelerealms/granular_navigation_sim_distance", 1000.0)
	ProjectSettings.set_setting("skelerealms/savegame_indents", true)
	
	ProjectSettings.set_setting("skelerealms/seconds_per_minute", 2.0)
	ProjectSettings.set_setting("skelerealms/minutes_per_hour", 31.0)
	ProjectSettings.set_setting("skelerealms/hours_per_day", 15.0)
	ProjectSettings.set_setting("skelerealms/days_per_week", 8)
	ProjectSettings.set_setting("skelerealms/weeks_in_month", 4)
	ProjectSettings.set_setting("skelerealms/months_in_year", 8)
	
	ProjectSettings.set_setting("skelerealms/worlds_path", "res://worlds")
	ProjectSettings.set_setting("skelerealms/entities_path", "res://entities")
	ProjectSettings.set_setting("skelerealms/covens_path", "res://covens")
	ProjectSettings.set_setting("skelerealms/doors_path", "res://doors")
	ProjectSettings.set_setting("skelerealms/networks_path", "res://networks")
	
	ProjectSettings.set_setting("skelerealms/config_path", "res://sk_config.res")
	
	ProjectSettings.set_setting("skelerealms/mods_path", "res://mods")
	
	ProjectSettings.set_setting("skelerealms/entity_archetypes", PackedStringArray([
		"res://addons/skelerealms/npc_entity_template.tscn",
		"res://addons/skelerealms/item_entity_template.tscn"
	]))


func _disable_plugin() -> void:
	# settings
	ProjectSettings.set_setting("skelerealms/actor_fade_distance", null)
	ProjectSettings.set_setting("skelerealms/entity_cleanup_timer", null)
	ProjectSettings.set_setting("skelerealms/granular_navigation_sim_distance", null)
	ProjectSettings.set_setting("skelerealms/savegame_indents", null)
	
	ProjectSettings.set_setting("skelerealms/seconds_per_minute", null)
	ProjectSettings.set_setting("skelerealms/minutes_per_hour", null)
	ProjectSettings.set_setting("skelerealms/hours_per_day", null)
	ProjectSettings.set_setting("skelerealms/days_per_week", null)
	ProjectSettings.set_setting("skelerealms/weeks_in_month", null)
	ProjectSettings.set_setting("skelerealms/months_in_year", null)
	
	ProjectSettings.set_setting("skelerealms/worlds_path", null)
	ProjectSettings.set_setting("skelerealms/entities_path", null)
	ProjectSettings.set_setting("skelerealms/covens_path", null)
	ProjectSettings.set_setting("skelerealms/doors_path", null)
	ProjectSettings.set_setting("skelerealms/networks_path", null)
	
	ProjectSettings.set_setting("skelerealms/entity_archetypes", null)
	ProjectSettings.set_setting("skelerealms/config_path", null)
	ProjectSettings.set_setting("skelerealms/mods_path", null)


## Run one-shot plugin-version migrations. Operates on ProjectSettings keys
## and other project-level state that persists across editor sessions.
##
## Each migration is keyed by the FROM-version; it executes when the installed
## version equals that key, then the installed version advances one step.
## See `docs/architecture/migration_tooling.md` for the contract.
func _run_plugin_migrations() -> void:
	var registry := PluginMigrationRegistry.new(PLUGIN_VERSION)

	# beta 0.7 → beta 0.8: no project-level schema changes. The stub below
	# exists so future migrations have a reference pattern.
	registry.register("beta 0.7", func() -> void:
		# No-op — Phase 8 (debug overlays) and Phase 9 (architecture docs)
		# did not change ProjectSettings keys or resource schemas.
		pass)

	registry.run()


func _handles(object: Object) -> bool:
	return object is NetworkInstance


func _selection_changed() -> void:
	# Get selected nodes
	var selections = get_editor_interface()\
							.get_selection()\
							.get_selected_nodes()
	# Skip if no selections 
	if selections.is_empty():
		target = null
		return
	# Set target if network instance
	if selections[0] is NetworkInstance:
		_target_node = selections[0]
		target = selections[0].network
		return
	target = null


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	# if no utility, pass
	if not utility:
		return AFTER_GUI_INPUT_PASS
	# if no target, pass
	if target == null:
		return AFTER_GUI_INPUT_PASS
	# if not in add mode, pass
	if not utility.add_mode:
		return AFTER_GUI_INPUT_PASS
	# pass if event isn't a mouse button
	if not event is InputEventMouseButton:
		return AFTER_GUI_INPUT_PASS
	# pass if not mouse right click down
	if not (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT or \
		not (event as InputEventMouseButton).pressed:
			return AFTER_GUI_INPUT_PASS
	# If we passed all failure conditions, we block and add point
	_on_add_point(viewport_camera, event)
	return AFTER_GUI_INPUT_STOP


func _set_toolbar_visibility(state:bool) -> void:
	if utility:
		if state:
			utility.show()
		else:
			utility.hide()


func _on_dissolve() -> void:
	if target and network_gizmo.last_modified:
		# dissolve selected point
		target.dissolve_point(network_gizmo.last_modified)

		network_gizmo.last_modified = null
		network_gizmo.second_last_modified = null


func _on_remove() -> void:
	if target and network_gizmo.last_modified:
		# remove selected point
		target.remove_point(network_gizmo.last_modified)

		network_gizmo.last_modified = null
		network_gizmo.second_last_modified = null


func _on_merge() -> void:
	if target and network_gizmo.last_modified and network_gizmo.second_last_modified:
		# Merge the last two selected points
		target.merge_points(network_gizmo.last_modified, network_gizmo.second_last_modified)

		network_gizmo.last_modified = null
		network_gizmo.second_last_modified = null


func _on_link() -> void:
	if target and network_gizmo.last_modified and network_gizmo.second_last_modified:
		# Add an edge between the two last selected points
		target.add_edge(network_gizmo.last_modified, network_gizmo.second_last_modified)


func _on_subdivide() -> void:
	if target and network_gizmo.last_modified and network_gizmo.second_last_modified:
		var edge = target.find_edge(network_gizmo.last_modified, network_gizmo.second_last_modified)
		if edge:
			var middle_node = target.subdivide_edge(edge)
			network_gizmo.last_modified = middle_node


func _on_unlink() -> void:
	if target and network_gizmo.last_modified and network_gizmo.second_last_modified:
		var edge = target.find_edge(network_gizmo.last_modified, network_gizmo.second_last_modified)
		if edge:
			target.remove_edge(edge)


func _on_add_point(camera: Camera3D, event: InputEventMouseButton) -> void:
	_add_point(camera, event.position, utility.portal_mode)


## Add or link nodes.
func _add_point(camera: Camera3D, position:Vector2, portal:bool = false) -> void:
	# return if no target
	if not _target_node:
		return
	var hit_pos:Vector3

	# Step 1: find hit point
	var from = camera.project_ray_origin(position)
	var to = from + (camera.project_ray_normal(position) * RAY_LENGTH)
	var ray = PhysicsRayQueryParameters3D.create(from, to)
	# wait for physics
	await _target_node.get_tree().physics_frame
	var hits = _target_node.get_world_3d().direct_space_state.intersect_ray(ray)
	if hits:
		hit_pos = hits["position"]
	else:
		return
	
	# Step 2: determine if linking to anything else
	var linking:bool = false
	var link_target:NetworkPoint
	var candidates = target.points.filter(func(x:NetworkPoint): return hit_pos.distance_to(x.position) <= SNAP_DISTANCE) # Get all points within distance
	candidates.sort_custom(func(a:NetworkPoint, b:NetworkPoint): return hit_pos.distance_to(a.position) < hit_pos.distance_to(b.position)) # sort by distance
	# if we have candidates, grab closest one
	if not candidates.is_empty():
		linking = true
		link_target = candidates[0]
	
	# Step 3: perform link or add
	if linking: # we are linking
		target.add_edge(link_target, network_gizmo.last_modified) # add between last selected and this one
		network_gizmo.last_modified = link_target # set last modified to link target for easier chaining
	else: # add new node
		var new_pt = target.add_point(hit_pos, portal)
		# if there is something to link, try linking
		if network_gizmo.last_modified:
			target.add_edge(new_pt, network_gizmo.last_modified)
		
		network_gizmo.last_modified = new_pt # set last modified so we can chain
	
	utility.reset_portal_mode()


func _change_cost(text:String) -> void:
	if target and network_gizmo.last_modified and network_gizmo.second_last_modified:
		var edge = target.find_edge(network_gizmo.last_modified, network_gizmo.second_last_modified)
		if edge:
			edge.cost = text.to_float()
			return
	
	push_warning("must select two connected nodes")


func _redraw_gizmo():
	if _target_node:
		_target_node.update_gizmos()
