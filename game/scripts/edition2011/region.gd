class_name EditionRegion
extends RefCounted
static var catalog: Dictionary={}
const CentipedeAttack=preload("res://scripts/edition2011/centipede_attack.gd")
var current_map:=""
var refresh_left:=0.0
var remembered: Dictionary={}
var placements: Dictionary={}
var owner_id:=""
var blocked_until: Dictionary={}
static func data() -> Dictionary:
	if catalog.is_empty():
		var raw=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/regional-data.json"))
		if raw is Dictionary:catalog=raw
	return catalog
static func npcs(id: String) -> Array:
	return data().get("npcs",[]).filter(func(n):return n.enabled and n.map==id).duplicate(true)
static func safe(id: String,cell: Vector2i) -> bool:
	for z in data().get("safe_zones",[]):
		if z.enabled and z.map==id and absi(cell.x-int(z.cell[0]))<=int(z.radius) and absi(cell.y-int(z.cell[1]))<=int(z.radius):return true
	return false
# Nearest town follows existing map exits; within a map choose the closest safe zone.
static func revival_zone(id: String,cell: Vector2i,links: Dictionary) -> Dictionary:
	var frontier: Array=[{"map":id,"cell":cell}];var seen: Dictionary={id:true}
	while not frontier.is_empty():
		var candidates: Array=[];var following: Array=[]
		for node in frontier:
			for zone in data().get("safe_zones",[]):
				if zone.enabled and zone.map==node.map:
					candidates.append({"zone":zone,"distance":node.cell.distance_squared_to(Vector2i(zone.cell[0],zone.cell[1]))})
			for route in links.get(node.map,[]):
				if seen.has(route.target_map):continue
				seen[route.target_map]=true
				following.append({"map":route.target_map,"cell":Vector2i(route.target_cell[0],route.target_cell[1])})
		if not candidates.is_empty():
			candidates.sort_custom(func(a,b):return a.distance<b.distance)
			return candidates[0].zone.duplicate(true)
		frontier=following
	return {}

static func safe_rect(zone: Dictionary) -> Rect2:
	var radius:=int(zone.radius)
	return Rect2(Vector2((int(zone.cell[0])-radius)*48,(int(zone.cell[1])-radius)*32),Vector2((radius*2+1)*48,(radius*2+1)*32))

static func destination(id: String) -> Vector2i:
	var cell: Array=data().get("defaults",{}).get(id,{}).get("cell",[-1,-1])
	return Vector2i(cell[0],cell[1])
static func teleports(npc_id: String) -> Array:
	return data().get("teleports",[]).filter(func(t):return t.npc==npc_id and t.enabled)
static func shop(npc_id: String) -> Dictionary:return data().get("shops",{}).get(npc_id,{})
static func material_suppliers(item: String) -> Array:
	var result: Array=[]
	var spec: Dictionary=data().get("items",{}).get(item,{})
	if spec.get("runtime_status","")!="supported":return result
	for npc in data().get("npcs",[]):
		if not npc.get("enabled",false) or npc.id=="server:merchant:126":continue
		var store:=shop(npc.id)
		for row in store.get("goods",[]):
			if row.get("type","")!=item or int(row.get("count",0))<=0:continue
			result.append({"npc":npc,"price":maxi(1,int(spec.price)*int(store.price_rate)/100),"note":row.get("note","")})
			break
	return result
func reset(world) -> void:
	for e in world.entities:
		e.erase("dragon_warning")
		if e.has("spawn_id"):remembered[e.id]=e
	current_map="";refresh_left=0
func special_snapshots(world) -> Dictionary:
	var records: Dictionary={};var all: Dictionary=remembered.duplicate()
	for entity in world.entities:
		if entity.has("spawn_id"):all[entity.id]=entity
	for id in all:
		var saved:=CentipedeAttack.snapshot(all[id])
		if not saved.is_empty():records[id]=saved
	return records

func trap_snapshots(world) -> Dictionary:
	var records: Dictionary={};var all: Dictionary=remembered.duplicate()
	for entity in world.entities:
		if entity.has("spawn_id"):all[entity.id]=entity
	for id in all:
		var saved: Dictionary=preload("res://scripts/edition2011/trap_status.gd").snapshot(all[id],world.elapsed)
		if not saved.is_empty():records[id]=saved
	return records

static func next_refresh(seconds: float,interval: float) -> float:
	var period:=maxf(1,interval)
	return (floor(seconds/period)+1)*period

func spawn_cell(world,source: Dictionary,p: Array,id: String,deadline: float) -> Vector2i:
	var key:=id+":"+str(deadline)
	if placements.has(key):return placements[key]
	if deadline<=0:return Vector2i(p[2],p[3])
	var rng:=RandomNumberGenerator.new();rng.seed=hash(key)
	var radius:=maxi(0,int(source.range))
	for attempt in range(int(data().monster_settings.spawnMaxTries)):
		var cell:=Vector2i(int(source.x)+rng.randi_range(-radius,radius),int(source.y)+rng.randi_range(-radius,radius))
		if world.navigation.walkable(cell) and not safe(world.metadata.id,cell):placements[key]=cell;return cell
	# Keep a verified original spawn rather than inventing an out-of-range point.
	return Vector2i(p[2],p[3])

static func entity_from(source: Dictionary,definition: Dictionary,id: String,index: int,cell: Vector2i,deadline: float) -> Dictionary:
	var raw: Dictionary=definition.raw
	var e:={"id":id,"spawn_id":source.runtime_id,"spawn_index":index,"kind":"monster","name":source.name,"reference_name":source.name,"species":"village_chicken" if source.name=="鸡" else "ref:"+source.name,"appearance":raw.appr,"bank":definition.profile.bank,"profile":definition.profile,"cell":[cell.x,cell.y],"origin":[cell.x,cell.y],"hp":raw.hp,"max_hp":raw.hp,"respawn":0.0,"respawn_seconds":float(source.interval if source.interval>0 else 10)*60,"generation":int(deadline),"exp":raw.exp,"ac":raw.ac,"damage":raw.dcMax,"walk_ms":raw.walkSpeed,"attack_ms":raw.attackSpd,"passive":int(raw.race) in [20,51,52,55,80,110,111,112],"stationary":int(raw.race) in [55,85,103,107,110,111,112,115,116] or int(definition.profile.actions.walk.count)==0,"drops":definition.drops}
	e.catalog_group=definition.get("catalog_group","normal")
	e.level=int(raw.lvl);e.mp=int(raw.mp);e.max_mp=int(raw.mp)
	e.dc=int(raw.dc);e.dc_max=int(raw.dcMax);e.mac=int(raw.mac);e.mc=int(raw.mc);e.sc=int(raw.sc)
	e.hit=int(raw.hit);e.speed=int(raw.speed);e.race=int(raw.race);e.race_image=int(raw.raceImg)
	e.undead=int(raw.undead);e.cool_eye=int(raw.coolEye);e.walk_step=int(raw.walkStep);e.walk_wait_ms=int(raw.walkWait)
	for key in definition.get("runtime_stats",{}):e[key]=definition.runtime_stats[key]
	if int(raw.race)==107 and int(raw.raceImg)==33:e.centipede_phase="hidden"
	e.reference_stats=raw.duplicate(true);e.reference_spawn=source.duplicate(true)
	return e

func populate(world,rules: EditionRules,delta:=0.0,seconds:=-1.0) -> void:
	if owner_id!=str(rules.character.id):
		remembered.clear();placements.clear();blocked_until.clear();owner_id=str(rules.character.id)
	if seconds<0:seconds=float(rules.state.time)
	refresh_left-=delta
	if current_map==world.metadata.id and refresh_left>0:return
	current_map=world.metadata.id;refresh_left=0.5
	var active: Dictionary={}
	for e in world.entities.duplicate():
		if not e.has("spawn_id"):continue
		if e.hp<=0 and seconds>=float(e.respawn):
			world.entities.erase(e);remembered.erase(e.id);world.actors.movers.erase(e.id);world.actors.brains.erase(e.id)
		else:active[e.id]=e
	var candidates: Array=[]
	for point in data().get("populations",{}).get(current_map,[]):
		var source: Dictionary=data().spawns[int(point[0])]
		var id:="region:"+str(int(point[0]))+":"+str(int(point[1]))
		var deadline:=float(rules.state.get("regional_deaths",{}).get(id,0))
		var cell:=spawn_cell(world,source,point,id,deadline if seconds>=deadline else 0.0)
		var existing: Dictionary=active.get(id,remembered.get(id,{}))
		if deadline>seconds and not existing.is_empty() and existing.hp<=0 and seconds-float(existing.get("motion_time",0))>float(data().monster_settings.corpseDelay)/1000:continue
		if not existing.is_empty() and existing.hp>0:cell=Vector2i(existing.cell[0],existing.cell[1])
		var distance:=Vector2(cell-world.player.cell).length_squared()
		if distance<=1600:candidates.append({"point":point,"id":id,"distance":distance,"cell":cell,"deadline":deadline,"priority":data().monsters[source.name].get("catalog_group","")=="boss_elite"})
	candidates.sort_custom(func(a,b):return a.priority if a.priority!=b.priority else a.distance<b.distance)
	var keep: Dictionary={}
	for candidate in candidates.slice(0,192):
		var p: Array=candidate.point;var source: Dictionary=data().spawns[int(p[0])]
		var id: String=candidate.id;keep[id]=true
		if active.has(id):continue
		if float(candidate.deadline)>seconds or float(blocked_until.get(id,0))>seconds:continue
		var e: Dictionary=remembered.get(id,{})
		var created:=false
		if e.is_empty() or e.get("hp",0)<=0:
			var cell: Vector2i=candidate.cell
			var occupied: Dictionary={world.player.cell:true}
			for other in world.entities:
				if other.get("hp",1)>0:occupied[Vector2i(other.cell[0],other.cell[1])]=true
			if not world.navigation.walkable(cell) or safe(current_map,cell) or occupied.has(cell):
				var rng:=RandomNumberGenerator.new();rng.seed=hash(id+":"+str(candidate.deadline)+":occupied")
				var radius:=maxi(0,int(source.range));var placed:=false
				for attempt in range(int(data().monster_settings.spawnMaxTries)):
					cell=Vector2i(int(source.x)+rng.randi_range(-radius,radius),int(source.y)+rng.randi_range(-radius,radius))
					if world.navigation.walkable(cell) and not safe(current_map,cell) and not occupied.has(cell):placed=true;break
				if not placed:
					blocked_until[id]=seconds+1.0;continue
			placements[id+":"+str(candidate.deadline)]=cell
			e=entity_from(source,data().monsters[source.name],id,int(p[0]),cell,float(candidate.deadline));created=true
			preload("res://scripts/edition2011/trap_status.gd").restore(e,rules.state.get("trapped_monsters",{}).get(id,{}),seconds)
			if int(e.get("race",-1))==107:CentipedeAttack.restore(e,rules.state.get("special_monsters",{}).get(id,{}))
		world.entities.append(e);world.actors.mover(e)
		if created and delta>0:world.actors.sound(e,"appear")
	for id in active:
		if keep.has(id):continue
		remembered[id]=active[id];world.entities.erase(active[id]);world.actors.movers.erase(id);world.actors.brains.erase(id)
