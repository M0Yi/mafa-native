extends RefCounted
# Single-player reconstruction. These control rules are not present in the
# selected reference client's disabled mtKyulKai effect implementation.
const DURATIONS=[8.0,12.0,16.0]
static func eligible(monster: Dictionary,caster_level: int) -> bool:
	return monster.get("kind","")=="monster" and int(monster.get("hp",0))>0 and not monster.get("boss",false) and monster.get("catalog_group","") not in ["boss","boss_elite"] and not monster.get("trap_immune",false) and int(monster.get("level",1))<caster_level
static func create(monster: Dictionary,caster_level: int,rank: int,seconds: float) -> Dictionary:
	if not eligible(monster,caster_level) or not is_finite(seconds) or seconds<0 or str(monster.get("id","")).is_empty():return {}
	return {"id":str(monster.id),"generation":int(monster.get("generation",0)),"hp":int(monster.hp),"expires":seconds+DURATIONS[clampi(rank,1,3)-1]}
static func active(status: Dictionary,monster: Dictionary,seconds: float) -> bool:
	if not is_finite(seconds) or seconds<0:return false
	return not status.is_empty() and status.get("id","")==monster.get("id","") and int(status.get("generation",-1))==int(monster.get("generation",0)) and int(monster.get("hp",0))>0 and int(monster.hp)>=int(status.get("hp",0)) and seconds<float(status.get("expires",0))

static func update_entity(monster: Dictionary,seconds: float) -> bool:
	if not monster.has("trap_status"):return false
	var status: Dictionary=monster.trap_status
	if not active(status,monster,seconds):
		monster.erase("trap_status")
		return false
	# Cancel any attack windup; an expired trap must not release a stale hit.
	monster.strike_done=true
	monster.motion="stand"
	return true

static func snapshot(monster: Dictionary,seconds: float) -> Dictionary:
	if not monster.has("trap_status") or not active(monster.trap_status,monster,seconds):return {}
	return {"spawn_id":str(monster.get("spawn_id","")),"status":monster.trap_status.duplicate(true),"hp":int(monster.hp)}
static func valid_snapshot(record: Variant) -> bool:
	if not record is Dictionary or not record.get("spawn_id") is String or not record.get("status") is Dictionary:return false
	var status: Dictionary=record.status
	if not status.get("id") is String or str(status.id).is_empty():return false
	for key in ["hp","generation","expires"]:
		var number=status.get(key)
		if not (number is int or number is float) or not is_finite(float(number)) or number<0:return false
		if key!="expires" and float(number)!=floor(float(number)):return false
	var hp=record.get("hp")
	return (hp is int or hp is float) and is_finite(float(hp)) and hp>0 and hp==floor(float(hp)) and hp>=status.hp
static func restore(monster: Dictionary,record: Dictionary,seconds: float) -> bool:
	if not valid_snapshot(record) or record.spawn_id!=monster.get("spawn_id",""):return false
	var probe:=monster.duplicate(true);probe.hp=int(record.hp)
	if not active(record.status,probe,seconds) or int(record.hp)>int(monster.get("max_hp",0)):return false
	monster.hp=int(record.hp);monster.trap_status=record.status.duplicate(true)
	return true
