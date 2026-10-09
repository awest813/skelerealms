extends Resource
## Data for one star system (a compact local zone kept near the origin).
##
## Systems are connected through [member links]; jumping unloads the current
## zone subtree and builds the destination, resetting coordinates back to the
## origin. Player-level state (ship durability, kills) lives outside the zone
## and survives the switch. Keeps the sandbox dependency-free.

## Stable identifier used by links, saves, and the travel coordinator.
@export var id := &""
## HUD display name, e.g. "TRAINING SECTOR".
@export var display_name := ""
## HUD subtitle, e.g. "LOCAL SPACE".
@export var sub_name := ""
## Destination ids reachable from this system.
@export var links: Array[StringName] = []

@export_group("Backdrop")
@export var bg_color := Color("030b19")
@export var ambient_color := Color("86a6cd")
@export var ambient_energy := 0.7
@export var sun_rotation := Vector3(-25, -40, 0)
@export var sun_color := Color("ffe0b5")
@export var sun_energy := 1.5
@export var star_seed := 314159
@export var planet_position := Vector3(620, 170, -1600)
@export var planet_radius := 240.0
@export var planet_color := Color("243d64")

@export_group("Course")
## Phase offset shaping this system's gate slalom (radians).
@export var gate_phase := 0.0
## Distance between consecutive gates.
@export var gate_spacing := 85.0
## Tint distinguishing this system's gates and obstacles.
@export var accent_a := Color("45b9b4")
@export var accent_b := Color("d49b54")
@export var obstacle_color := Color("47576b")

@export_group("Course")
## Gate count for this system's slalom. Surface zones use 0 (free flight).
@export var gate_count := 6

@export_group("Landing")
## Set on space systems: where the landing beacon floats.
@export var landing_beacon := Vector3(200, 40, -700)
## Set on space systems: surface system id the beacon leads to. Empty = none.
@export var landing_target := &""
## Set on surface systems: replaces the starfield backdrop builder.
@export var is_surface := false
## Day-sky background and ground tint for surface zones.
@export var surface_sky := Color("c77b3f")
@export var ground_color := Color("6b4a2e")

@export_group("Station")
## Display name of this system's station.
@export var station_name := "PORT MERIDIAN"
## Where the station sits in this zone.
@export var station_position := Vector3(90, 5, -250)

@export_group("Travel")
## Where the jump ring sits in this zone (fallback when a link has no
## dedicated ring in link_gates).
@export var jump_gate_position := Vector3(0, 10, -560)
## Destination id (String) → ring position. Systems with several links get
## one visible ring per destination.
@export var link_gates := {}
## Where arriving ships are placed (near the origin by design).
@export var arrival_position := Vector3.ZERO
## Facing on arrival (degrees around Y; 0 faces down-course, -Z).
@export var arrival_yaw_deg := 0.0
