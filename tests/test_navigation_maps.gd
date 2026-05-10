## Unit tests for [SKNavigationMaps] (TerraBrush / world navigation map resolution).
extends GutTest


func test_primary_group_selects_tagged_region() -> void:
	var tagged := NavigationRegion3D.new()
	tagged.add_to_group(SKNavigationMaps.PRIMARY_NAV_REGION_GROUP)
	var other := NavigationRegion3D.new()
	add_child_autofree(tagged)
	add_child_autofree(other)
	var probe := Node.new()
	add_child_autofree(probe)
	await get_tree().process_frame
	var want := NavigationServer3D.region_get_navigation_map(tagged.get_rid())
	var got := SKNavigationMaps.get_navigation_map_rid(probe)
	assert_eq(got, want, "Tagged primary region should win over an untagged sibling.")


func test_world_loader_fallback_finds_region_under_loaded_world() -> void:
	var wl := Node.new()
	wl.name = "WorldLoader"
	var world := Node3D.new()
	var region := NavigationRegion3D.new()
	world.add_child(region)
	wl.add_child(world)
	add_child_autofree(wl)
	var probe := Node.new()
	add_child_autofree(probe)
	await get_tree().process_frame
	var want := NavigationServer3D.region_get_navigation_map(region.get_rid())
	var got := SKNavigationMaps.get_navigation_map_rid(probe)
	assert_eq(got, want, "Resolver should find NavigationRegion3D under WorldLoader's active child.")
