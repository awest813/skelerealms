extends RefCounted
## Bounded mission instances: one delivery template, one bounty template.
##
## Pure logic, no scene-tree access. Progress enters through on_dock() and
## on_kill(); rewards pay exactly once via the claimed flag. Mission dicts
## use plain Strings/ints/bools only so they survive JSON saves untouched.

enum ClaimResult { OK, NOT_COMPLETE, ALREADY_CLAIMED, UNKNOWN }

## Active and finished-but-unclaimed missions.
var missions: Array = []


static func delivery_mission(id: String, commodity: String, qty: int, dest_system: String, dest_name: String, reward: int) -> Dictionary:
	return {
		"id": id, "kind": "delivery", "commodity": commodity, "qty": qty,
		"dest": dest_system, "dest_name": dest_name, "reward": reward,
		"complete": false, "claimed": false,
	}


static func bounty_mission(id: String, target_name: String, required_kills: int, reward: int) -> Dictionary:
	return {
		"id": id, "kind": "bounty", "target": target_name, "qty": required_kills,
		"kills": 0, "reward": reward, "complete": false, "claimed": false,
	}


## Accept a mission instance. Rejects duplicate ids so rewards stay bounded.
func accept(mission: Dictionary) -> bool:
	for existing in missions:
		if str(existing.get("id", "")) == str(mission.get("id", "")):
			return false
	missions.append(mission.duplicate())
	return true


func get_mission(id: String) -> Dictionary:
	for mission in missions:
		if str(mission.get("id", "")) == id:
			return mission
	return {}


## Check delivery completion on docking. Consumes the goods and returns the
## ids that completed this call.
func on_dock(system_id: String, cargo: Dictionary) -> Array:
	var completed := []
	for mission in missions:
		if str(mission.get("kind", "")) != "delivery":
			continue
		if bool(mission.get("complete", false)):
			continue
		if str(mission.get("dest", "")) != system_id:
			continue
		var need := int(mission.get("qty", 0))
		var have := int(cargo.get(StringName(str(mission.get("commodity", ""))), 0))
		if have < need:
			continue
		var key := StringName(str(mission.get("commodity", "")))
		cargo[key] = have - need
		if int(cargo[key]) <= 0:
			cargo.erase(key)
		mission["complete"] = true
		completed.append(str(mission.get("id", "")))
	return completed


## Record a drone kill. Returns bounty ids that completed this call.
func on_kill() -> Array:
	var completed := []
	for mission in missions:
		if str(mission.get("kind", "")) != "bounty":
			continue
		if bool(mission.get("complete", false)):
			continue
		mission["kills"] = int(mission.get("kills", 0)) + 1
		if int(mission["kills"]) >= int(mission.get("qty", 1)):
			mission["complete"] = true
			completed.append(str(mission.get("id", "")))
	return completed


## Pay a completed mission's reward. Each instance pays at most once.
func claim(id: String, wallet: Dictionary) -> int:
	var mission := get_mission(id)
	if mission.is_empty():
		return ClaimResult.UNKNOWN
	if bool(mission.get("claimed", false)):
		return ClaimResult.ALREADY_CLAIMED
	if not bool(mission.get("complete", false)):
		return ClaimResult.NOT_COMPLETE
	mission["claimed"] = true
	wallet[&"credits"] = int(wallet.get(&"credits", 0)) + int(mission.get("reward", 0))
	return ClaimResult.OK


## Generate board offers: deliveries of random goods to linked systems and
## drone bounties, with rewards scaled from quantity and base prices.
## Deterministic for a given RNG state, so tests can pin the economy.
static func generate(rng: RandomNumberGenerator, links: Array, link_names: Dictionary, goods: Array, base_prices: Dictionary) -> Array:
	var offers := []
	if links.is_empty() or goods.is_empty():
		return offers
	var good: String = str(goods[rng.randi_range(0, goods.size() - 1)])
	var qty := rng.randi_range(3, 8)
	var dest: String = str(links[rng.randi_range(0, links.size() - 1)])
	var reward := 50 + int(round(qty * float(base_prices.get(good, 10.0)) * 1.5))
	offers.append(delivery_mission("gen_d_%d" % rng.randi(), good, qty, dest, str(link_names.get(dest, dest)), reward))
	var kills := rng.randi_range(1, 3)
	offers.append(bounty_mission("gen_b_%d" % rng.randi(), "Hostile drone", kills, 120 * kills + 50))
	return offers


## Follow-up chain: claiming the ore delivery angers whoever hit the route.
## Returns the next template, or {} when the chain ends. The game layer
## accepts it so chains stay bounded and pay-once like everything else.
static func follow_up(parent_id: String) -> Dictionary:
	if parent_id == "delivery_ore":
		return bounty_mission("ore_route_ambush", "Route raider", 2, 350)
	return {}


## One-line tracker text for the HUD, empty when nothing is active.
func tracker_text() -> String:
	var parts: PackedStringArray = []
	for mission in missions:
		if bool(mission.get("claimed", false)):
			continue
		if str(mission.get("kind", "")) == "delivery":
			parts.append("DELIVER %d %s → %s" % [int(mission.get("qty", 0)), str(mission.get("commodity", "")).to_upper(), str(mission.get("dest_name", "")).to_upper()])
		else:
			parts.append("BOUNTY %d/%d" % [int(mission.get("kills", 0)), int(mission.get("qty", 0))])
	return "   ".join(parts)
