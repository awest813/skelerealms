class_name SKNavigationMaps
extends RefCounted
## Resolves [NavigationServer3D] map [RID]s for loaded worlds.
##
## Worlds that bake navigation meshes against TerraBrush collision still register
## those meshes on a [NavigationRegion3D]. Agents must use that region's map —
## not [code]NavigationServer3D.get_maps()[0][/code], which can point at a stale
## or empty map depending on registration order.
##
## Tag one region per world with group [code]sk_primary_navigation_region[/code]
## (see [code]world_template.tscn[/code]). This resolver falls back to ancestor
## regions, the active [WorldLoader] world subtree, then the current scene.


const PRIMARY_NAV_REGION_GROUP := &"sk_primary_navigation_region"


static func get_navigation_map_rid(from_node: Node) -> RID:
	if from_node == null or from_node.get_tree() == null:
		return _fallback_default_map()

	var tree := from_node.get_tree()

	for n in tree.get_nodes_in_group(PRIMARY_NAV_REGION_GROUP):
		if n is NavigationRegion3D:
			return NavigationServer3D.region_get_navigation_map(n.get_rid())

	var walk: Node = from_node
	while walk:
		if walk is NavigationRegion3D:
			return NavigationServer3D.region_get_navigation_map(walk.get_rid())
		walk = walk.get_parent()

	var wl: Node = tree.root.find_child("WorldLoader", true, false)
	if wl and wl.get_child_count() > 0:
		var world_root: Node = wl.get_child(0)
		var region := world_root.find_child("NavigationRegion3D", true, false)
		if region is NavigationRegion3D:
			return NavigationServer3D.region_get_navigation_map(region.get_rid())

	var scene_root: Node = tree.current_scene if tree.current_scene else tree.root
	if scene_root:
		var found := scene_root.find_child("NavigationRegion3D", true, false)
		if found is NavigationRegion3D:
			return NavigationServer3D.region_get_navigation_map(found.get_rid())

	return _fallback_default_map()


static func _fallback_default_map() -> RID:
	var maps = NavigationServer3D.get_maps()
	if maps.is_empty():
		return RID()
	return maps[0]


static func find_terrabrush_node(tree: SceneTree) -> Node:
	if tree == null:
		return null

	if tree.current_scene:
		var hit := _find_node_by_class_name(tree.current_scene, "TerraBrush")
		if hit:
			return hit

	var wl: Node = tree.root.find_child("WorldLoader", true, false)
	if wl and wl.get_child_count() > 0:
		return _find_node_by_class_name(wl.get_child(0), "TerraBrush")

	return null


static func _find_node_by_class_name(node: Node, class_to_find: String) -> Node:
	if node.get_class() == class_to_find:
		return node
	for c in node.get_children():
		var found := _find_node_by_class_name(c, class_to_find)
		if found:
			return found
	return null
