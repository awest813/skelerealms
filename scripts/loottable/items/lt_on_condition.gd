class_name SKLTOnCondition
extends SKLootTableItem


@export_multiline var condition:String = ""
var items:SKLootTable


func _ready() -> void:
	if get_child_count() == 0:
		push_error("SKLTOnCondition: requires at least one child node.")
		return
	items = get_child(0)


func resolve() -> SKLootTable.LootTableResult:
	if items == null or not _check_condition():
		return SKLootTable.LootTableResult.new()
	
	var o:SKLootTable.LootTableResult = SKLootTable.LootTableResult.new()
	for i:SKLootTableItem in items.items:
		o.concat(i.resolve())
	return o


func _check_condition() -> bool:
	if condition == "":
		return false
	
	var e:Expression = Expression.new()
	
	var err:int = e.parse(condition)
	if not err == 0:
		push_error("Loot table script error: %s" % e.get_error_text())
		return false
	
	var res = e.execute()
	
	if e.has_execute_failed():
		push_error("Loot table script execution failed.")
		return false
	if res == null:
		return false
	if res is bool:
		return res
	else:
		push_warning("Loot table script warning: Expression should return boolean value.")
		return true
