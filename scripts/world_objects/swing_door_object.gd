class_name SwingDoorObject
extends InteractiveObject
## A local animated door (swing or slide) that can be locked with a key item.
##
## Unlike [Door], which handles world-to-world teleport transitions, this class
## handles physical doors that open in-place via a [Tween]. Supports rotating
## (swing) and sliding door types. Lock it with a key item tracked by an
## [InventoryComponent].
##
## [b]Usage:[/b] Attach to the root [Node3D] of your door mesh. Tune the open/
## closed transform values in the Inspector and wire audio streams.


## Emitted when the door opens.
signal door_opened
## Emitted when the door closes.
signal door_closed
## Emitted when a locked door is interacted with.
signal door_rattled
## Emitted when the lock state changes.
signal lock_state_changed(is_locked: bool)


enum DoorType {
	## Door rotates about its local Y axis.
	ROTATING,
	## Door slides along a local axis.
	SLIDING,
}


@export_group("Door Settings")
## Whether the door starts open.
@export var is_open: bool = false
## Whether the door is locked.
@export var is_locked: bool = false
## Door movement type.
@export var door_type: DoorType = DoorType.ROTATING
## Duration of the open/close transition (seconds).
@export var door_speed: float = 0.5
## If > 0 the door will automatically close after this many seconds.
@export var auto_close_delay: float = 0.0

@export_group("Rotating Door")
## Local-space Euler angles (degrees) when fully closed.
@export var closed_rotation_deg: Vector3 = Vector3.ZERO
## Local-space Euler angles (degrees) when fully open.
@export var open_rotation_deg: Vector3 = Vector3(0.0, 90.0, 0.0)

@export_group("Sliding Door")
## Local-space position when fully closed.
@export var closed_position: Vector3 = Vector3.ZERO
## Local-space position when fully open.
@export var open_position: Vector3 = Vector3(2.0, 0.0, 0.0)

@export_group("Lock")
## FormID of the key item that unlocks this door. Leave blank if no key is
## required (but [member is_locked] may still be toggled programmatically).
@export var key_form_id: String = ""
## Hint shown to the player when they try to open a locked door without the key.
@export var locked_hint: String = "This door is locked."

@export_group("Audio")
@export var open_sound: AudioStream
@export var close_sound: AudioStream
## Sound played when the player tries to open a locked door.
@export var locked_sound: AudioStream
@export var unlock_sound: AudioStream

var _tween: Tween
var _auto_close_timer: Timer
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()

	# Find an AudioStreamPlayer3D child if one exists.
	for c in get_children():
		if c is AudioStreamPlayer3D:
			_audio = c as AudioStreamPlayer3D
			break

	if auto_close_delay > 0.0:
		_auto_close_timer = Timer.new()
		_auto_close_timer.one_shot = true
		_auto_close_timer.timeout.connect(_on_auto_close)
		add_child(_auto_close_timer)

	# Snap to start state without tweening.
	if is_open:
		_apply_state(true, true)
	else:
		_apply_state(false, true)

	_refresh_verb()


func interact(id: String) -> void:
	if is_locked:
		_try_unlock(id)
		return
	super.interact(id)
	if is_open:
		close_door()
	else:
		open_door()


## Open the door programmatically (e.g. triggered by a button or keypad).
func open_door() -> void:
	if is_open:
		return
	is_open = true
	_refresh_verb()
	_apply_state(true, false)
	_play_sound(open_sound)
	door_opened.emit()
	if auto_close_delay > 0.0 and _auto_close_timer:
		_auto_close_timer.start(auto_close_delay)


## Close the door programmatically.
func close_door() -> void:
	if not is_open:
		return
	is_open = false
	_refresh_verb()
	_apply_state(false, false)
	_play_sound(close_sound)
	door_closed.emit()


## Lock the door.
func lock() -> void:
	is_locked = true
	lock_state_changed.emit(true)
	_refresh_verb()


## Unlock the door (without requiring a key item).
func unlock() -> void:
	is_locked = false
	lock_state_changed.emit(false)
	_refresh_verb()


# ── Private helpers ───────────────────────────────────────────────────────────

func _try_unlock(interactor_id: String) -> void:
	door_rattled.emit()
	_play_sound(locked_sound)

	if key_form_id.is_empty():
		# No key required — just rattle.
		return

	var entity := SKEntityManager.instance.get_entity(interactor_id) if SKEntityManager.instance else null
	if not entity:
		return
	var inv := entity.get_component("InventoryComponent") as InventoryComponent
	if not inv:
		return

	var matches := inv.get_items_of_form(key_form_id)
	if matches.is_empty():
		# Player doesn't have the key — emit hint via AudioEventEmitter pattern.
		push_warning("SwingDoorObject '%s': interactor '%s' lacks key '%s'." % [name, interactor_id, key_form_id])
		return

	_play_sound(unlock_sound)
	unlock()


func _apply_state(open: bool, instant: bool) -> void:
	if _tween:
		_tween.kill()

	match door_type:
		DoorType.ROTATING:
			var target_deg: Vector3 = open_rotation_deg if open else closed_rotation_deg
			if instant:
				rotation_degrees = target_deg
			else:
				_tween = create_tween()
				_tween.tween_property(self, "rotation_degrees", target_deg, door_speed)
		DoorType.SLIDING:
			var target_pos: Vector3 = open_position if open else closed_position
			if instant:
				position = target_pos
			else:
				_tween = create_tween()
				_tween.tween_property(self, "position", target_pos, door_speed)


func _refresh_verb() -> void:
	if is_locked:
		interact_verb = "Locked"
	elif is_open:
		interact_verb = "Close"
	else:
		interact_verb = "Open"


func _play_sound(stream: AudioStream) -> void:
	if not _audio or not stream:
		return
	_audio.stream = stream
	_audio.play()


func _on_auto_close() -> void:
	close_door()
