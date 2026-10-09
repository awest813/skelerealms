class_name Perk
extends Resource
## One purchasable perk in a trait tree. Requirements gate [method PerkSystem.can_take];
## effects apply on grant. There is no respec in v1 — grants are permanent.


## Unique ID, e.g. &"tough_hide".
@export var id: StringName
## Display name.
@export var perk_name: String
## What it does, for tooltips.
@export_multiline var description: String
## Minimum character level (SkillsComponent.level).
@export var required_level: int = 0
## Skill minimums: skill id String -> level int.
@export var required_skills: Dictionary = {}
## Perk ids that must already be granted.
@export var required_perks: Array[StringName] = []
## Mechanical effects, applied once on grant.
@export var effects: Array[PerkEffect] = []
