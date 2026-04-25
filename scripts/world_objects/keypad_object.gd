class_name KeypadObject
extends InteractiveObject
## Code-entry keypad that emits a signal when the correct passcode is entered.
##
## This class handles only the logic of code entry and validation. The UI
## (buttons, display) is game-specific and calls [method enter_digit],
## [method clear_code], and [method submit_code] on this node. Wire the
## [signal correct_code_entered] signal to any [SwingDoorObject] or other
## object that should respond to a successful unlock.
##
## [b]Example flow:[/b]
## 1. Player interacts → your keypad UI opens and calls
##    [code]keypad.enter_digit("4")[/code] for each key press.
## 2. When ready, call [code]keypad.submit_code()[/code].
## 3. Connect [signal correct_code_entered] → [code]door.unlock()[/code].
##
## If [member auto_submit] is true, the code is checked automatically once the
## correct number of digits is entered — no explicit [method submit_code] call
## needed.


## Emitted when the entered code matches [member passcode].
signal correct_code_entered
## Emitted when an incorrect code is submitted.
signal wrong_code_entered(entered: String)
## Emitted every time the entered code changes (pass to your display label).
signal code_display_changed(display: String)
## Emitted when the max number of attempts is exceeded.
signal attempts_exhausted


@export_group("Keypad Settings")
## The correct code. Use digits only.
@export var passcode: String = ""
## If [code]true[/code], the code is validated automatically as soon as the
## right number of digits is entered. The player does not need to press a
## confirm key.
@export var auto_submit: bool = true
## Maximum number of wrong attempts allowed (0 = unlimited).
@export var max_attempts: int = 0
## If [code]true[/code] the digits are displayed as asterisks (password mode).
@export var mask_input: bool = false

@export_group("Audio")
## Sound played on a correct code entry.
@export var correct_sound: AudioStream
## Sound played on a wrong code entry.
@export var wrong_sound: AudioStream
## Sound played for each digit press.
@export var digit_sound: AudioStream

## The code entered so far. Read-only; modify via [method enter_digit] / [method clear_code].
var entered_code: String = ""
## Whether the keypad has been successfully unlocked.
var is_unlocked: bool = false

var _attempt_count: int = 0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()

	for c in get_children():
		if c is AudioStreamPlayer3D:
			_audio = c as AudioStreamPlayer3D
			break


## Append a single character to the entered code.
## Called by your keypad UI buttons.
func enter_digit(digit: String) -> void:
	if is_unlocked:
		return
	if passcode.length() > 0 and entered_code.length() >= passcode.length():
		return

	entered_code += digit
	_play_sound(digit_sound)
	_emit_display()

	if auto_submit and passcode.length() > 0 and entered_code.length() == passcode.length():
		submit_code()


## Clear the entered code.
func clear_code() -> void:
	entered_code = ""
	_emit_display()


## Validate the currently entered code against [member passcode].
func submit_code() -> void:
	if is_unlocked:
		return

	if entered_code == passcode:
		is_unlocked = true
		interactible = false
		_play_sound(correct_sound)
		correct_code_entered.emit()
	else:
		_attempt_count += 1
		_play_sound(wrong_sound)
		wrong_code_entered.emit(entered_code)
		if max_attempts > 0 and _attempt_count >= max_attempts:
			interactible = false
			attempts_exhausted.emit()
		clear_code()


## Reset the keypad to its initial locked state.
func reset_keypad() -> void:
	is_unlocked = false
	interactible = true
	_attempt_count = 0
	clear_code()


func _emit_display() -> void:
	if mask_input:
		code_display_changed.emit("*".repeat(entered_code.length()))
	else:
		code_display_changed.emit(entered_code)


func _play_sound(stream: AudioStream) -> void:
	if not _audio or not stream:
		return
	_audio.stream = stream
	_audio.play()
