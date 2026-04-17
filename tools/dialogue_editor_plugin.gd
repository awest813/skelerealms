@tool
extends EditorInspectorPlugin
## Inspector plugin that adds an "Open Dialogue Editor" button when a [DialogueDefinition] is selected.


signal request_open(definition: DialogueDefinition)


func _can_handle(object: Object) -> bool:
	return object is DialogueDefinition


func _parse_begin(object: Object) -> void:
	var b := Button.new()
	b.text = "Open Dialogue Editor"
	b.pressed.connect(func() -> void: request_open.emit(object as DialogueDefinition))
	add_custom_control(b)
