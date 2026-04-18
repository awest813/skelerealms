class_name SKMenuShell
extends Control
## Abstract base for the game menu system.
## Manages tab/page switching for full-screen menus (pause, inventory,
## journal, map, character) and popup menus (dialogue, barter, crafting).
##
## Subclass to provide concrete layout. Use [method register_page] and
## [method register_popup] to wire up menu sections.


## Emitted when a tab/page is switched.
signal page_changed(page_name:StringName)
## Emitted when a popup is opened.
signal popup_opened(popup_name:StringName)
## Emitted when a popup is closed.
signal popup_closed(popup_name:StringName)


## Registered pages by name.
var _pages:Dictionary = {}
## Currently visible page name.
var _current_page:StringName = &""
## Registered popups by name.
var _popups:Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Register a page (tab) in the menu shell.
func register_page(page_name:StringName, page:Control) -> void:
	_pages[page_name] = page
	page.visible = false


## Switch to a page by name. Hides the current page.
func switch_page(page_name:StringName) -> void:
	if not _pages.has(page_name):
		push_warning("SKMenuShell: page '%s' not registered." % page_name)
		return
	if not _current_page.is_empty() and _pages.has(_current_page):
		_pages[_current_page].visible = false
	_current_page = page_name
	_pages[page_name].visible = true
	page_changed.emit(page_name)


## Register a popup menu (dialogue, barter, crafting, etc.).
func register_popup(popup_name:StringName, popup:Control) -> void:
	_popups[popup_name] = popup
	popup.visible = false


## Show a popup by name.
func show_popup(popup_name:StringName) -> void:
	if not _popups.has(popup_name):
		push_warning("SKMenuShell: popup '%s' not registered." % popup_name)
		return
	_popups[popup_name].visible = true
	popup_opened.emit(popup_name)


## Hide a popup by name.
func hide_popup(popup_name:StringName) -> void:
	if not _popups.has(popup_name):
		return
	_popups[popup_name].visible = false
	popup_closed.emit(popup_name)


## Get the currently active page name.
func get_current_page() -> StringName:
	return _current_page


## Get a registered page control by name.
func get_page(page_name:StringName) -> Control:
	return _pages.get(page_name)


## Get a registered popup control by name.
func get_popup(popup_name:StringName) -> Control:
	return _popups.get(popup_name)
