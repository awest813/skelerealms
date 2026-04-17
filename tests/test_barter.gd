## Integration tests for BarterSystem.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## These tests cover the pure-logic parts of BarterSystem: haggle arithmetic,
## sell/buy toggling, and modifier tracking.  The accept_barter path requires
## SKEntityManager and scene-tree-aware components; those are covered by
## end-to-end game tests rather than unit tests here.
extends GutTest


# ── Stubs ────────────────────────────────────────────────────────────────


## Minimal inventory stub: just holds a currencies dict and a parent_entity stub.
class StubInventory extends Node:
	var currencies: Dictionary = {}
	var parent_entity: StubEntity = null

	func _init() -> void:
		name = "InventoryComponent"

	func add_money(_amount: int, _currency: StringName) -> void:
		currencies[_currency] = currencies.get(_currency, 0) + _amount

	func remove_money(_amount: int, _currency: StringName) -> void:
		currencies[_currency] = currencies.get(_currency, 0) - _amount


class StubEntity extends Node:
	var _components: Dictionary = {}

	func get_component(comp_name: String) -> Node:
		return _components.get(comp_name, null)


## Minimal shop stub: just exposes haggle_tolerance and other barter fields.
class StubShop extends Node:
	var haggle_tolerance: float = 0.3
	var whitelist: Array[StringName] = []
	var blacklist: Array[StringName] = []
	var accept_stolen: bool = true

	func _init() -> void:
		name = "ShopComponent"


# ── Helpers ────────────────────────────────────────────────────────────────


func _make_barter_system(max_attempts: int = 3) -> BarterSystem:
	var bs := BarterSystem.new()
	bs.max_haggle_attempts = max_attempts
	add_child(bs)
	return bs


func _start_barter_with_shop(bs: BarterSystem, tolerance: float = 0.3) -> void:
	var vendor := StubInventory.new()
	var customer := StubInventory.new()
	vendor.currencies[&"snails"] = 10000
	customer.currencies[&"snails"] = 10000
	add_child(vendor)
	add_child(customer)

	# Inject a stub shop onto vendor's entity
	var vendor_entity := StubEntity.new()
	var stub_shop := StubShop.new()
	stub_shop.haggle_tolerance = tolerance
	vendor_entity._components["ShopComponent"] = stub_shop
	vendor.parent_entity = vendor_entity
	add_child(vendor_entity)
	add_child(stub_shop)

	# Directly call start_barter internals since InventoryComponent.parent_entity
	# is now set to our stub.
	bs.current_transaction = Transaction.new(vendor as InventoryComponent, customer as InventoryComponent)
	bs._haggle_modifier = 1.0
	bs._haggle_attempts = 0
	bs._current_shop = stub_shop as ShopComponent


# ── Haggle — modifier arithmetic ─────────────────────────────────────────


func test_initial_haggle_modifier_is_one() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs, 0.3)
	assert_eq(bs.get_haggle_modifier(), 1.0)


func test_successful_haggle_reduces_modifier() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs, 0.3)
	# tolerance = 0.3, threshold = 0.7; skill_factor = 1.0 (above threshold)
	var succeeded := bs.haggle(1.0)
	assert_true(succeeded)
	assert_lt(bs.get_haggle_modifier(), 1.0)


func test_failed_haggle_does_not_reduce_modifier() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs, 0.3)
	# tolerance = 0.3, threshold = 0.7; skill_factor = 0.0 (below threshold)
	var modifier_before := bs.get_haggle_modifier()
	var succeeded := bs.haggle(0.0)
	assert_false(succeeded)
	assert_eq(bs.get_haggle_modifier(), modifier_before)


func test_modifier_never_goes_below_one_minus_tolerance() -> void:
	var bs := _make_barter_system(10)
	_start_barter_with_shop(bs, 0.3)
	# Haggle many times
	for i in range(10):
		bs.haggle(1.0)
	var floor_val := 1.0 - 0.3
	assert_ge(bs.get_haggle_modifier(), floor_val - 0.0001,
		"Modifier should not drop below 1 - tolerance.")


func test_haggle_capped_at_max_attempts() -> void:
	var bs := _make_barter_system(2)
	_start_barter_with_shop(bs, 0.9)
	bs.haggle(1.0)
	bs.haggle(1.0)
	# Third attempt must fail due to max_haggle_attempts
	var succeeded := bs.haggle(1.0)
	assert_false(succeeded)


func test_haggle_zero_tolerance_always_fails() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs, 0.0)
	var succeeded := bs.haggle(1.0)
	assert_false(succeeded)
	assert_eq(bs.get_haggle_modifier(), 1.0)


func test_haggle_without_active_transaction_returns_false() -> void:
	var bs := _make_barter_system()
	# No transaction started
	var ok := bs.haggle(1.0)
	assert_false(ok)


# ── sell_item / buy_item toggling ─────────────────────────────────────────


func test_sell_item_adds_to_selling_list() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs)
	var ok := bs.sell_item("item_a")
	assert_true(ok)
	assert_has(bs.current_transaction.selling, "item_a")


func test_sell_item_cancels_pending_buy() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs)
	bs.buy_item("item_a")
	assert_has(bs.current_transaction.buying, "item_a")
	# Selling the same item should cancel the buy
	var ok := bs.sell_item("item_a")
	assert_true(ok)
	assert_does_not_have(bs.current_transaction.buying, "item_a")
	assert_does_not_have(bs.current_transaction.selling, "item_a")


func test_sell_item_twice_returns_false() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs)
	bs.sell_item("item_b")
	var ok := bs.sell_item("item_b")
	assert_false(ok)


func test_buy_item_adds_to_buying_list() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs)
	var ok := bs.buy_item("item_c")
	assert_true(ok)
	assert_has(bs.current_transaction.buying, "item_c")


func test_buy_item_cancels_pending_sell() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs)
	bs.sell_item("item_c")
	assert_has(bs.current_transaction.selling, "item_c")
	# Buying the same item should cancel the sell
	var ok := bs.buy_item("item_c")
	assert_true(ok)
	assert_does_not_have(bs.current_transaction.selling, "item_c")
	assert_does_not_have(bs.current_transaction.buying, "item_c")


func test_buy_item_twice_returns_false() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs)
	bs.buy_item("item_d")
	var ok := bs.buy_item("item_d")
	assert_false(ok)


func test_sell_without_transaction_returns_false() -> void:
	var bs := _make_barter_system()
	var ok := bs.sell_item("item_e")
	assert_false(ok)


func test_buy_without_transaction_returns_false() -> void:
	var bs := _make_barter_system()
	var ok := bs.buy_item("item_e")
	assert_false(ok)


# ── cancel_barter ────────────────────────────────────────────────────────


func test_cancel_barter_clears_transaction() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs)
	assert_not_null(bs.current_transaction)
	bs.cancel_barter()
	assert_null(bs.current_transaction)


func test_cancel_barter_emits_signals() -> void:
	var bs := _make_barter_system()
	_start_barter_with_shop(bs)
	watch_signals(bs)
	bs.cancel_barter()
	assert_signal_emitted(bs, "ended_barter")
	assert_signal_emitted(bs, "cancelled_barter")


func test_cancel_when_no_transaction_does_not_crash() -> void:
	var bs := _make_barter_system()
	# Should be a no-op
	bs.cancel_barter()
	assert_null(bs.current_transaction)
