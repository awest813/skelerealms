class_name Coven
extends Resource
## Analagous to a Faction in creation kit games, where a Coven is a group of Entities that behave a certain way.
## Entities must have a [CovensComponent] to be a part of a coven.
## Entities are automatically added to a group with the coven's ID when they are a part of a coven, so to get all entities part of a coven, you can get all of group.
## Unlike Creation Kit, Entties are assigned to a coven on the SKEntity side- the Coven just holds information.
## To give them a default response to the player, create a "Player" coven, and give them a default reaction to that.


## Disposition thresholds (ported from Camelot's FactionEngine).
## These determine how the faction views entities based on opinion score.
enum Disposition { HOSTILE, NEUTRAL, FRIENDLY, ALLIED }

## Default threshold constants. Override per-coven via the exports below.
const DEFAULT_HOSTILE_BELOW: int = -25
const DEFAULT_FRIENDLY_AT: int = 25
const DEFAULT_ALLIED_AT: int = 60


@export_category("Information")
## ID for this coven. Also used as a key in translations. See [member coven_name].
@export var coven_id:StringName
## The opinion this coven has of other covens. The dictionary shopuld be of StringName:int.
@export var other_coven_opinions:Dictionary[StringName, int] = {}
## Whether the player should see this in the menu if they are a part of the coven.
@export var hidden_from_player:bool
## The ranks of this coven. Shape is int:String, where key is the rank, and value is the translation key for the rank.
@export var ranks:Dictionary[int, String] = {}
@export_category("Crime")
## Whether members of this coven ignore crimes perpetrated to other members.
@export var ignore_crimes_against_others:bool = false
## Whether members care abourt crimes done against their own members.
@export var ignore_crimes_against_members:bool = false
## Whether this coven remembers crimes done against it.
@export var track_crime:bool = true
@export_category("Disposition Thresholds")
## Opinion score below which an entity is considered hostile.
@export var hostile_below: int = DEFAULT_HOSTILE_BELOW
## Opinion score at or above which an entity is considered friendly.
@export var friendly_at: int = DEFAULT_FRIENDLY_AT
## Opinion score at or above which an entity is considered allied.
@export var allied_at: int = DEFAULT_ALLIED_AT


## Translated coven name.
var coven_name:String:
	get:
		return tr(coven_id)


## Get the translated name of a rank.
func rank_name(rank:int) -> String:
	return tr(ranks[rank]) if ranks.has(rank) else ""


## Returns a list of the opinions this coven has of a list of other covens.
func get_coven_opinions(covens:Array) -> Array[int]:
	var opinion_list:Array[int] = []
	
	for coven in covens:
		if other_coven_opinions.has(coven):
			opinion_list.append(other_coven_opinions[coven])
		else:
			opinion_list.append(0)
	
	return opinion_list


## Get the disposition of this coven towards a given opinion score.
## Returns one of [enum Disposition]: HOSTILE, NEUTRAL, FRIENDLY, or ALLIED.
func get_disposition(opinion: int) -> Disposition:
	if opinion < hostile_below:
		return Disposition.HOSTILE
	if opinion >= allied_at:
		return Disposition.ALLIED
	if opinion >= friendly_at:
		return Disposition.FRIENDLY
	return Disposition.NEUTRAL


## Get the disposition name as a string (for debug / UI).
func get_disposition_name(opinion: int) -> String:
	match get_disposition(opinion):
		Disposition.HOSTILE:
			return "hostile"
		Disposition.FRIENDLY:
			return "friendly"
		Disposition.ALLIED:
			return "allied"
		_:
			return "neutral"


## Get the crime opinion modifier for an entity against this coven.
## The formula is [code]max_crime_severity * -10[/code].
func get_crime_modifier(who:StringName) -> int:
	return CrimeMaster.max_crime_severity(who, coven_id) * -10


func get_debug_info() -> String:
	return """
[b]%s[/b]
	Opinions: %s
	Hidden from player: %s
	Ranks: %s
	Ignores crimes against others: %s
	Ignores crimes against members: %s
	Track Crime: %s
	Hostile below: %s
	Friendly at: %s
	Allied at: %s
	""" % [
		coven_id,
		JSON.stringify(other_coven_opinions),
		hidden_from_player,
		JSON.stringify(ranks),
		ignore_crimes_against_others,
		ignore_crimes_against_members,
		track_crime,
		hostile_below,
		friendly_at,
		allied_at
	]
