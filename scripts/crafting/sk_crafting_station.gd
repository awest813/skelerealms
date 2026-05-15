class_name SKCraftingStation
extends Node
## Abstract base class for crafting stations.
##
## Attach to any scene node (a world object, NPC, etc.) to give it crafting
## capability. Register [SKRecipe] resources in [member recipes], then call
## [method craft] from your game's interaction handler.
##
## Override [method _on_craft_success] and [method _on_craft_fail] for
## game-specific feedback (animations, sounds, UI popups, etc.).
##
## ## Minimal setup
## 1. Add a node that extends [SKCraftingStation] to your crafting table scene.
## 2. Assign [SKRecipe] resources to [member recipes].
## 3. In your interaction code call [code]station.craft(recipe_id, crafter_entity)[/code].
##
## ## Extending
## ```gdscript
## class_name MyForge
## extends SKCraftingStation
##
## func _on_craft_success(recipe: SKRecipe, crafter: SKEntity) -> void:
##     $AnimationPlayer.play("forge_spark")
##     SoundManager.play_at("anvil_clang", global_position)
## ```


## All recipes available at this station.
@export var recipes: Array[SKRecipe] = []

## Emitted when a craft succeeds. [param crafter] is the entity that performed it.
signal craft_succeeded(recipe: SKRecipe, crafter: SKEntity)
## Emitted when a craft fails (missing ingredients or skill).
signal craft_failed(recipe: SKRecipe, reason: StringName, crafter: SKEntity)


## Attempt to craft [param recipe_id]. Returns [code]true[/code] on success.
## [param crafter] must have an [InventoryComponent].
func craft(recipe_id: StringName, crafter: SKEntity) -> bool:
	var recipe := get_recipe(recipe_id)
	if not recipe:
		push_warning("SKCraftingStation: recipe '%s' not found." % recipe_id)
		return false

	var inventory := crafter.get_component("InventoryComponent") as InventoryComponent
	if not inventory:
		craft_failed.emit(recipe, &"no_inventory", crafter)
		return false

	# Skill check
	var skills := crafter.get_component("AttributesComponent") as AttributesComponent
	if skills and not recipe.meets_skill_requirement(skills):
		craft_failed.emit(recipe, &"skill_too_low", crafter)
		_on_craft_fail(recipe, crafter)
		return false

	# Ingredient check
	if not recipe.can_craft(inventory):
		craft_failed.emit(recipe, &"missing_ingredients", crafter)
		_on_craft_fail(recipe, crafter)
		return false

	# Consume ingredients
	_consume_ingredients(recipe, inventory)

	# Spawn output items and add to crafter's inventory
	_deliver_output(recipe, crafter, inventory)

	craft_succeeded.emit(recipe, crafter)
	_on_craft_success(recipe, crafter)
	return true


## Return all recipes the crafter can currently make.
func get_available_recipes(crafter: SKEntity) -> Array[SKRecipe]:
	var inventory := crafter.get_component("InventoryComponent") as InventoryComponent
	var skills := crafter.get_component("AttributesComponent") as AttributesComponent
	var available: Array[SKRecipe] = []
	for r in recipes:
		if inventory and r.can_craft(inventory):
			if skills and not r.meets_skill_requirement(skills):
				continue
			available.append(r)
	return available


## Return a recipe by id, or null.
func get_recipe(recipe_id: StringName) -> SKRecipe:
	for r in recipes:
		if r.id == recipe_id:
			return r
	return null


## Called after a successful craft. Override for effects.
func _on_craft_success(_recipe: SKRecipe, _crafter: SKEntity) -> void:
	pass


## Called after a failed craft. Override for effects.
func _on_craft_fail(_recipe: SKRecipe, _crafter: SKEntity) -> void:
	pass


func _consume_ingredients(recipe: SKRecipe, inventory: InventoryComponent) -> void:
	for form_id: StringName in recipe.ingredients:
		var needed: int = recipe.ingredients[form_id]
		var consumed := 0
		var to_remove: Array[String] = []
		for ref_id: String in inventory.inventory:
			if consumed >= needed:
				break
			var entity := SKEntityManager.instance.get_entity(StringName(ref_id)) if SKEntityManager.instance else null
			if entity and entity.form_id == form_id:
				to_remove.append(ref_id)
				consumed += 1
		for ref_id in to_remove:
			inventory.remove_from_inventory(ref_id)


func _deliver_output(recipe: SKRecipe, crafter: SKEntity, inventory: InventoryComponent) -> void:
	if not SKEntityManager.instance:
		push_warning("SKCraftingStation: SKEntityManager not available; cannot deliver output for recipe '%s'." % recipe.id)
		return
	for i in recipe.output_count:
		# Instantiate the output entity from its template (form_id == scene file name).
		var new_id := SKEntityManager.instance.create_entity(recipe.output_item)
		if new_id != &"":
			inventory.add_to_inventory(new_id)
