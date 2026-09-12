extends RefCounted
const CLOUD="traveler:yunyouke"
static func alive(state: Dictionary,name: String) -> bool:
	var id: String={"云游客":CLOUD,"青禾":"border:traveler:1","远山":"border:traveler:2","轻舟":"border:traveler:3"}.get(name,"")
	if id.is_empty():return false
	var records=state.get("traveler_health",{})
	if not records is Dictionary:return false
	if not records.has(id):return true
	var row=records[id]
	if not row is Dictionary:return false
	var hp=row.get("hp")
	return (hp is int or hp is float) and is_finite(float(hp)) and hp>0 and hp<=250

static func migrate(state: Dictionary) -> bool:
	var health=state.get("traveler_health",{})
	if not health is Dictionary:return false
	var aliases: Array=["border:traveler:0"]
	var maps=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/maps.json"))
	for entry in maps.entries:aliases.append(str(entry.id)+":traveler")
	var records: Dictionary={}
	for id in aliases:
		if health.has(id):records[id]=health[id].duplicate(true) if health[id] is Dictionary else health[id]
	if health.has(CLOUD):records[CLOUD]=health[CLOUD]
	var chosen: Dictionary={}
	for id in records:
		var row=records[id]
		if not row is Dictionary:return false
		for field in ["hp","generation","respawn"]:
			var value=row.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or value<0:return false
		if row.hp>250 or int(row.hp)!=row.hp or int(row.generation)!=row.generation:return false
		# Legacy records lack chronology. Preserve the newest death generation,
		# then the lower life total and later recovery deadline, without healing.
		if chosen.is_empty() or int(row.generation)>int(chosen.generation) or (int(row.generation)==int(chosen.generation) and (int(row.hp)<int(chosen.hp) or (int(row.hp)==int(chosen.hp) and float(row.respawn)>float(chosen.respawn)))):chosen=row.duplicate(true)
	if not records.is_empty():
		state.legacy_traveler_health=records.duplicate(true)
		for id in records:health.erase(id)
		health[CLOUD]=chosen
		state.traveler_health=health
	state.traveler_identity_version=1
	return true
