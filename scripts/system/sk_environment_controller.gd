class_name SKEnvironmentController
extends Node
## Base class for day/night environment controllers.
##
## Extend this class and implement [method _apply_time] to drive
## [WorldEnvironment], [DirectionalLight3D] (sun angle/color), or any
## other scene nodes based on the current world time.
##
## The controller connects to [GameInfo]'s time signals automatically.
## The first call to [method _apply_time] happens in [method _ready] using the
## current world time so the environment is correct on game load.
##
## ## Typical Usage
## ```gdscript
## class_name MyEnvironment
## extends SKEnvironmentController
##
## @export var sun: DirectionalLight3D
## @export var sky: WorldEnvironment
##
## func _apply_time(progress: float) -> void:
##     # progress is 0.0 (midnight) → 1.0 (midnight next day)
##     var sun_angle := lerpf(-90.0, 270.0, progress)
##     sun.rotation_degrees.x = sun_angle
## ```


## Emitted whenever [method _apply_time] is called.
## [param progress] is the fractional progress through the in-game day (0.0–1.0).
signal time_applied(progress: float)


func _ready() -> void:
	# Connect to minute-level time signals so the environment updates every in-game minute.
	if not Engine.is_editor_hint():
		GameInfo.minute_incremented.connect(_on_time_changed)
		# Apply immediately on startup so the environment reflects a loaded save.
		_on_time_changed()


## Called every in-game minute. Override [method _apply_time] rather than this.
func _on_time_changed() -> void:
	var progress := _day_progress()
	_apply_time(progress)
	time_applied.emit(progress)


## Override this in a subclass to drive environment nodes.
## [param progress] is a normalised float from 0.0 (start of day) to 1.0 (end of day).
func _apply_time(_progress: float) -> void:
	pass


## Compute the fractional progress through the current in-game day (0.0–1.0).
func _day_progress() -> float:
	var hours_per_day: float = ProjectSettings.get_setting("skelerealms/hours_per_day", 24.0)
	var minutes_per_hour: float = ProjectSettings.get_setting("skelerealms/minutes_per_hour", 60.0)
	var total_minutes: float = hours_per_day * minutes_per_hour
	var current_minutes: float = GameInfo.hour * minutes_per_hour + GameInfo.minute + GameInfo.time_fraction
	return clampf(current_minutes / total_minutes, 0.0, 1.0)
