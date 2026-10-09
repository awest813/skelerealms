# Character Progression

Levels, skills, perks, and origins. XP flows through `SkillsComponent`
(skill XP and character XP, both with carryover remainders), perks gate on
levels/skills/other perks, and origins package starting stats. Formulas live
in `SKConfig` (`skill_xp_formula`, `character_xp_formula`) so every game
tunes its own curve without code.

## Earning XP

```gdscript
skills.add_skill_xp(&"sneak", 25)   # levels sneak, emits skill_levelled_up
skills.add_character_xp(100)        # levels the character, emits character_levelled_up
```

XP sources are game wiring, not framework magic. The three standard hooks:

- **Quest XP**: `QuestSystem.quest_completed.connect(func(id, xp): player_skills.add_character_xp(xp))`
- **Skill use**: call `add_skill_xp` from harvest/hit/craft callbacks.
- **Kills**: combat resolution calls `add_skill_xp` on the victor.

Unknown skills warn and bank nothing; negative awards clamp to zero; awards
without a loaded `SKConfig` bank safely instead of crashing.

## Perks

A `Perk` resource declares requirements and effects:

| Field | Description |
|---|---|
| `required_level` / `required_skills` / `required_perks` | Character level, skill minimums, perk chain. |
| `effects` | `vital_max` (raise max + heal), `skill_xp_rate` (XP multiplier, blank skill = all), `flag` (game-checked marker). |

```gdscript
PerkSystem.register_perk(preload("res://perks/tough_hide.tres"))
var check := PerkSystem.can_take(player, &"tough_hide")  # {ok, reason} for UI
PerkSystem.grant(player, &"tough_hide")                  # spends a point
PerkSystem.has_flag(player, &"can_smith_ebony")          # game-side gates
```

Perk points accrue automatically: `PerkComponent` grants one per sibling
character level. Grants live on the component (saved with the entity); the
system keeps no save data. There is no respec in v1. Validate content with
`PerkSystem.validate_perk()`.

## Origins

An `Origin` resource (race, background, upbringing) applies once at
character creation:

```gdscript
origin.apply_to(player)  # attributes stack, skills set minimums, perks grant free
```

Requires `AttributesComponent` and `SkillsComponent`; starting perks need a
`PerkComponent` (warns without one). Effects of origin perks apply
immediately, like grants.
