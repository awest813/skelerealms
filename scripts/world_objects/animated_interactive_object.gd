class_name AnimatedInteractiveObject
extends InteractiveObject
## Base class for world objects that open and close via an [AnimationPlayer].
##
## Concrete subclasses (e.g. a drawer or hatch) extend this and either leave
## [member open_animation]/[member close_animation] to drive a real
## [AnimationPlayer], or override [method _do_open]/[method _do_close] entirely.
##
## Audio is played through an [AudioStreamPlayer3D] child node. Add one to your
## scene and assign the streams in the Inspector.


## Emitted when the object finishes opening.
signal opened
## Emitted when the object finishes closing.
signal closed

@export_group("Animation")
## Name of the animation to play when opening. Must exist on the [AnimationPlayer] child.
@export var open_animation: String = "open"
## Name of the animation to play when closing. Leave blank to play [member open_animation]
## in reverse.
@export var close_animation: String = ""
## Path to the [AnimationPlayer] child. Defaults to the first [AnimationPlayer] found.
@export_node_path("AnimationPlayer") var animation_player_path: NodePath

@export_group("Audio")
## Sound played when opening. Requires an [AudioStreamPlayer3D] child.
@export var open_sound: AudioStream
## Sound played when closing.
@export var close_sound: AudioStream

@export_group("State")
## If [code]true[/code] the object starts in the open state.
@export var starts_open: bool = false
## If [code]true[/code] the object cannot currently be interacted with.
@export var locked: bool = false
## Verb shown on the interaction prompt when locked.
@export var locked_verb: String = "LOCKED"

## Current open/closed state.
var is_open: bool = false

var _anim_player: AnimationPlayer
var _audio_player: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	is_open = starts_open

	if not animation_player_path.is_empty():
		_anim_player = get_node_or_null(animation_player_path) as AnimationPlayer
	else:
		_anim_player = _find_child_of_type(self, "AnimationPlayer") as AnimationPlayer

	_audio_player = _find_child_of_type(self, "AudioStreamPlayer3D") as AudioStreamPlayer3D

	if _anim_player and starts_open:
		# Jump to end of open animation without playing it.
		_anim_player.play(open_animation)
		_anim_player.advance(_anim_player.current_animation_length)


func interact(id: String) -> void:
	if locked:
		_play_sound(null)  # No audio — subclasses can override for a rattle.
		return
	super.interact(id)
	if is_open:
		_do_close()
	else:
		_do_open()


## Override to customise open behaviour. Default implementation plays the animation.
func _do_open() -> void:
	is_open = true
	interact_verb = "Close"
	_play_animation(open_animation, false)
	_play_sound(open_sound)
	opened.emit()


## Override to customise close behaviour. Default plays [member close_animation]
## or the open animation in reverse.
func _do_close() -> void:
	is_open = false
	interact_verb = "Open"
	if not close_animation.is_empty():
		_play_animation(close_animation, false)
	else:
		_play_animation(open_animation, true)
	_play_sound(close_sound)
	closed.emit()


func _play_animation(anim_name: String, backwards: bool) -> void:
	if not _anim_player:
		push_warning("AnimatedInteractiveObject '%s': no AnimationPlayer found." % name)
		return
	if not _anim_player.has_animation(anim_name):
		push_warning("AnimatedInteractiveObject '%s': animation '%s' not found." % [name, anim_name])
		return
	if backwards:
		_anim_player.play_backwards(anim_name)
	else:
		_anim_player.play(anim_name)


func _play_sound(stream: AudioStream) -> void:
	if not _audio_player or not stream:
		return
	_audio_player.stream = stream
	_audio_player.play()


## Utility: find the first child of a given class name string (shallow, one level deep).
static func _find_child_of_type(parent: Node, type_name: String) -> Node:
	for c in parent.get_children():
		if c.get_class() == type_name or c.is_class(type_name):
			return c
	return null
