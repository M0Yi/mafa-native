extends RefCounted
static func number(value,maximum: float,whole:=true) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and (not whole or int(value)==value)
static func valid(state: Dictionary,items: Dictionary) -> bool:
	var health=state.get("traveler_health",{})
	if not health is Dictionary:return false
	for id in health:
		var row=health[id]
		if not id is String or id.is_empty() or not row is Dictionary:return false
		if not number(row.get("hp"),250) or not number(row.get("generation"),2147483647) or not number(row.get("respawn"),1e15,false):return false
	var guild=state.get("guild",{})
	if not guild is Dictionary:return false
	if guild.has("name") and not guild.name is String:return false
	if guild.has("members"):
		if not guild.members is Array:return false
		for member in guild.members:
			if not member is String or member.is_empty():return false
	if guild.has("contribution") and not number(guild.contribution,2147483647):return false
	var supplies=guild.get("supplies",{})
	if not supplies is Dictionary:return false
	for item in supplies:
		if not items.has(item) or not number(supplies[item],2147483647):return false
	var log=guild.get("aid_log",[])
	if not log is Array or log.size()>100:return false
	for row in log:
		if not row is Dictionary:return false
		for key in ["member","entity","map","item"]:
			if not row.get(key) is String or row[key].is_empty():return false
		if not items.has(row.item) or not number(row.get("count"),9999) or row.count<1 or not number(row.get("healed"),250) or row.healed<1:return false
	return true
