class_name SKHUDShell
extends Control
## Abstract base for the game HUD layout.
## Provides widget slots that the consuming project fills with concrete
## implementations. Each slot expects a node conforming to the corresponding
## widget contract (duck-typed via [method Object.has_method]).


## Exported widget slot paths — set these in the editor to point at your
## concrete widget nodes.
@export_category("Widget Slots")
## Node implementing [SKVitalsWidget] contract.
@export var vitals_widget_path:NodePath
## Node implementing [SKCompassWidget] contract.
@export var compass_widget_path:NodePath
## Node implementing [SKCrosshair] contract.
@export var crosshair_widget_path:NodePath
## Node implementing [SKInteractionPrompt] contract.
@export var interaction_prompt_path:NodePath
## Node implementing [SKStatusEffectBar] contract.
@export var status_effect_bar_path:NodePath


## Resolved widget references (populated in [method _ready]).
var vitals_widget:Control
var compass_widget:Control
var crosshair_widget:Control
var interaction_prompt:Control
var status_effect_bar:Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_widgets()


func _resolve_widgets() -> void:
	if not vitals_widget_path.is_empty():
		vitals_widget = get_node_or_null(vitals_widget_path)
	if not compass_widget_path.is_empty():
		compass_widget = get_node_or_null(compass_widget_path)
	if not crosshair_widget_path.is_empty():
		crosshair_widget = get_node_or_null(crosshair_widget_path)
	if not interaction_prompt_path.is_empty():
		interaction_prompt = get_node_or_null(interaction_prompt_path)
	if not status_effect_bar_path.is_empty():
		status_effect_bar = get_node_or_null(status_effect_bar_path)


## Update the vitals display. Delegates to the vitals widget if present.
func update_vitals(data:Dictionary) -> void:
	if vitals_widget and vitals_widget.has_method("update_vitals"):
		vitals_widget.call("update_vitals", data)


## Update the compass heading.
func update_compass(degrees:float) -> void:
	if compass_widget and compass_widget.has_method("update_heading"):
		compass_widget.call("update_heading", degrees)


## Show an interaction prompt.
func show_interaction_prompt(text:String, action:StringName = &"interact") -> void:
	if interaction_prompt and interaction_prompt.has_method("show_prompt"):
		interaction_prompt.call("show_prompt", text, action)


## Hide the interaction prompt.
func hide_interaction_prompt() -> void:
	if interaction_prompt and interaction_prompt.has_method("hide_prompt"):
		interaction_prompt.call("hide_prompt")


## Set the crosshair state.
func set_crosshair_state(state_name:StringName) -> void:
	if crosshair_widget and crosshair_widget.has_method("set_state"):
		crosshair_widget.call("set_state", state_name)


## Update the status effect bar.
func update_status_effects(effects:Array) -> void:
	if status_effect_bar and status_effect_bar.has_method("update_effects"):
		status_effect_bar.call("update_effects", effects)
