class_name EditionMonsterAI
extends RefCounted
# Mir2-GeeM2 monsterobject.go searchTarget / validateTarget / Run.
# Safe-zone and closed-corner protection are explicit single-player adaptations.
static func melee(nav: ClassicNavigation,a: Vector2i,b: Vector2i) -> bool:
	return nav.can_step(a,b)

static func update_target(world,entity: Dictionary,motion: ClassicPlayer,delta: float) -> bool:
	var cfg: Dictionary=EditionRegion.data().monster_settings
	var offset: Vector2i=(world.player.cell-motion.cell).abs()
	var protected: bool=not world.player_alive or EditionRegion.safe(world.metadata.id,world.player.cell)
	var invalid: bool=protected or offset.x+offset.y>int(cfg.targetLossDist)
	var focus: float=float(entity.get("focus_time",world.elapsed))
	if entity.get("aggro",false) and world.elapsed-focus>float(cfg.targetFocusTimeout)/1000:invalid=true
	if invalid:
		entity.aggro=false;motion.route.clear()
		entity.search_left=float(cfg.searchNoTarget)/1000
	else:
		entity.search_left=float(entity.get("search_left",float(cfg.searchNoTarget)/1000))-delta
		if not entity.get("aggro",false) and not entity.get("passive",true) and entity.search_left<=0:
			entity.search_left=float(cfg.searchNoTarget)/1000
			var view:=int(cfg.defaultViewRange)+int(entity.get("cool_eye",0))
			if maxi(offset.x,offset.y)<=view:
				entity.aggro=true;entity.focus_time=world.elapsed
	regenerate(entity,delta,cfg)
	return protected

static func regenerate(entity: Dictionary,delta: float,cfg: Dictionary) -> void:
	if int(entity.get("hp",0))<=0 or delta<=0:return
	var interval:=maxf(0.1,float(cfg.hpRegenInterval)/1000)
	if entity.hp>=entity.max_hp:entity.regen_left=interval;return
	entity.regen_left=float(entity.get("regen_left",interval))-delta
	if entity.regen_left<=0:
		var ticks:=1+int(floor(-float(entity.regen_left)/interval))
		entity.regen_left+=ticks*interval
		var amount:=maxi(1,int(entity.max_hp)/maxi(1,int(cfg.hpRegenDivisor))+1)
		entity.hp=mini(int(entity.max_hp),int(entity.hp)+amount*ticks)

static func approach(world,motion: ClassicPlayer,blocked: Dictionary={}) -> void:
	# Aim at a reachable attack tile, never at the player's occupied cell.
	var start:=motion.destination if motion.progress<1 else motion.cell
	if melee(world.navigation,start,world.player.cell):motion.route.clear();return
	var previous: Array[Vector2i]=[]
	for cell in world.navigation.occupied:previous.append(cell)
	var temporary:=previous.duplicate()
	for cell in blocked:
		if cell!=start and cell!=motion.cell:temporary.append(cell)
	world.navigation.set_occupied(temporary)
	var best: Array[Vector2i]=[]
	for direction in ClassicNavigation.DIRECTIONS:
		var target: Vector2i=world.player.cell+direction
		if not melee(world.navigation,target,world.player.cell):continue
		var route: Array[Vector2i]=world.navigation.path(start,target)
		if route.is_empty() or world.player.cell in route:continue
		if route.any(func(p):return EditionRegion.safe(world.metadata.id,p)):continue
		if best.is_empty() or route.size()<best.size():best=route
	world.navigation.set_occupied(previous)
	motion.route=best
	if not motion.route.is_empty():motion.route.pop_front()

static func react_to_hit(entity: Dictionary,seconds: float,periodic:=false) -> void:
	entity.aggro=int(entity.get("race",0))!=55
	entity.focus_time=seconds
	# Damage never cancels a committed attack or repeatedly restarts a flinch.
	# Periodic poison continues aggro without stun-locking the target.
	if periodic or entity.get("centipede_phase","")=="emerging" or entity.get("motion","")=="attack":return
	if seconds<float(entity.get("flinch_ready",0)):return
	entity.motion="hurt";entity.motion_time=seconds;entity.flinch_ready=seconds+0.6
