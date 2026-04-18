class_name SKUIManager
extends Node
## Manages the game UI layer stack, input routing between game and menu
## modes, and pause integration with [GameInfo].
##
## Register as an autoload singleton. The consuming project provides
## concrete HUD and menu scenes; this manager handles layering, visibility,
## and input mode switching.


## UI layers in render order (back to front).
enum Layer {
	HUD,     ## Always-visible gameplay overlay.
	MENU,    ## Full-screen menu (pause, inventory, journal, etc.).
	OVERLAY, ## Top-level overlays (tooltips, notifications, prompts).
}

## Emitted when the HUD is shown or hidden.
signal hud_shown
signal hud_hidden
## Emitted when a menu is opened or closed, with its name.
signal menu_opened(menu_name:StringName)
signal menu_closed(menu_name:StringName)

## The active [SKTheme] applied to all managed UI.
@export var theme_resource:SKTheme

## The HUD shell scene instance.
var _hud:SKHUDShell
## Stack of open menus (most recent on top).
var _menu_stack:Array[Control] = []
## Name-to-menu mapping for quick lookup.
var _menus:Dictionary[StringName, Control] = {}

## Layer containers.
var _hud_layer:CanvasLayer
var _menu_layer:CanvasLayer
var _overlay_layer:CanvasLayer


func _ready() -> void:
	name = "SKUIManager"
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create layer containers
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	_hud_layer.name = "HUDLayer"
	add_child(_hud_layer)

	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 20
	_menu_layer.name = "MenuLayer"
	add_child(_menu_layer)

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 30
	_overlay_layer.name = "OverlayLayer"
	add_child(_overlay_layer)


## Set the HUD shell instance. Called by the consuming project during setup.
func set_hud(hud:SKHUDShell) -> void:
	if _hud:
		_hud_layer.remove_child(_hud)
	_hud = hud
	_hud_layer.add_child(hud)
	if theme_resource and theme_resource.base_theme:
		hud.theme = theme_resource.base_theme


## Register a menu by name. The menu must extend [Control].
func register_menu(menu_name:StringName, menu:Control) -> void:
	_menus[menu_name] = menu
	_menu_layer.add_child(menu)
	menu.visible = false
	if theme_resource and theme_resource.base_theme:
		menu.theme = theme_resource.base_theme


## Open a menu by name. Pushes it onto the stack and pauses the game.
func open_menu(menu_name:StringName) -> void:
	if not _menus.has(menu_name):
		push_warning("SKUIManager: menu '%s' not registered." % menu_name)
		return
	var menu:Control = _menus[menu_name]
	if menu.visible:
		return

	menu.visible = true
	_menu_stack.push_back(menu)

	# Pause game when first menu opens
	if _menu_stack.size() == 1:
		_enter_menu_mode()

	menu_opened.emit(menu_name)


## Close a menu by name. Pops it from the stack; unpauses if stack is empty.
func close_menu(menu_name:StringName) -> void:
	if not _menus.has(menu_name):
		return
	var menu:Control = _menus[menu_name]
	if not menu.visible:
		return

	menu.visible = false
	_menu_stack.erase(menu)

	# Unpause when all menus close
	if _menu_stack.is_empty():
		_exit_menu_mode()

	menu_closed.emit(menu_name)


## Close the topmost menu on the stack.
func close_top_menu() -> void:
	if _menu_stack.is_empty():
		return
	var top:Control = _menu_stack.back()
	# Find its name
	for menu_name in _menus:
		if _menus[menu_name] == top:
			close_menu(menu_name)
			return


## Close all open menus.
func close_all_menus() -> void:
	while not _menu_stack.is_empty():
		close_top_menu()


## Whether any menu is currently open.
func is_menu_open() -> bool:
	return not _menu_stack.is_empty()


## Show the HUD.
func show_hud() -> void:
	if _hud:
		_hud.visible = true
		hud_shown.emit()


## Hide the HUD.
func hide_hud() -> void:
	if _hud:
		_hud.visible = false
		hud_hidden.emit()


## Add a control to the overlay layer (tooltips, notifications).
func add_overlay(control:Control) -> void:
	_overlay_layer.add_child(control)
	if theme_resource and theme_resource.base_theme:
		control.theme = theme_resource.base_theme


## Remove a control from the overlay layer.
func remove_overlay(control:Control) -> void:
	if control.get_parent() == _overlay_layer:
		_overlay_layer.remove_child(control)


func _enter_menu_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameInfo.pause_game(true)  # silent pause — UI handles its own input


func _exit_menu_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameInfo.unpause_game()
