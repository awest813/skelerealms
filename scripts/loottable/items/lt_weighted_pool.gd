class_name SKLTWeightedPool
extends SKLootTableItem


## Picks [member picks] item(s) from [SKLTWeightedItem] children using weight-based probability.
##
## Each child's [member SKLTWeightedItem.weight] controls its relative chance of being selected:
## a child with weight 3.0 is three times as likely to be chosen as one with weight 1.0.
## Inspired by the Lootie library (https://github.com/ninetailsrabbit/lootie).


## Number of items to pick from the pool.
@export_range(1, 100, 1, "or_greater") var picks: int = 1

## When false (default), the same child cannot be picked more than once per resolve call.
@export var allow_duplicates: bool = false


func resolve() -> SKLootTable.LootTableResult:
	var pool: Array[SKLTWeightedItem] = []
	for c: Node in get_children():
		if c is SKLTWeightedItem and c.weight > 0.0:
			pool.append(c as SKLTWeightedItem)

	if pool.is_empty():
		return SKLootTable.LootTableResult.new()

	var output := SKLootTable.LootTableResult.new()
	var remaining: Array[SKLTWeightedItem] = pool.duplicate()
	var n: int = picks if allow_duplicates else mini(picks, remaining.size())

	for _i: int in n:
		if remaining.is_empty():
			break
		var selected: SKLTWeightedItem = _pick_weighted(remaining)
		output.concat(selected.resolve())
		if not allow_duplicates:
			remaining.erase(selected)

	return output


func _pick_weighted(pool: Array[SKLTWeightedItem]) -> SKLTWeightedItem:
	var total: float = 0.0
	for item: SKLTWeightedItem in pool:
		total += item.weight

	var roll: float = randf() * total
	var accum: float = 0.0
	for item: SKLTWeightedItem in pool:
		accum += item.weight
		if roll <= accum:
			return item

	return pool[-1]
