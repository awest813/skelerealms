class_name ButtonObject
extends InteractiveObject
## A pressable button that can trigger other [InteractiveObject]s.
##
## Supports single-use and repeatable buttons, a press cooldown, and chaining
## to an arbitrary list of other [InteractiveObject]s (or nodes with an
## [code]interact[/code] method). Useful for levers, switches, pressure plates,
## and any momentary-contact trigger.
##
## [b]Usage:[/b] Add to your scene, assign [member objects_to_trigger] in the
## Inspector, and connect the [signal pressed] signal for additional logic.


## Emitted when the button is successfully pressed.
signal pressed
## Emitted when the button enters or exits its cooldown period.
signal cooldown_changed(active: bool)


@export_group("Button Settings")
## Interaction prompt shown when the button is ready to use.
@export var usable_verb: String = "Press"
## Interaction prompt shown after the button has been used (when
## [member allows_repeat] is false).
@export var used_verb: String = "Used"
## If [code]true[/code], the button can be pressed more than once.
@export var allows_repeat: bool = true
## Seconds the button waits before it can be pressed again (0 = no cooldown).
@export var cooldown_time: float = 0.0
## Sound played when the button is pressed.
@export var press_sound: AudioStream

@export_group("Trigger Chain")
## Other nodes to call [code]interact(id)[/code] on when this button is pressed.
## The node must be an [InteractiveObject] or have an [code]interact(id)[/code]
## method. Paths are relative to this node's parent.
@export var objects_to_trigger: Array[NodePath] = []
## Delay in seconds before calling [code]interact[/code] on the chained nodes.
@export var trigger_delay: float = 0.0

var _has_been_used: bool = false
var _cooldown_remaining: float = 0.0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	interact_verb = usable_verb

	for c in get_children():
		if c is AudioStreamPlayer3D:
			_audio = c as AudioStreamPlayer3D
			break


func _physics_process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_cooldown_remaining = 0.0
			cooldown_changed.emit(false)


func interact(id: String) -> void:
	if _cooldown_remaining > 0.0:
		return
	if not allows_repeat and _has_been_used:
		return

	super.interact(id)
	_press(id)


func _press(interactor_id: String) -> void:
	_has_been_used = true
	pressed.emit()

	if _audio and press_sound:
		_audio.stream = press_sound
		_audio.play()

	if not allows_repeat:
		interact_verb = used_verb
		interactible = false
	elif cooldown_time > 0.0:
		_cooldown_remaining = cooldown_time
		cooldown_changed.emit(true)

	_trigger_chained(interactor_id)


func _trigger_chained(interactor_id: String) -> void:
	if objects_to_trigger.is_empty():
		return

	var call_fn := func() -> void:
		for path in objects_to_trigger:
			if path.is_empty():
				continue
			var target := get_node_or_null(path)
			if not target:
				push_warning("ButtonObject '%s': trigger target '%s' not found." % [name, path])
				continue
			if target.has_method("interact"):
				target.interact(interactor_id)

	if trigger_delay > 0.0:
		get_tree().create_timer(trigger_delay).timeout.connect(call_fn, CONNECT_ONE_SHOT)
	else:
		call_fn.call()
