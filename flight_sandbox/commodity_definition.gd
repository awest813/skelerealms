extends Resource
## Immutable trade-good template. Prices and stock live per station in
## MarketService; this resource only carries identity and baseline data.

## Stable id used in cargo dicts, saves, and missions (e.g. &"ore").
@export var id := &""
## HUD display name.
@export var display_name := ""
## Reference price; stations quote fixed markups/discounts off this.
@export var base_price := 10
## Flavor line for market/mission UI.
@export var description := ""
