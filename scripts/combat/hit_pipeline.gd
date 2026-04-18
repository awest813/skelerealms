class_name HitPipeline
extends RefCounted
## Resolves combat hits by checking invincibility, blocking, parrying,
## applying resistances, delivering damage, and processing poise/stagger.
##
## This is a stateless utility — call [method resolve_hit] or
## [method resolve_hitscan] from hitbox callbacks or hitscan checks.


## Result of a hit resolution.
enum HitResult {
	LANDED,     ## Normal hit — damage applied.
	BLOCKED,    ## Target was blocking — reduced or no damage.
	PARRIED,    ## Target was in parry window — special response.
	INVINCIBLE, ## Target was invincible (i-frames) — no effect.
	MISSED,     ## No valid target found (hitscan only).
}


## Resolve a melee/AOE hit between a hitbox and hurtbox.
## Returns the [enum HitResult].
static func resolve_hit(
	hitbox:SKHitbox,
	hurtbox:SKHurtbox,
	action:CombatAction,
	offender_name:String,
	source_weapon:StringName = &"",
) -> HitResult:
	var target_entity := SKEntityManager.instance.get_entity(hurtbox.owner_entity_ref)
	if not target_entity:
		return HitResult.MISSED

	var combatant:CombatantComponent = target_entity.get_component("CombatantComponent") as CombatantComponent

	# I-frame check
	if combatant and combatant.invincible:
		return HitResult.INVINCIBLE

	# Parry check
	if combatant and combatant.parrying:
		return HitResult.PARRIED

	# Block check
	if combatant and combatant.blocking:
		return HitResult.BLOCKED

	# Build damage packet
	var packet := action.build_damage_packet(offender_name, source_weapon)

	# Apply hurtbox region multiplier
	if not is_zero_approx(hurtbox.damage_multiplier - 1.0):
		for key in packet.damage_effects:
			packet.damage_effects[key] *= hurtbox.damage_multiplier

	# Apply resistances
	if combatant:
		packet = combatant.apply_resistances(packet)

	# Deliver damage through existing pipeline
	var damageable:DamageableComponent = target_entity.get_component("DamageableComponent") as DamageableComponent
	if damageable:
		damageable.damage(packet)

	# Process poise
	if combatant:
		var poise_broken := combatant.apply_poise_damage(action.poise_damage)
		if poise_broken:
			var csm:CombatStateMachine = target_entity.get_node_or_null("CombatStateMachine") as CombatStateMachine
			if csm:
				if packet.hit_reaction == &"knockdown":
					csm.apply_knockdown()
				else:
					csm.apply_stagger()

	# Notify the hurtbox
	hurtbox.hurt.emit(hitbox)

	return HitResult.LANDED


## Resolve a hitscan (raycast) hit.
## [param space_state]: the physics space to raycast in.
## [param from]: ray origin (e.g. muzzle position).
## [param direction]: normalized ray direction.
## [param action]: the combat action being performed.
## [param offender_name]: the attacker's entity name.
## [param source_weapon]: weapon identifier.
## [param exclude]: RIDs to exclude from the ray (e.g. the shooter).
static func resolve_hitscan(
	space_state:PhysicsDirectSpaceState3D,
	from:Vector3,
	direction:Vector3,
	action:CombatAction,
	offender_name:String,
	source_weapon:StringName = &"",
	exclude:Array[RID] = [],
) -> HitResult:
	var to := from + direction * action.hitscan_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return HitResult.MISSED

	var collider = result.get("collider")
	if not collider:
		return HitResult.MISSED

	# Check if we hit a hurtbox
	if collider is SKHurtbox:
		# Create a temporary hitbox reference for the pipeline
		var temp_hitbox := SKHitbox.new()
		temp_hitbox.owner_entity_ref = StringName(offender_name)
		var hit_result := resolve_hit(temp_hitbox, collider as SKHurtbox, action, offender_name, source_weapon)
		temp_hitbox.queue_free()
		return hit_result

	# If we hit a damageable world object, apply damage directly
	if collider.has_method("damage"):
		var packet := action.build_damage_packet(offender_name, source_weapon)
		collider.damage(packet)
		return HitResult.LANDED

	return HitResult.MISSED
