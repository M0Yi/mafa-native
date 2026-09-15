class_name EditionActors
extends RefCounted
const CentipedeAttack=preload("res://scripts/edition2011/centipede_attack.gd")
var world
var movers: Dictionary={}
var brains: Dictionary={}

static func occupied_by_other(occupied: Dictionary,cell: Vector2i,actor_id: String) -> bool:
	if not occupied.has(cell):return false
	var owners: Array=occupied[cell]
	return owners.size()>1 or (owners.size()==1 and owners[0]!=actor_id)

static func blocked_cells(occupied: Dictionary,actor_id: String) -> Dictionary:
	var blocked: Dictionary={}
	for cell in occupied:
		if occupied_by_other(occupied,cell,actor_id):blocked[cell]=true
	return blocked

func reset() -> void:movers.clear();brains.clear()
func player_reserved_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i]=[]
	for actor in world.entities:
		if actor.kind not in ["monster","traveler"] or int(actor.get("hp",1))<=0 or EditionCreatures.underground(actor):continue
		var motion: ClassicPlayer=movers.get(actor.id)
		if motion!=null:
			cells.append(motion.cell);cells.append(motion.destination)
		else:cells.append(Vector2i(actor.cell[0],actor.cell[1]))
	return cells

func player_can_step(next: Vector2i) -> bool:
	return next not in player_reserved_cells()

func party_landing() -> Vector2i:
	var origin: Vector2i=world.player.cell
	var occupied: Dictionary={origin:true}
	for actor in world.entities:
		if actor.kind=="npc" or int(actor.get("hp",1))>0:occupied[Vector2i(actor.cell[0],actor.cell[1])]=true
	var doors: Array[Vector2i]=world.player.path_avoid
	for radius in range(1,9):
		for y in range(origin.y-radius,origin.y+radius+1):
			for x in range(origin.x-radius,origin.x+radius+1):
				var at:=Vector2i(x,y)
				if occupied.has(at) or at in doors or not world.navigation.mobile(at):continue
				if not world.navigation.path_avoiding(origin,at,doors).is_empty():return at
	return Vector2i(-1,-1)

func traveler_landing(center: Vector2i,actor_id: String) -> Vector2i:
	# Keep nearby doorway routes usable when placing an ambient traveler.
	var occupied: Dictionary={world.player.cell:true}
	for actor in world.entities:
		if actor.id!=actor_id and (actor.kind=="npc" or int(actor.get("hp",1))>0):occupied[Vector2i(actor.cell[0],actor.cell[1])]=true
	var paths: Array=[]
	for door in world.player.path_avoid:
		if door.distance_to(center)>16 and door.distance_to(world.player.cell)>16:continue
		var path: Array[Vector2i]=world.navigation.path_avoiding(world.player.cell,door,world.player.path_avoid)
		if not path.is_empty():paths.append(path)
	for radius in range(13):
		for y in range(center.y-radius,center.y+radius+1):
			for x in range(center.x-radius,center.x+radius+1):
				if radius>0 and maxi(absi(x-center.x),absi(y-center.y))!=radius:continue
				var at:=Vector2i(x,y)
				if occupied.has(at) or at in world.player.path_avoid or not world.navigation.mobile(at):continue
				if world.navigation.path_avoiding(world.player.cell,at,world.player.path_avoid).is_empty():continue
				var blocked:=false
				for path in paths:
					if at not in path:continue
					var avoid: Array[Vector2i]=world.player.path_avoid.duplicate();avoid.append(at)
					if world.navigation.path_avoiding(world.player.cell,path.back(),avoid).is_empty():blocked=true;break
				if not blocked:return at
	return Vector2i(-1,-1)

func mover(entity: Dictionary) -> ClassicPlayer:
	if not movers.has(entity.id):
		var motion:=ClassicPlayer.new();motion.nav=world.navigation;motion.reset(Vector2i(entity.cell[0],entity.cell[1]));motion.direction=int(entity.get("direction",4));movers[entity.id]=motion
		brains[entity.id]={"wait":0.3+posmod(hash(entity.id),12)*0.1,"turn":0,"retarget":0.0,"ambient":2.0+posmod(hash(entity.id),9),"cooldown":0.0,"walk_count":0,"walk_rest":0.0}
	return movers[entity.id]
func anchor(entity: Dictionary) -> Vector2:
	return movers[entity.id].anchor if movers.has(entity.id) else Vector2(entity.cell[0],entity.cell[1])*ClassicPlayer.CELL
func landing(center: Vector2i) -> Vector2i:
	if world.navigation.walkable(center):return center
	for radius in range(1,13):
		for d in ClassicNavigation.DIRECTIONS:
			var cell: Vector2i=center+d*radius
			if world.navigation.walkable(cell):return cell
	return world.player.cell
func sound(entity: Dictionary,event: String) -> void:
	if anchor(entity).distance_to(world.player.anchor)>ClassicPlayer.CELL.x*12:return
	var id:=EditionCreatures.sound_id(entity,event)
	if id>=0:world.actor_sound.emit(id,anchor(entity),event)
func wander(entity: Dictionary,motion: ClassicPlayer,brain: Dictionary) -> void:
	var origin: Array=entity.get("origin",entity.cell)
	var radius:=2 if entity.kind=="monster" else 5
	for attempt in range(8):
		brain.turn+=1
		var n:=posmod(hash(entity.id)+int(brain.turn)*17,89)
		var target:=Vector2i(origin[0]+n%(radius*2+1)-radius,origin[1]+(n/7)%(radius*2+1)-radius)
		if entity.kind=="monster" and EditionRegion.safe(world.metadata.id,target):continue
		if motion.go_to(target) and not motion.route.is_empty():
			if entity.kind=="monster" and motion.route.any(func(p):return EditionRegion.safe(world.metadata.id,p)):motion.route.clear();continue
			return

func update(delta: float,party: Array) -> void:
	if world.paused:return
	# Reserve both ends of each ongoing step. Never snap an actor backwards.
	var occupied: Dictionary={}
	for actor in world.entities:
		if actor.kind not in ["monster","traveler"] or int(actor.get("hp",1))<=0 or EditionCreatures.underground(actor):continue
		var moving:=mover(actor)
		for cell in [moving.cell,moving.destination]:
			if not occupied.has(cell):occupied[cell]=[]
			if actor.id not in occupied[cell]:occupied[cell].append(actor.id)
	for entity in world.entities:
		if entity.kind not in ["traveler","monster"]:continue
		if entity.kind=="traveler" and int(entity.get("hp",250))<=0:continue
		if entity.kind=="traveler" and world.elapsed<float(entity.get("stone_until",0)):continue
		var motion:=mover(entity);var brain: Dictionary=brains[entity.id]
		var previous_cells: Array[Vector2i]=[motion.cell,motion.destination]
		var blocked: Dictionary={}
		var actor_id: String=entity.id
		var target_player: ClassicPlayer=world.player
		var reserved_doors: Array[Vector2i]=[]
		if entity.kind=="traveler":reserved_doors.assign(world.player.path_avoid)
		motion.step_filter=func(next):return next!=target_player.cell and next!=target_player.destination and not EditionActors.occupied_by_other(occupied,next,actor_id) and next not in reserved_doors
		if entity.kind=="traveler":
			blocked=blocked_cells(occupied,actor_id)
			motion.path_avoid.assign(blocked.keys())
			motion.path_avoid.append_array(reserved_doors)
			motion.path_avoid.append(target_player.cell);motion.path_avoid.append(target_player.destination)

		if entity.kind=="monster":
			if preload("res://scripts/edition2011/trap_status.gd").update_entity(entity,world.elapsed):
				motion.route.clear();motion.action="stand";continue
			if entity.hp<=0:
				if entity.has("spawn_id"):continue
				if world.elapsed>=float(entity.respawn):
					entity.hp=entity.max_hp;entity.motion="stand";entity.motion_time=world.elapsed;entity.aggro=false
					var origin: Array=entity.get("origin",entity.cell);motion.reset(landing(Vector2i(origin[0],origin[1])));entity.cell=[motion.cell.x,motion.cell.y];sound(entity,"appear")
				continue
			var protected:=EditionMonsterAI.update_target(world,entity,motion,delta)
			if EditionDragonAttack.update(world,entity,motion,protected):continue
			if CentipedeAttack.update(world,entity,motion,protected):continue
			brain.ambient-=delta;brain.cooldown=maxf(0,brain.cooldown-delta)
			if brain.ambient<=0:
				brain.ambient=6.0+posmod(hash(entity.id)+int(brain.turn),7);sound(entity,"idle")
			var age: float=world.elapsed-float(entity.get("motion_time",0))
			if entity.get("motion")=="attack":
				if age>=EditionCreatures.duration(entity,"attack",0.6)/2 and not entity.get("strike_done",false):
					entity.strike_done=true;sound(entity,"weapon")
					if not protected and entity.get("aggro",false) and EditionMonsterAI.melee(world.navigation,motion.cell,world.player.cell):
						entity.focus_time=world.elapsed
						world.monster_hit.emit(entity,randi_range(int(entity.get("dc",1)),maxi(int(entity.get("dc",1)),int(entity.get("dc_max",EditionCreatures.profile(entity).get("damage",1))))))
				if age<EditionCreatures.duration(entity,"attack",0.6):continue
				entity.motion="stand"
			if entity.get("motion")=="hurt":
				if age<EditionCreatures.duration(entity,"hurt",0.2):continue
				entity.motion="stand"
			if entity.get("aggro",false) and brain.cooldown<=0 and motion.progress>=1 and EditionMonsterAI.melee(world.navigation,motion.cell,world.player.cell):
				motion.route.clear();motion.action="stand";entity.motion="attack";entity.motion_time=world.elapsed;entity.strike_done=false
				var direction:=Vector2i(signi(world.player.cell.x-motion.cell.x),signi(world.player.cell.y-motion.cell.y))
				if direction!=Vector2i.ZERO:motion.direction=ClassicNavigation.DIRECTIONS.find(direction)
				entity.direction=motion.direction;brain.cooldown=maxf(0.5,float(entity.get("attack_ms",1800))/1000);sound(entity,"attack");continue
		if entity.get("stationary",false):motion.route.clear();continue
		brain.wait-=delta;brain.retarget-=delta
		var following: bool=str(entity.name) in party
		if following:
			if brain.retarget<=0:
				brain.retarget=0.5
				if motion.anchor.distance_to(world.player.anchor)>130:
					var offsets: Array[Vector2i]=[Vector2i(-2,1),Vector2i(2,1),Vector2i(-1,2),Vector2i(1,-2)]
					var index:=maxi(0,party.find(str(entity.name)))
					for attempt in range(offsets.size()):
						var target: Vector2i=world.player.cell+offsets[(index+attempt)%offsets.size()]
						if not occupied_by_other(occupied,target,actor_id) and world.navigation.walkable(target) and motion.go_to(target):break
				else:motion.route.clear()
		elif entity.kind=="monster" and entity.get("aggro",false) and brain.retarget<=0:
			brain.retarget=0.35+posmod(hash(entity.id),5)*0.05
			blocked=blocked_cells(occupied,actor_id)
			EditionMonsterAI.approach(world,motion,blocked)
		elif not entity.get("aggro",false) and motion.progress>=1 and motion.route.is_empty() and brain.wait<=0:
			wander(entity,motion,brain);brain.wait=1.5+posmod(hash(entity.id)+int(brain.turn),9)*0.2
		if entity.kind=="monster":
			if world.player.cell in motion.route:motion.route.clear()
			motion.step_duration_override=maxf(0.2,float(entity.get("walk_ms",720))/1000)
			if float(brain.walk_rest)>0 and motion.progress>=1:
				brain.walk_rest=maxf(0,float(brain.walk_rest)-delta);motion.action="stand";continue
		var steps_before:=motion.completed_steps
		motion.update(delta,Vector2i.ZERO,following and motion.anchor.distance_to(world.player.anchor)>320)
		if entity.kind=="monster" and motion.completed_steps>steps_before:
			brain.walk_count+=1
			if int(entity.get("walk_step",0))>0 and int(brain.walk_count)>=int(entity.walk_step):
				brain.walk_count=0;brain.walk_rest=float(entity.get("walk_wait_ms",0))/1000
				# ClassicPlayer can queue the next step in the same update. Yield
				# before moving into it so the source burst/rest rule takes effect.
				if motion.progress==0:
					motion.route.push_front(motion.destination);motion.destination=motion.cell;motion.progress=1;motion.action="stand";motion.elapsed=0
		entity.cell=[motion.cell.x,motion.cell.y];entity.direction=motion.direction
		# This actor only reserved its previous step endpoints, not every cell.
		for cell in previous_cells:
			if not occupied.has(cell):continue
			occupied[cell].erase(entity.id)
			if occupied[cell].is_empty():occupied.erase(cell)
		for cell in [motion.cell,motion.destination]:
			if not occupied.has(cell):occupied[cell]=[]
			if entity.id not in occupied[cell]:occupied[cell].append(entity.id)
