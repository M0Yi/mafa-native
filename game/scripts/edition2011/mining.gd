extends RefCounted
# Local reconstruction: source mining lacks a usable high-grade gold distribution.
# One chance in four per swing; equal ore kinds, integer purity 1..20.
const MAPS=["d401","d402","d403","d404","d405","d406"]
const VEIN_SWINGS=200
const REGEN_SECONDS=600.0
const DISTRIBUTION_VERSION=2
const ORES=["ore","ref:131","ref:132","ref:178"]
static func valid(value: Variant) -> bool:
	if not value is Dictionary:return false
	for key in ["attempts","ready"]:
		var number=value.get(key)
		if not (number is int or number is float) or not is_finite(float(number)) or number<0:return false
	if value.attempts!=floor(float(value.attempts)) or value.attempts>=1000000000:return false
	if value.has("veins"):
		if not value.veins is Dictionary:return false
		for key in value.veins:
			if not key is String:return false
			var parts: PackedStringArray=key.split(":")
			if parts.size()!=3 or parts[0] not in MAPS:return false
			for coordinate in parts.slice(1):
				if not coordinate.is_valid_int() or int(coordinate)<0 or int(coordinate)>4095 or str(int(coordinate))!=coordinate:return false
			var node=value.veins[key]
			if not node is Dictionary:return false
			for field in ["used","restore_at"]:
				var number=node.get(field)
				if not (number is int or number is float) or not is_finite(float(number)) or number<0:return false
			if node.used!=floor(float(node.used)) or node.used>VEIN_SWINGS:return false
			if (node.used<VEIN_SWINGS and node.restore_at!=0) or (node.used==VEIN_SWINGS and node.restore_at<REGEN_SECONDS):return false
	return true
static func wall(navigation,cell: Vector2i,direction: int) -> bool:
	if direction<0 or direction>=8 or not navigation.walkable(cell):return false
	var target: Vector2i=cell+ClassicNavigation.DIRECTIONS[direction]
	return target.x>=0 and target.y>=0 and target.x<navigation.size.x and target.y<navigation.size.y and not bool(navigation.cells[target.y][target.x])
static func result(character_id: String,attempt: int) -> Dictionary:
	var digest: String=(character_id+":mining-v"+str(DISTRIBUTION_VERSION)+":"+str(attempt)).sha256_text()
	if digest.substr(0,6).hex_to_int()%4!=0:return {}
	return {"type":ORES[digest.substr(6,6).hex_to_int()%ORES.size()],"purity":1+digest.substr(12,6).hex_to_int()%20}
static func swing(app) -> bool:
	if app.world.metadata.id not in MAPS or app.rules.state.equipment.get("weapon")!="ref:87":return false
	if not wall(app.world.navigation,app.world.player.cell,app.world.player.direction):return false
	if not app.gameplay.available() or not app.pending_attack.is_empty():return true
	var previous: Dictionary=app.rules.state.get("mining",{"attempts":0,"ready":0.0})
	if app.elapsed<float(previous.ready):return true
	var target: Vector2i=app.world.player.cell+ClassicNavigation.DIRECTIONS[app.world.player.direction]
	var key: String="%s:%d:%d"%[app.world.metadata.id,target.x,target.y]
	var veins: Dictionary=previous.get("veins",{}).duplicate(true)
	var node: Dictionary=veins.get(key,{"used":0,"restore_at":0.0})
	if int(node.used)>=VEIN_SWINGS:
		if app.elapsed<float(node.restore_at):
			app.pending_message="这处矿壁已采空，还需 %d 秒游戏时间恢复；可以寻找另一处矿壁"%int(ceil(float(node.restore_at)-app.elapsed));return true
		node={"used":0,"restore_at":0.0}
	var next: Dictionary=app.rules.state.duplicate(true)
	var equipped: Array=next.items.filter(func(i):return i.container=="equipment" and i.type=="ref:87")
	if equipped.is_empty() or int(equipped[0].durability)<=0:app.pending_message="鹤嘴锄已损坏，请修理后采矿";return true
	var attempt:=int(previous.attempts)+1
	var ore:=result(str(app.rules.character.id),attempt)
	equipped[0].durability-=1;EditionInventory.mirror(next)
	node.used+=1
	if int(node.used)==VEIN_SWINGS:node.restore_at=app.elapsed+REGEN_SECONDS
	veins[key]=node
	next.mining={"attempts":attempt,"ready":app.elapsed+1.0,"veins":veins};next.time=app.elapsed
	if not ore.is_empty():
		app.rules.add_ground(next,{"map":app.world.metadata.id,"cell":[app.world.player.cell.x,app.world.player.cell.y]},ore.type,1)
		next.ground_loot[-1].purity=ore.purity
		EditionRules.Story.observe(next,"mine",{"map":app.world.metadata.id,"item":ore.type})
	if not app.rules.apply(next,"mine_swing"):app.pending_message=app.rules.message;return true
	app.fight_timer=1.0;app.world.animate("attack");app.play_sound_id(91)
	app.pending_message="挖出%s · 纯度%d · 请拾取地上矿石"%[EditionRules.ITEMS[ore.type].name,ore.purity] if not ore.is_empty() else "挥镐未获得矿石 · 鹤嘴锄耐久减少1"
	return true

static func nearby_wall(navigation,start: Vector2i,map_id: String,mining_state: Dictionary,seconds: float) -> Dictionary:
	if map_id not in MAPS or not navigation.walkable(start):return {}
	var queue: Array[Vector2i]=[start]
	var seen: Dictionary={start:true}
	var cursor:=0
	while cursor<queue.size() and cursor<4096:
		var at: Vector2i=queue[cursor];cursor+=1
		for direction in range(8):
			if not wall(navigation,at,direction):continue
			var target: Vector2i=at+ClassicNavigation.DIRECTIONS[direction]
			var key: String="%s:%d:%d"%[map_id,target.x,target.y]
			var vein: Dictionary=mining_state.get("veins",{}).get(key,{"used":0,"restore_at":0})
			if int(vein.used)>=VEIN_SWINGS and seconds<float(vein.restore_at):continue
			return {"cell":at,"direction":direction,"wall":target}
		for step in ClassicNavigation.DIRECTIONS:
			var next: Vector2i=at+step
			if not seen.has(next) and navigation.can_step(at,next):seen[next]=true;queue.append(next)
	return {}
