extends RefCounted
const JOB_MAPS={"战士":"q001","法师":"q002","道士":"q003"}
const MONSTERS={"战士":"骷髅精灵2","法师":"半兽勇士2","道士":"巨型多角虫2"}
static func valid(value: Variant) -> bool:
	if not value is Dictionary:return false
	for key in ["active","won","claimed"]:
		if not value.get(key) is bool:return false
	if not value.get("id") is String or value.id.length()!=32 or not value.id.is_valid_hex_number(false):return false
	if not JOB_MAPS.has(value.get("job")) or value.get("map")!=JOB_MAPS[value.job] or value.get("return_map")!="1":return false
	for key in ["started","deadline"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])) or value[key]<0:return false
	if absf(float(value.deadline)-float(value.started)-60.0)>0.001:return false
	if not value.get("return_cell") is Array or value.return_cell.size()!=2:return false
	for coordinate in value.return_cell:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or coordinate!=int(coordinate) or coordinate<0 or coordinate>4095:return false
	if value.has("proof_uid") and (not value.proof_uid is String or value.proof_uid.length()!=32 or not value.proof_uid.is_valid_hex_number(false)):return false
	if value.has("picked") and (not value.picked is bool or (value.picked and (not value.won or not value.has("proof_uid")))):return false
	if value.has("monster"):
		var monster=value.monster
		if not monster is Dictionary:return false
		if monster.has("trap"):
			if not preload("res://scripts/edition2011/trap_status.gd").valid_snapshot(monster.trap):return false
			if monster.trap.status.id!="cook:"+value.id or monster.trap.spawn_id!="cook:"+value.id:return false
		for key in ["hp","mp","direction","cooldown","wait","walk_rest"]:
			if not (monster.get(key) is int or monster.get(key) is float) or not is_finite(float(monster[key])) or monster[key]<0:return false
		for key in ["hp","mp","direction"]:
			if monster[key]!=int(monster[key]):return false
		if monster.hp<1 or monster.hp>100000000 or monster.mp>100000000 or monster.direction>7:return false
		if not monster.get("cell") is Array or monster.cell.size()!=2:return false
		for coordinate in monster.cell:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or coordinate!=int(coordinate) or coordinate<0 or coordinate>=25:return false
	return not value.claimed or (value.won and not value.active)
static func begin(state: Dictionary,job: String,cell: Vector2i,seconds: float) -> Dictionary:
	if not JOB_MAPS.has(job) or not is_finite(seconds) or seconds<0 or state.get("hp",0)<=0 or state.get("map")!="1":return {}
	if state.get("quests",{}).get("story_feast_cook_trail")!="done":return {}
	var previous: Dictionary=state.get("cook_trial",{})
	if previous.get("claimed",false) or previous.get("active",false) or (previous.get("won",false) and not previous.get("claimed",false)):return {}
	var session:={"id":Crypto.new().generate_random_bytes(16).hex_encode(),"job":job,"map":JOB_MAPS[job],"return_map":"1","return_cell":[cell.x,cell.y],"started":seconds,"deadline":seconds+60.0,"active":true,"won":false,"claimed":false}
	return session if valid(session) else {}
static func victory(session: Dictionary,attempt: String,map_id: String,monster: String,seconds: float,alive: bool) -> Dictionary:
	if not valid(session) or not alive or not session.active or session.won or session.id!=attempt or session.map!=map_id:return {}
	if monster!=MONSTERS[session.job] or not is_finite(seconds) or seconds<float(session.started) or seconds>=float(session.deadline):return {}
	var next:=session.duplicate(true);next.won=true;return next
static func due(session: Dictionary,seconds: float) -> bool:
	return valid(session) and session.active and is_finite(seconds) and seconds>=float(session.deadline)
