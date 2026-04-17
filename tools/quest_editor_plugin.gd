@tool
extends EditorInspectorPlugin
## Inspector plugin that adds an "Open Quest Editor" button when a [QuestDefinition] is selected.


signal request_open(definition: QuestDefinition)


func _can_handle(object: Object) -> bool:
	return object is QuestDefinition


func _parse_begin(object: Object) -> void:
	var b := Button.new()
	b.text = "Open Quest Editor"
	b.pressed.connect(func() -> void: request_open.emit(object as QuestDefinition))
	add_custom_control(b)
