extends RefCounted
## One station's commodity market: finite stock, deterministic prices.
##
## Pure logic, no scene-tree access — trade functions take the player's
## wallet/cargo dicts and validate everything before committing, so a
## rejected trade leaves funds, cargo, and stock all unchanged.

enum TradeResult { OK, BAD_QUANTITY, NO_FUNDS, NO_STOCK, NO_CARGO, NO_SPACE, UNKNOWN_GOOD }

## Commodity id → units on the shelf.
var stock := {}
## Commodity id → price per unit in credits (buy and sell use the same quote).
var prices := {}
## Commodity id → fully-stocked quantity; restocking drifts back toward this.
var max_stock := {}


## Build a market from parallel commodity/quantity/price arrays.
static func with_offers(ids: Array, quantities: Array, price_list: Array) -> RefCounted:
	var script := load("res://market_service.gd")
	var market: RefCounted = script.new()
	for i in ids.size():
		market.stock[ids[i]] = int(quantities[i])
		market.max_stock[ids[i]] = int(quantities[i])
		market.prices[ids[i]] = int(price_list[i])
	return market


## Drift every quote by up to pct (up or down), floored at 1 cr.
func drift(rng: RandomNumberGenerator, pct: float) -> void:
	for good in prices:
		var change := rng.randf_range(-pct, pct)
		prices[good] = maxi(1, int(round(float(prices[good]) * (1.0 + change))))


## Replenish each shelf toward its opening stock by frac of the deficit.
func restock(rng: RandomNumberGenerator, frac := 0.5) -> void:
	for good in max_stock:
		var want := int(max_stock[good])
		var have := int(stock.get(good, 0))
		if have < want:
			stock[good] = have + maxi(1, int(round((want - have) * frac)) + rng.randi_range(0, 1))


func quote(good: StringName) -> int:
	return int(prices.get(good, -1))


func stock_of(good: StringName) -> int:
	return int(stock.get(good, 0))


## Buy qty units: credits cover price, shelf has stock, hold has space.
## price_mult scales the unit quote (faction favor < 1 is a discount).
## Commits wallet, cargo, and stock together or not at all.
func buy(good: StringName, qty: int, wallet: Dictionary, cargo: Dictionary, capacity: int, price_mult := 1.0) -> int:
	if qty <= 0:
		return TradeResult.BAD_QUANTITY
	if not prices.has(good):
		return TradeResult.UNKNOWN_GOOD
	var unit := maxi(1, int(round(float(prices[good]) * price_mult)))
	var cost: int = unit * qty
	if int(wallet.get(&"credits", 0)) < cost:
		return TradeResult.NO_FUNDS
	if int(stock.get(good, 0)) < qty:
		return TradeResult.NO_STOCK
	if _cargo_total(cargo) + qty > capacity:
		return TradeResult.NO_SPACE
	wallet[&"credits"] = int(wallet[&"credits"]) - cost
	cargo[good] = int(cargo.get(good, 0)) + qty
	stock[good] = int(stock[good]) - qty
	return TradeResult.OK


## Sell qty units from the hold back to the shelf. price_mult > 1 favors
## the seller (faction favor).
func sell(good: StringName, qty: int, wallet: Dictionary, cargo: Dictionary, price_mult := 1.0) -> int:
	if qty <= 0:
		return TradeResult.BAD_QUANTITY
	if not prices.has(good):
		return TradeResult.UNKNOWN_GOOD
	if int(cargo.get(good, 0)) < qty:
		return TradeResult.NO_CARGO
	var payout: int = maxi(1, int(round(float(prices[good]) * price_mult))) * qty
	cargo[good] = int(cargo[good]) - qty
	if int(cargo[good]) <= 0:
		cargo.erase(good)
	stock[good] = int(stock.get(good, 0)) + qty
	wallet[&"credits"] = int(wallet.get(&"credits", 0)) + payout
	return TradeResult.OK


static func _cargo_total(cargo: Dictionary) -> int:
	var total := 0
	for good in cargo:
		total += int(cargo[good])
	return total
