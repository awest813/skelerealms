extends AIModule
## Crime report AI module. When an NPC witnesses a crime, it will report the crime
## to CrimeMaster and optionally confront the perpetrator.
##
## Ported from Camelot's Guard Challenge concept. Four response branches:
## - Pay fine: perpetrator pays the bounty
## - Serve jail time: perpetrator is sent to a jail point
## - Resist arrest: combat begins
## - Attempt persuasion: skill-check-based resolution
##
## The module emits signals and GOAP objectives so consuming games can attach
## custom behavior (dialogue, UI, animations) to the confrontation flow.


## Whether this NPC will report crimes committed against other covens' members.
@export var report_crimes_against_other_covens: bool = false
## Whether this NPC will attempt to confront the perpetrator after reporting.
@export var confront_perpetrator: bool = true
## Crime severity threshold below which this NPC will not confront.
## 0 means confront for any crime, 2 means only confront for assault or worse.
@export var confront_severity_threshold: int = 0


func _ready() -> void:
	CrimeMaster.crime_committed.connect(react.bind())


## React to a committed crime. If the perpetrator can be seen, the crime will be reported.
func react(crime: Crime, pos: Vector3) -> void:
	if not _npc.can_see_entity(crime.perpetrator):
		return

	# Check whether we should care about this crime
	if not _should_report(crime):
		return

	_npc.printe("Witnessed crime: %s by %s against %s" % [crime.crime_type, crime.perpetrator, crime.victim])
	CrimeMaster.add_crime(crime, _npc.parent_entity.name)
	_npc.crime_witnessed.emit()

	# Optionally confront the perpetrator
	if confront_perpetrator and crime.severity >= confront_severity_threshold:
		_confront(crime)


## Determine whether this NPC should report a crime based on coven membership.
func _should_report(crime: Crime) -> bool:
	if crime.victim.is_empty():
		return false

	# Always report crimes against members of our own covens
	var our_covens_component = _npc.parent_entity.get_component("CovensComponent")
	if not our_covens_component:
		return false

	var our_covens: Array = (our_covens_component as CovensComponent).covens.keys()

	var victim_entity := SKEntityManager.instance.get_entity(crime.victim)
	if not victim_entity:
		return false

	var victim_cc = victim_entity.get_component("CovensComponent")
	if not victim_cc:
		return false

	var victim_covens: Array = (victim_cc as CovensComponent).covens.keys()

	# Check if the victim shares any of our covens
	for coven: StringName in our_covens:
		if victim_covens.has(coven):
			# Check if this coven ignores crimes against its own members
			var c: Coven = CovenSystem.get_coven(coven)
			if c and not c.ignore_crimes_against_members:
				return true

	# Optionally report crimes against other covens' members
	if report_crimes_against_other_covens:
		for coven: StringName in our_covens:
			var c: Coven = CovenSystem.get_coven(coven)
			if c and not c.ignore_crimes_against_others:
				return true

	return false


## Confront the perpetrator of a crime.
## Stores the crime info in GOAP memory and adds a confrontation objective.
## The consuming game should provide GOAP actions that satisfy the
## [code]{"crime_confronted": true}[/code] goal.
func _confront(crime: Crime) -> void:
	var perp_entity := SKEntityManager.instance.get_entity(crime.perpetrator)
	if not perp_entity:
		return

	_npc.printe("Confronting %s for %s" % [crime.perpetrator, crime.crime_type])

	# Store confrontation data in GOAP memory for actions to reference
	_npc.goap_memory["confrontation_target"] = crime.perpetrator
	_npc.goap_memory["confrontation_crime"] = crime
	_npc.goap_memory["confrontation_bounty"] = _calculate_bounty(crime)

	# Add a high-priority objective to confront the perpetrator
	_npc.add_objective({"crime_confronted": true}, true, 8)

	# Emit signal so consuming games can show dialogue / UI
	_npc.crime_confrontation.emit(crime.perpetrator, crime)


## Calculate the bounty for a specific crime.
func _calculate_bounty(crime: Crime) -> int:
	return CrimeMaster.bounty_amount.get(crime.severity, 0)


## Get the current confrontation target from GOAP memory. Returns empty string if none.
func _get_confrontation_target() -> String:
	return _npc.goap_memory.get("confrontation_target", "")


## Punish crimes in all of this NPC's covens.
func _punish_crimes_for_all_covens() -> void:
	var our_cc = _npc.parent_entity.get_component("CovensComponent")
	if our_cc:
		for coven: StringName in (our_cc as CovensComponent).covens:
			CrimeMaster.punish_crimes(coven)


## Called by the consuming game when the perpetrator chooses to pay the fine.
## Punishes all crimes for the relevant covens and clears the confrontation.
func resolve_pay_fine() -> void:
	var target := _get_confrontation_target()
	if target.is_empty():
		return

	_npc.printe("Crime resolved: %s paid the fine" % target)
	_punish_crimes_for_all_covens()
	_clear_confrontation()


## Called by the consuming game when the perpetrator chooses to serve jail time.
## Punishes all crimes and emits info for the game to handle the jail mechanic.
func resolve_serve_time() -> void:
	var target := _get_confrontation_target()
	if target.is_empty():
		return

	_npc.printe("Crime resolved: %s serving time" % target)
	_punish_crimes_for_all_covens()
	_clear_confrontation()


## Called by the consuming game when the perpetrator resists arrest.
## Begins combat with the perpetrator.
func resolve_resist_arrest() -> void:
	var target := _get_confrontation_target()
	if target.is_empty():
		return

	_npc.printe("Crime resolved: %s resisting arrest — engaging!" % target)

	var perp_entity := SKEntityManager.instance.get_entity(target)
	if perp_entity:
		# Trigger combat via the threat response system
		_npc.in_combat = true
		if _npc.goap_memory.has("enemies"):
			if not _npc.goap_memory["enemies"].has(perp_entity.name):
				_npc.goap_memory["enemies"].append(perp_entity.name)
		else:
			_npc.goap_memory["enemies"] = [perp_entity.name]
		_npc._goap_component.interrupt()

	_clear_confrontation()


## Called by the consuming game when the perpetrator attempts persuasion.
## Returns true if the persuasion succeeds (based on a simple opinion check).
## Override or extend for more complex skill-check logic.
func resolve_persuasion() -> bool:
	var target := _get_confrontation_target()
	if target.is_empty():
		return false

	var opinion := _npc.determine_opinion_of(StringName(target))
	var crime: Crime = _npc.goap_memory.get("confrontation_crime")

	# Simple check: opinion must be positive and above the crime severity penalty
	var threshold: float = crime.severity * 15.0 if crime else 30.0
	var success := opinion > threshold

	if success:
		_npc.printe("Crime resolved: %s persuaded successfully" % target)
		_punish_crimes_for_all_covens()
	else:
		_npc.printe("Crime resolved: %s persuasion failed — resisting arrest" % target)
		resolve_resist_arrest()
		return false

	_clear_confrontation()
	return true


## Clear confrontation state from GOAP memory.
func _clear_confrontation() -> void:
	_npc.goap_memory.erase("confrontation_target")
	_npc.goap_memory.erase("confrontation_crime")
	_npc.goap_memory.erase("confrontation_bounty")


func get_type() -> String:
	return "DefaultCrimeReportModule"
