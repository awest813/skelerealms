# Creatures

Non-humanoid bodies — wolves, crawlers, cliff racers — are ordinary NPCs
with a `CreatureProfile` body plan read by `CreaturePuppet` (which extends
`NPCPuppet`, so perception, combat, dialogue, and entity sync keep working
unchanged). Scenes author the mesh, eyes, and ears; the profile scales
locomotion, collision, and senses per species.

## Body plans

| Property | Description |
|---|---|
| `movement_mode` | `GROUND` walks the navmesh; `FLY` self-steers in open air, no navmesh. Swimming is a later profile. |
| `move_speed` / `turn_speed` / `arrive_radius` | Top speed, turn rate, and settle distance. |
| `collision_radius` / `collision_height` | Capsule applied to the first `CollisionShape3D` child (created if missing). |
| `perception_range_mult` / `perception_fov_mult` | Multipliers over scene-authored eyes. Applied once. |

```gdscript
var wolf := CreaturePuppet.new()
wolf.profile = preload("res://bodies/wolf.tres")
```

Ground bodies use the standard navigation pipeline plus any movement
module. Flyers ignore the nav agent and steer yaw-limited toward movement
targets, climbing and diving along their forward vector while staying
upright — so `set_movement_target`, follow packages, companion orders, and
combat targeting all work unchanged across body plans. Validate content with
`profile.validate()`.

## Composition

Creatures compose with every actor system for free: `CompanionComponent`
makes a loyal hound (carry capacity included), `PackageComponent` gives
grazing or perch routines, and covens/factions govern their disposition.
No creature-specific code paths exist anywhere outside the puppet.
