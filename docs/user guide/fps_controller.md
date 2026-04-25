# FPS Player Controller

This guide explains how to wire Skelerealms' **FPS player puppet** into your project.

## Overview

Skelerealms separates player data (the `SKEntity` + components) from the physical in-scene representation (the *puppet*). The `FPSPlayerPuppet` script drives a first-person `CharacterBody3D` that is spawned by `PuppetSpawnerComponent` and connected to the player entity automatically.

```
PlayerEntity (SKEntity)
├── PlayerComponent         — entity sync, damage routing
├── PuppetSpawnerComponent  — spawns/despawns the puppet
│   └── FPSPuppet.tscn      ← your CharacterBody3D scene
├── TeleportComponent       — world-to-world teleport
├── VitalsComponent         — health, stamina, magicka
├── DamageableComponent     — receives DamageInfo events
└── InventoryComponent      — carried items and currency
```

---

## 1. Create the player entity

Use **`player_entity_template.tscn`** as your starting point. Duplicate it into `res://entities/` and rename it (e.g. `player.tscn`). The entity name becomes the player's RefID (`"Player"` by convention).

Set the entity's `world` property to the world the player starts in, and `position` to the spawn point.

---

## 2. Build the FPS puppet scene

Create a new scene with a **`CharacterBody3D`** root. Then add:

| Child node | Type | Required? | Notes |
|---|---|---|---|
| `Camera3D` | `Camera3D` | **Yes** | Name it `Camera3D` or set the path export |
| `StandingCollisionShape` | `CollisionShape3D` | **Yes** | Capsule shape for standing |
| `CrouchingCollisionShape` | `CollisionShape3D` | Optional | Shorter capsule for crouching |
| `SKFootstepPlayer` | `SKFootstepPlayer` | Optional | Surface-aware footstep audio |

Attach **`res://addons/skelerealms/scripts/puppets/fps_player_puppet.gd`** to the root node.

### Required input actions

Add these to your project's **Input Map** (Project → Project Settings → Input Map):

| Action | Suggested key |
|---|---|
| `move_forward` | W |
| `move_back` | S |
| `move_left` | A |
| `move_right` | D |
| `jump` | Space |
| `sprint` | Left Shift |
| `crouch` | Left Ctrl |
| `interact` | E |

---

## 3. Attach the puppet to the entity

1. Save your puppet scene (e.g. `res://puppets/fps_puppet.tscn`).
2. Open `player.tscn`.
3. Select `PuppetSpawnerComponent`.
4. Instance `fps_puppet.tscn` as a child of `PuppetSpawnerComponent`. The component treats this child as the pre-built puppet for when the entity is in-scene.

---

## 4. HUD integration (optional)

The puppet will call `show_interaction_prompt`, `hide_interaction_prompt`, and `set_crosshair_state` on whatever node is assigned to its **HUD Path** export — as long as that node responds to those methods.

Assign the path to your `SKHUDShell` subclass in the Inspector, or leave it blank to skip HUD updates.

---

## 5. Stamina during sprinting

`FPSPlayerPuppet` automatically reads the `VitalsComponent` from the parent entity and drains `moxie` (stamina) while the player is sprinting. Tune the drain rate with the **Sprint Moxie Drain** export (units/second; set to `0` to disable).

When the entity's `VitalsComponent.is_exhausted` is true, the puppet stops sprinting.

---

## 6. Footstep audio

Add an `SKFootstepPlayer` node as a child of your puppet. Then:

1. Add `AudioStreamPlayer3D` children to it, named after your surface groups (e.g. `stone`, `wood`, `grass`). Assign an `AudioStreamRandomizer` stream to each one with your sound files.
2. Add the `AudioStreamPlayer3D` named `default` as the fallback.
3. In your floors/terrain physics bodies, add matching **groups** (e.g. add group `stone` to your stone `StaticBody3D`).
4. Call `$SKFootstepPlayer.play_footstep()` from your puppet's movement logic on each step.

The simplest integration is a timer inside `_physics_process`:

```gdscript
var _footstep_timer: float = 0.0

func _physics_process(delta: float) -> void:
    # ... existing puppet physics ...
    
    if is_on_floor() and velocity.length() > 0.5:
        _footstep_timer -= delta
        if _footstep_timer <= 0.0:
            var interval := 0.3 if _is_sprinting else 0.6
            _footstep_timer = interval
            var fs := get_node_or_null("SKFootstepPlayer") as SKFootstepPlayer
            if fs:
                if _is_sprinting:
                    fs.play_footstep_sprint()
                elif _is_crouching:
                    fs.play_footstep_crouch()
                else:
                    fs.play_footstep()
```

---

## 7. World transitions

`TeleportComponent.teleport(world, position)` moves the entity to another world and fires the `teleporting` signal. `PlayerComponent` listens for this and calls `WorldLoader.load_world()` + sets the puppet position. The existing `Door` world-object handles the handoff automatically for scene-transition doors.
