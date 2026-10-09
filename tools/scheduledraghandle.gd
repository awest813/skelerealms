@tool
extends Control


var dragging:bool
var editing:ScheduleEvent
signal dragged(offset)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if (event as InputEventMouseButton).pressed:
				if _contains(event.global_position):
					dragging = true
			else:
				dragging = false
	elif event is InputEventMouseMotion:
		if dragging:
			dragged.emit(event.relative)


func _process(_delta: float) -> void:
	# _gui_input only fires while the cursor is over the handle, so a
	# release outside would otherwise leave dragging stuck on forever.
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false


func _contains(pos: Vector2) -> bool:
	return get_global_rect().has_point(pos)
