class_name WorldValidator
extends RefCounted
## Static verify-world checks for the Creation Kit story: dangling doors,
## cell layout, and content budgets. Pure functions over explicit inputs —
## no project settings or autoloads read — so editor tooling and content
## tests drive them identically. Issue dicts carry "type", "detail", and
## (for scene problems) "node" path strings.


## Every Door under root must name a destination world present in worlds
## (the id->path map, same shape as WorldLoader.world_paths).
static func validate_doors(world_root: Node, worlds: Dictionary) -> Array:
	var issues: Array = []
	var doors := world_root.find_children("*", "Door", true, false)
	for door in doors:
		var path := str((door as Node).get_path())
		var dest = (door as Door).destination_instance
		if dest == null:
			issues.append({"type": "door_without_destination", "node": path, "detail": "Door has no destination instance."})
			continue
		if String(dest.world).is_empty():
			issues.append({"type": "door_without_world", "node": path, "detail": "Door destination names no world."})
		elif not worlds.has(String(dest.world)):
			issues.append({"type": "door_unknown_world", "node": path, "detail": "Door destination world '%s' is not a known world." % dest.world})
	return issues


## Cell layout sanity, delegated to the worldspace definition.
static func validate_cells(worldspace: WorldspaceDefinition) -> Array:
	if worldspace == null:
		return [{"type": "missing_worldspace", "detail": "No worldspace provided."}]
	return worldspace.validate()


## Content budgets: counts of meshes and lights under root against limits
## ({max_meshes: int, max_lights: int}; missing keys mean no limit).
static func check_budgets(world_root: Node, limits: Dictionary = {}) -> Array:
	var issues: Array = []
	if limits.has("max_meshes"):
		var meshes := world_root.find_children("*", "MeshInstance3D", true, false).size()
		if meshes > int(limits["max_meshes"]):
			issues.append({"type": "over_mesh_budget", "detail": "Meshes %d exceed budget %d." % [meshes, int(limits["max_meshes"])]})
	if limits.has("max_lights"):
		var lights := world_root.find_children("*", "Light3D", true, false).size()
		if lights > int(limits["max_lights"]):
			issues.append({"type": "over_light_budget", "detail": "Lights %d exceed budget %d." % [lights, int(limits["max_lights"])]})
	return issues


## All three suites at once: doors, then cells, then budgets.
static func validate_world(world_root: Node, worlds: Dictionary, worldspace: WorldspaceDefinition = null, budgets: Dictionary = {}) -> Array:
	var issues: Array = []
	issues.append_array(validate_doors(world_root, worlds))
	if worldspace:
		issues.append_array(validate_cells(worldspace))
	issues.append_array(check_budgets(world_root, budgets))
	return issues
