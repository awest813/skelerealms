# Combat System

Skelerealms ships a full combat subsystem under `scripts/combat/` that provides
Skyrim-style melee, Fallout-style hitscan, and RPG ability/spell hit resolution.
The system is data-driven, modular, and integrates with the existing
`DamageableComponent`, `VitalsComponent`, and `NPCComponent` signals.

---

## Architecture overview

| File | Class | Role |
|---|---|---|
| `damage_packet.gd` | `DamagePacket` | Extends `DamageInfo`; adds crit flags, hit reaction, weapon source, and gameplay tags. |
| `combat_action.gd` | `CombatAction` | `Resource` declaring a single attack/spell: timing, costs, damage template, combo links. |
| `combatant_component.gd` | `CombatantComponent` | `SKEntityComponent` tracking poise, resistances, and block/parry/invincibility state. |
| `combat_state_machine.gd` | `CombatStateMachine` | Extends `FSMMachine`; drives Idle → Attack/Cast → Stagger → Knockdown → Death flow. |
| `hit_pipeline.gd` | `HitPipeline` | Stateless resolver for melee and hitscan hits. |
| `hitbox.gd` | `SKHitbox` | `Area3D` on weapon/projectile; deduplicates hits per swing. |
| `hurtbox.gd` | `SKHurtbox` | `Area3D` on entity body; routes hits to `DamageableComponent`. |
| `combat_action_module.gd` | `CombatActionModule` | `AIModule` that picks which `CombatAction` an NPC executes. |

---

## Setting up combat for an entity

### 1. Add `CombatantComponent`

Add a `CombatantComponent` node as a child of the entity.  Configure the exports:

| Property | Description |
|---|---|
| `max_poise` | Poise pool (depleted by hits; reaching 0 triggers stagger). |
| `poise_regen_rate` | Poise units recovered per second after `poise_regen_delay` seconds since last hit. |
| `resistances` | Dictionary of `StringName` damage-type → multiplier. `0.5` = half damage, `0.0` = immune. |
| `block_damage_multiplier` | Fraction of damage absorbed while blocking (default `0.25`). |
| `block_poise_multiplier` | Fraction of poise damage absorbed while blocking (default `0.5`). |

### 2. Add `CombatStateMachine`

Add a `CombatStateMachine` node and call `initialize(entity)` in your puppet's `_ready`:

```gdscript
func _ready() -> void:
    $CombatStateMachine.initialize(get_parent() as SKEntity)
```

Connect the machine's signals to your animation controller:

```gdscript
$CombatStateMachine.attack_started.connect(func(a): $AnimationPlayer.play(a.animation))
$CombatStateMachine.hitbox_active.connect(func(active): $Hitbox.active = active)
$CombatStateMachine.entity_died.connect(_on_death)
```

### 3. Add hitboxes and hurtboxes

- Place an `SKHitbox` `Area3D` on the weapon bone.  Set `owner_entity_ref` to the entity's name.
- Place one or more `SKHurtbox` `Area3D` nodes on body regions.  Set `owner_entity_ref` and optionally `damage_multiplier` for locational damage (e.g. `2.0` for head).

Connect the hitbox:

```gdscript
$Weapon/SKHitbox.hit_registered.connect(func(hurtbox):
    HitPipeline.resolve_hit($Weapon/SKHitbox, hurtbox, current_action, entity.name, &"iron_sword")
)
```

---

## Defining combat actions

Create a `CombatAction` resource (`.tres`):

| Property | Description |
|---|---|
| `id` | Unique `StringName` (e.g. `&"heavy_swing"`). |
| `action_type` | `MELEE`, `RANGED`, or `SPELL`. |
| `startup_duration` | Wind-up seconds before the hit window opens. |
| `active_duration` | Seconds the hitbox is active. |
| `recovery_duration` | Cooldown seconds after the hit; combo input accepted here. |
| `stamina_cost` / `mana_cost` | Resource cost deducted on execution. |
| `base_damage` | Dictionary of damage type → float (e.g. `{&"blunt": 20.0}`). |
| `poise_damage` | Poise removed from the target per hit. |
| `hit_reaction` | `&"flinch"`, `&"stagger"`, or `&"knockdown"`. |
| `crit_chance` / `crit_multiplier` | Probability and multiplier for critical hits. |
| `combo_links` | Array of action IDs that can chain from this one during recovery. |

---

## Executing an action

```gdscript
# Player presses attack button
if $CombatStateMachine.execute_action(heavy_swing_action):
    pass  # machine handles the rest
```

`execute_action` returns `false` if the entity is not in `Idle` state or cannot
afford the action's resource cost.

---

## Combos

Queue a follow-up during the recovery phase:

```gdscript
# During recovery of heavy_swing_action:
$CombatStateMachine.queue_combo(uppercut_action)
# Uppercut will chain automatically when recovery ends.
```

Check the combo window:

```gdscript
if $CombatStateMachine.is_in_combo_window():
    show_combo_prompt()
```

---

## Hitscan (ranged / firearms)

```gdscript
var result := HitPipeline.resolve_hitscan(
    get_world_3d().direct_space_state,
    muzzle.global_position,
    -muzzle.global_transform.basis.z,
    rifle_action,
    entity.name,
    &"rifle",
    [get_rid()]  # exclude shooter
)
```

---

## NPC combat AI

Add a `CombatActionModule` node under `NPCComponent`.  Export-assign an array of
`CombatAction` resources.  The module selects an action each frame based on
distance-to-target, available resources, and target state, then calls
`CombatStateMachine.execute_action()` on the NPC's machine.

---

## Signals quick-reference

### `CombatStateMachine`
| Signal | When |
|---|---|
| `attack_started(action)` | Attack/cast begins. |
| `attack_finished(action)` | All three phases complete without interrupt. |
| `hitbox_active(active)` | Active phase starts/ends — toggle hitbox. |
| `animation_requested(anim_name)` | Play this animation. |
| `entity_died` | Death state entered. |
| `combat_state_changed(state_name)` | Any state transition. |

### `CombatantComponent`
| Signal | When |
|---|---|
| `poise_broken` | Poise reaches zero — should trigger stagger. |
| `poise_restored` | Poise refilled after stagger recovery. |
| `block_hit(hitbox)` | A blocked hit landed — attacker recoil / sound. |
| `parry_landed(hitbox)` | A parried hit — attacker stagger / feedback. |
| `invincibility_changed(active)` | I-frame window opened/closed. |
