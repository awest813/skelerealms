class_name SKTabPanel
extends Control
## Contract for a tab panel widget — manages multiple child panels
## with tab switching. Used for menu section navigation.
##
## Subclass and override to provide your styled tab buttons and panels.


## Emitted when the active tab changes.
signal tab_changed(tab_name:StringName)

## Currently active tab name.
var _active_tab:StringName = &""
## Registered tabs: name → Control.
var _tabs:Dictionary[StringName, Control] = {}


## Register a tab with a name and its content panel.
func register_tab(tab_name:StringName, panel:Control) -> void:
	_tabs[tab_name] = panel
	panel.visible = false


## Switch to a tab by name.
func switch_tab(tab_name:StringName) -> void:
	if not _tabs.has(tab_name):
		return
	if not _active_tab.is_empty() and _tabs.has(_active_tab):
		_tabs[_active_tab].visible = false
	_active_tab = tab_name
	_tabs[tab_name].visible = true
	tab_changed.emit(tab_name)


## Get the currently active tab name.
func get_active_tab() -> StringName:
	return _active_tab
