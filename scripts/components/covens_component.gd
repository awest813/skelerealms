class_name CovensComponent
extends SKEntityComponent
## Allows an SKEntity to be part of a [Coven].
## Covens in this context are analagous to Bethesda games' Factions- groups of NPCs that behave in a similar way.
## Coven membership is also reflected in groups that the entity is in.


## IDs of covens this entity is a member of.
## This dictionary is of type StringName:Int, where key is the coven, and int is the rank of this member.
@export var covens:Dictionary[StringName, int] = {}


func _init(coven_list:Array[CovenRankData] = []) -> void:
	name = "CovensComponent"
	if coven_list.is_empty():
		return
	# Load rank info
	for crd in coven_list:
		#printe("Adding to coven %s" % crd.coven.coven_id)
		covens[crd.coven.coven_id] = crd.rank


func _ready() -> void:
	super._ready()
	# Add corresponding covens.
	for c in covens:
		parent_entity.add_to_group(c)


## Add this entity to a coven.
func add_to_coven(coven:StringName, rank:int = 1) -> void:
	covens[coven] = rank
	dirty = true
	parent_entity.add_to_group(coven)


## Remove this entity from the coven.
func remove_from_coven(coven:StringName) -> void:
	covens.erase(coven)
	dirty = true
	parent_entity.remove_from_group(coven)


## Whether the entity is in a coven or not.
func is_in_coven(coven:StringName) -> bool:
	return covens.has(coven)


## Get this entity's rank in a coven. Returns 0 if they aren't in the coven.
func get_coven_rank(coven:StringName) -> int:
	return covens[coven] if covens.has(coven) else 0


func save() -> Dictionary:
	dirty = false
	# Convert StringName keys to strings for JSON serialization
	var out := {}
	for c in covens:
		out[str(c)] = covens[c]
	return {
		"covens": out,
	}


func load_data(data:Dictionary) -> void:
	var coven_data = data.get("covens", null)
	if coven_data is Dictionary:
		covens = {}
		for c in coven_data:
			covens[StringName(c)] = int(coven_data[c])
		# Re-sync groups with loaded coven data
		if parent_entity:
			for c in covens:
				if not parent_entity.is_in_group(c):
					parent_entity.add_to_group(c)
	dirty = false
