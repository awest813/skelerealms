class_name SKRecipe
extends Resource
## Defines a single crafting recipe: required ingredients and the output item.
##
## Recipes are data-only resources. The crafting logic lives in [SKCraftingStation].
##
## ## Usage
## Create a [SKRecipe] `.tres` file and fill in the properties:
## ```
## id       = &"iron_sword"
## ingredients = { &"iron_ingot": 2, &"wood": 1 }
## output_item = &"iron_sword"
## output_count = 1
## required_skill = &"smithing"
## required_skill_level = 25
## ```


## Unique identifier for this recipe (e.g. &"iron_sword").
@export var id: StringName = &""

## Human-readable name for display in the crafting UI.
@export var display_name: String = ""

## Required ingredients. Keys are item [b]form IDs[/b] (StringName) —
## the template/type ID of the item (see [member SKEntity.form_id]);
## values are the required quantity (int).
@export var ingredients: Dictionary[StringName, int] = {}

## The entity reference ID of the item produced by this recipe.
@export var output_item: StringName = &""

## How many copies of [member output_item] are produced per craft.
@export var output_count: int = 1

## Optional: skill required to craft (e.g. &"smithing"). Empty = no skill required.
@export var required_skill: StringName = &""

## Minimum skill level required ([member required_skill] must be set).
@export var required_skill_level: int = 0

## Optional: gameplay tags for filtering in the UI (e.g. &"weapon", &"armor").
@export var tags: Array[StringName] = []


## Return true if [param inventory] contains all required ingredients.
func can_craft(inventory: InventoryComponent) -> bool:
	for item_id: StringName in ingredients:
		var required_count: int = ingredients[item_id]
		if not _has_enough(inventory, item_id, required_count):
			return false
	return true


## Return true if the entity has the required skill level.
## If no skill is required this always returns true.
func meets_skill_requirement(skills: AttributesComponent) -> bool:
	if required_skill == &"" or required_skill_level <= 0:
		return true
	# AttributesComponent may store skills or use SkillsComponent; try a generic get.
	if skills.has_method("get_attribute"):
		return int(skills.call("get_attribute", required_skill)) >= required_skill_level
	return true


## Return a human-readable string listing which ingredients are missing.
func describe_missing(inventory: InventoryComponent) -> String:
	var missing: PackedStringArray = []
	for item_id: StringName in ingredients:
		var required_count: int = ingredients[item_id]
		if not _has_enough(inventory, item_id, required_count):
			missing.append("%s ×%d" % [item_id, required_count])
	return ", ".join(missing)


func _has_enough(inventory: InventoryComponent, form_id: StringName, count: int) -> bool:
	var found := 0
	for ref_id: String in inventory.inventory:
		var entity := SKEntityManager.instance.get_entity(StringName(ref_id)) if SKEntityManager.instance else null
		if entity and entity.form_id == form_id:
			found += 1
			if found >= count:
				return true
	return found >= count
