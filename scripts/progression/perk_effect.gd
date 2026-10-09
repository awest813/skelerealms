class_name PerkEffect
extends Resource
## One mechanical effect of a [Perk]. Effect kinds map onto existing
## systems only — no new engine code per perk. Game-specific powers use
## the "flag" kind, which games check directly.


## Effect kind: "vital_max", "skill_xp_rate", or "flag".
@export var type: String = "flag"
## Vital raised (when type == "vital_max"): "health", "moxie", or "will".
@export var vital: String = "health"
## Amount added to the vital max, and healed alongside (when "vital_max").
@export var amount: float = 0.0
## Skill the XP multiplier applies to, or empty for all (when "skill_xp_rate").
@export var skill_id: StringName
## XP multiplier (when type == "skill_xp_rate"). Must be above zero.
@export var multiplier: float = 1.0
## Marker id for game-checked powers (when type == "flag").
@export var flag: StringName
