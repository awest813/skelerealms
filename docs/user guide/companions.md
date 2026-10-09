# Companions

Skelerealms companions are recruitable NPCs that follow the player, wait on
order, track affinity, and plug into dialogue, quests, and trade. State lives
on `CompanionComponent` (saved with its entity); `CompanionSystem` drives the
roster, orders, and affinity milestones. Steering is an `AIModule`
(`CompanionFollowModule`), so it composes with schedules, GOAP, and combat.

## Making an NPC recruitable

Add a `CompanionComponent` to the entity (alongside its `NPCComponent`) and a
`CompanionFollowModule` as a child of the `NPCComponent`:

| Property | Type | Description |
|---|---|---|
| `recruited` | `bool` | Currently travelling with the player. |
| `following` | `bool` | Actively following (`false` = waiting). |
| `affinity` | `int` | Relationship score, `-100..100`. |
| `home_world` / `home_position` | `String` / `Vector3` | Where dismissal returns them. Captured at recruitment when empty. |
| `carry_capacity` | `int` | Max item count in their `InventoryComponent` (default `30`). |
| `affinity_perk_id` | `StringName` | Game-defined perk id, applied by your game at high affinity. |
| `follow_distance` / `catchup_distance` | `float` | Walk within 3 m; teleport-catch-up beyond 60 m or across worlds. |

No template changes are required — companions are opt-in per entity.

## Roster and orders

```gdscript
CompanionSystem.recruit(&"lydia")          # false when the party is full
CompanionSystem.dismiss(&"lydia")          # true = send home when set
CompanionSystem.set_following(&"lydia", false)  # wait here
CompanionSystem.get_party()                # Array of recruited ref-IDs
CompanionSystem.max_party_size = 2         # party cap, false on overflow
```

Following companions steer their puppet toward `GameInfo.world_origin`
(the player anchor), yield while busy or in combat, and teleport beside the
player across worlds or long distances. Schedules resume on their own when
following stops. Dismissal without a home leaves them where they stand.

## Affinity

```gdscript
CompanionSystem.adjust_affinity(&"lydia", 10, "quest_done")
CompanionSystem.get_affinity_level(&"lydia")  # FRACTURED / WARY / NEUTRAL / TRUSTED / SWORN
```

| Band | Range | Meaning |
|---|---|---|
| FRACTURED | `-100..-50` | Walks away: auto-dismissed home, `companion_left` emits. |
| WARY | `-49..-1` | — |
| NEUTRAL | `0..24` | Starting band. |
| TRUSTED | `25..59` | `affinity_milestone` fires — apply `affinity_perk_id` here. |
| SWORN | `60..100` | `affinity_milestone` fires — unlock their quest here. |

Milestones emit only on band crossings. All companion state saves with the
entity, so the roster can never drift — the system itself keeps no save data.

## Dialogue hooks

Recruit, dismiss, and gate dialogue on companions:

```gdscript
# Choice effect (DialogueChoiceEffect.companion_id):
{"type": "recruit_companion", "companion_id": &"lydia"}
{"type": "dismiss_companion", "companion_id": &"lydia"}

# Choice conditions:
{"type": "companion_recruited", "companion_id": &"lydia"}
{"type": "companion_affinity_min", "companion_id": &"lydia", "min_value": 25}
```

## Quest and trade patterns

- Target companions with quest aliases (`required_form` or exclusions), and
  gate follow-up stages on affinity via `CompanionSystem.get_affinity()`.
- Trade through their `InventoryComponent` with `can_carry()` /
  `cargo_count()` guarding capacity; the barter menu works against any
  vendor-side inventory.
- Companion combat needs no extra wiring: recruited NPCs fight with the
  standard NPC combat pipeline when threatened.
