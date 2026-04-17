class_name CovenOpinionOverride
extends Resource
## Declares an opinion adjustment one coven has toward another.
## Used in [ModManifest] to modify faction relationships at load time.


## The coven whose opinion is being changed.
@export var coven_id: StringName
## The coven that [member coven_id] holds an opinion about.
@export var target_coven_id: StringName
## Amount to add to the existing opinion. Positive values improve relations,
## negative values worsen them. Applied via [method CovenSystem.change_opinion].
@export var delta: int = 0
