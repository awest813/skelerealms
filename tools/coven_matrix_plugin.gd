@tool
extends EditorInspectorPlugin
## Inspector plugin that adds an "Open Coven Matrix" button when a [Coven] is selected.


signal request_open


func _can_handle(object: Object) -> bool:
	return object is Coven


func _parse_begin(_object: Object) -> void:
	var b := Button.new()
	b.text = "Open Coven Relationship Matrix"
	b.pressed.connect(func() -> void: request_open.emit())
	add_custom_control(b)
