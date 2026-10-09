class_name QuestAlias
extends Resource
## A named reference slot on a quest, filled with a live entity ref-ID when
## the quest activates — the Creation-Kit-style alias mechanic.
##
## Use aliases instead of hardcoded ref-IDs whenever the target should be
## chosen at runtime: the nearest NPC of a faction, a procedurally picked
## mark, anyone except the quest giver. Nodes reference an alias with a
## [code]{AliasId}[/code] placeholder in
## [member QuestNodeDefinition.target_id]; the engine resolves it against
## the fills stored in quest runtime state when matching events.
##
## Filling is deterministic: candidates come from the engine's
## [member QuestGraphEngine.entity_finder] in registry order, and nearest
## picks break ties by distance, so the same world state always fills the
## same refs. Fills persist in save snapshots.


## Alias name, e.g. &"BanditLeader". Referenced as "{BanditLeader}".
@export var id: StringName
## When true, the quest still activates if nothing matches. The placeholder
## then never resolves and simply matches no events.
@export var optional: bool = false
## When true, only entities with an NPCComponent are candidates.
@export var must_be_npc: bool = true
## Only entities in this coven are candidates. Empty means any coven.
@export var required_coven: StringName
## Only entities with this form_id are candidates. Empty means any form.
@export var required_form: StringName
## Ref-IDs that must never fill this alias (e.g. the quest giver).
@export var exclude_ids: Array[StringName] = []
## Nearest-pick anchor: &"player", another (earlier) alias id, or empty for
## first-registry-match. Anchors to later aliases fail activation — the
## quest editor's alias validation flags them.
@export var nearest_to: StringName
