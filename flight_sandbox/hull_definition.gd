extends Resource
## Immutable preset-hull template. The shipyard sells whole hulls, never
## parts: tuning, durability, cargo bonus, and paint come as one package.

## Stable id (e.g. &"sparrow"). Saved in ShipState.
@export var id := &""
## Display name and sales pitch.
@export var display_name := ""
@export var description := ""
## Purchase price in credits. The starter hull costs 0 and is pre-owned.
@export var cost := 0

@export_group("Flight Tuning")
@export var thrust_acceleration := 22.0
@export var strafe_acceleration := 14.0
@export var brake_acceleration := 35.0
@export var maximum_speed := 120.0
@export var angular_speed := 1.25
@export var angular_response := 8.0

@export_group("Durability & Cargo")
@export var max_shield := 50.0
@export var max_hull := 100.0
@export var cargo_bonus := 0

@export_group("Paint")
@export var hull_tint := Color("a3b4c3")
@export var wing_tint := Color("a67848")
