class_name SKLTWeightedItem
extends SKLootTableItem


## A single entry in an [SKLTWeightedPool].
## Higher [member weight] values make this item more likely to be chosen.


@export var data: PackedScene
@export_range(0.0, 100.0, 0.01, "or_greater") var weight: float = 1.0


func resolve() -> SKLootTable.LootTableResult:
	if data == null:
		return SKLootTable.LootTableResult.new()
	return SKLootTable.LootTableResult.new([data], {})
