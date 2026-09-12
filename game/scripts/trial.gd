class_name ClassicTrial
extends RefCounted

var player: ClassicPlayer
var nav: ClassicNavigation
var audio: ClassicAudio
var catalog: Dictionary
var skills: Array = []
var job := "法师"
var hurt_sound := "0103008A"
var selected := 0
var enabled := false
var actors: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var fields: Array[Dictionary] = []
var buffs: Dictionary = {}
var hp := 360.0
var mp := 300.0
var cast_time := 0.0
var cooldown := 0.0
var action := "cast"
var message := ""
var clock := 0.0
var tick := 0.0
var attack_count := 0
var red_poison := false
var hostile := false
var hostile_magic := false
var next_id := 1
var total_casts := 0
var rng := RandomNumberGenerator.new()

func configure(p: ClassicPlayer, a: ClassicAudio, data: Dictionary) -> void:
	player=p; nav=p.nav; audio=a; catalog=data
	rng.seed=176
	select_job(job)

func select_job(value: String) -> void:
	job=value; skills=[]; selected=0
	for s in catalog.skills:
		if s.job==job: skills.append(s)
	buffs.clear(); pending.clear(); fields.clear(); effects.clear()
	actors = actors.filter(func(a): return not a.ally)
	cast_time=0; cooldown=0; hp=360; mp=300
	message=job+"技能已全部开放；当前使用试练数值。"

func reset_targets() -> void:
	actors.clear(); fields.clear(); effects.clear(); pending.clear(); buffs.clear()
	hp=360; mp=300; cast_time=0; cooldown=0
	var places: Array[Vector2i]=[]
	for y in range(-4,5):
		for x in range(-5,6):
			var p:=player.cell+Vector2i(x,y)
			if p!=player.cell and line_clear(player.cell,p): places.append(p)
	places.sort_custom(func(a,b):
		var da: int=a.distance_squared_to(player.cell)
		var db: int=b.distance_squared_to(player.cell)
		if da!=db:return da<db
		if a.x!=b.x:return a.x>b.x
		return a.y<b.y)
	var count:=0
	for place in places:
		if actors.any(func(a):return distance(a.cell,place)<2.0):continue
		spawn_actor("chicken" if count%2==0 else "skeleton",place,false)
		count+=1
		if count==5:break
	message="陪练已就位：鸡为生物，骷髅为不死系。Q 施法，空格普攻。"

func spawn_actor(kind: String, cell: Vector2i, ally: bool) -> Dictionary:
	var a: Dictionary={"id":next_id,"kind":kind,"cell":cell,"anchor":Vector2(cell)*ClassicPlayer.CELL,"from":cell,"progress":1.0,"direction":6,"action":"stand","anim":0.0,"hp":240.0,"max_hp":240.0,"ally":ally,"statuses":{},"timer":0.0,"dead":0.0}
	next_id+=1; actors.append(a);return a

func occupied(cell: Vector2i, except_id := -1) -> bool:
	for a in actors:
		if int(a.id)!=except_id and a.hp>0 and a.cell==cell: return true
	return false

func near(cell: Vector2i, ally := false, radius := 1.5) -> Dictionary:
	var best: Dictionary={}; var distance:=radius*radius
	for a in actors:
		if bool(a.ally)!=ally or a.hp<=0:continue
		var d:=Vector2(a.cell-cell).length_squared()
		if d<distance:distance=d;best=a
	return best

func distance(a: Vector2i,b: Vector2i) -> float:
	return Vector2(a-b).length()

func aim(cell: Vector2i) -> int:
	var v:=Vector2(cell-player.cell)
	return player.direction if v==Vector2.ZERO else posmod(roundi((v.angle()+PI/2)/(PI/4)),8)

func line_clear(a: Vector2i,b: Vector2i) -> bool:
	var count:=maxi(absi(a.x-b.x),absi(a.y-b.y))
	var prev:=a
	for i in range(1,count+1):
		var p:=Vector2i(Vector2(a).lerp(Vector2(b),float(i)/count).round())
		if p!=prev and not nav.can_step(prev,p):return false
		prev=p
	return true

func add_effect(skill: Dictionary, stage: String, at: Vector2, direction: int, duration := -1.0, target := Vector2.INF) -> void:
	if not skill.gfx.has(stage): return
	var gfx: Dictionary=skill.gfx[stage]
	var end:=at if target==Vector2.INF else target
	effects.append({"gfx":gfx,"at":at,"end":end,"direction":direction,"time":0.0,"duration":float(gfx.count)*0.075 if duration<0 else duration})
	if effects.size()>128:effects.pop_front()

func begin_visual(skill: Dictionary,target: Vector2i) -> void:
	var at:=player.anchor
	var end:=Vector2(target)*ClassicPlayer.CELL
	add_effect(skill,"启动",at,player.direction)
	audio.skill_sound(skill,0)
	var locked: Dictionary=near(target) if skill.kind in ["projectile","bolt","holy","charm","poison","reveal"] else {}
	var delay:=0.30
	if skill.kind=="projectile":
		delay+=clampf(distance(player.cell,target)*0.065,0.18,0.65)
		pending.append({"time":0.30,"type":"projectile","skill":skill,"at":at,"end":end,"direction":player.direction,"duration":delay-0.3,"locked":locked})
	pending.append({"time":delay,"type":"impact","skill":skill,"cell":target,"origin":player.cell,"direction":player.direction,"locked":locked})

func cast(target: Vector2i) -> bool:
	if not enabled or cooldown>0 or cast_time>0: return false
	var skill: Dictionary=skills[selected]
	if skill.kind=="passive" or skill.kind=="empower":
		message=skill.description+" 按空格试用普通攻击。"
		return false
	if player.progress<1:
		player.route.clear();message="先停稳，再施放技能。";return false
	if not nav.walkable(target):message="请瞄准可通行区域。";return false
	if distance(player.cell,target)>9:message="目标超出九格试练范围。";return false
	var self_kinds: Array=["repel","nova","shield","invisible","fireblade","summon","teleport"]
	if skill.kind not in self_kinds and not line_clear(player.cell,target):message="墙体挡住了目标。";return false
	if skill.kind in ["bolt","holy","charm","poison","reveal","projectile"] and near(target).is_empty():
		message="请把鼠标指向陪练目标。";return false
	if skill.kind in ["pierce","cleave"] and distance(player.cell,target)>2.9:message="近战技能需要靠近目标。";return false
	var cost:=8.0 if job=="战士" else 16.0
	if mp<cost:message="法力不足，稍等恢复或按 R 重置试练。";return false
	mp-=cost;total_casts+=1;cooldown=0.85;cast_time=0.45;action="attack" if job=="战士" else "cast"
	player.route.clear();player.direction=aim(target)
	buffs.erase("隐身")
	if skill.kind in self_kinds:target=player.cell
	begin_visual(skill,target)
	message=skill.name+" · "+skill.description
	return true

func strike(target: Vector2i) -> bool:
	if not enabled or cooldown>0 or player.progress<1: return false
	var enemy:=near(target,false,1.1)
	if enemy.is_empty() or distance(player.cell,enemy.cell)>1.5 or not line_clear(player.cell,enemy.cell):message="靠近陪练目标后按空格攻击。";return false
	attack_count+=1;cooldown=0.55;cast_time=0.42;action="attack";player.route.clear();player.direction=aim(enemy.cell);buffs.erase("隐身")
	audio.play_sound("01010034")
	var damage:=32.0 if job=="战士" else 20.0
	if job=="战士" and attack_count%3==0:
		damage+=20;add_effect(find_skill("攻杀剑术"),"运行",player.anchor,player.direction)
	if buffs.has("烈火"):
		damage+=75;buffs.erase("烈火");add_effect(find_skill("烈火剑法"),"运行",player.anchor,player.direction)
	# Basic swordsmanship / spirit combat reduce the miss frequency in trial rules.
	if attack_count% (12 if job in ["战士","道士"] else 5)==0:message="普通攻击未命中。";return true
	pending.append({"type":"strike","time":0.22,"target":enemy,"damage":damage})
	return true

func find_skill(name: String) -> Dictionary:
	for s in catalog.skills:
		if s.name==name:return s
	return {}

func hurt(a: Dictionary,damage: float,magic := true,ignore_armor := false) -> void:
	if a.is_empty() or a.hp<=0:return
	var armor:=0.0 if ignore_armor else (4.0 if magic else 10.0)
	if a.statuses.has("红毒"):armor=0;damage*=1.2
	if a.statuses.has("幽灵盾") and magic:armor+=10
	if a.statuses.has("战甲") and not magic:armor+=10
	a.hp=maxf(0,float(a.hp)-maxf(1,damage-armor));a.statuses.erase("禁锢");a.action="hit";a.anim=0
	audio.play_sound("01010050",0.45)
	if a.hp<=0:a.action="die";a.dead=3.0;a.ally=false

func push_actor(a: Dictionary,dir: Vector2i,steps: int) -> void:
	for i in range(steps):
		var p: Vector2i=a.cell+dir
		if not nav.can_step(a.cell,p) or occupied(p,int(a.id)) or p==player.cell:break
		a.cell=p;a.anchor=Vector2(p)*ClassicPlayer.CELL;a.progress=1.0

func apply_skill(s: Dictionary,target: Vector2i,origin: Vector2i,dir: int) -> void:
	var kind: String=s.kind
	var at:=Vector2(target)*ClassicPlayer.CELL
	var victim:=near(target)
	if kind=="projectile":
		add_effect(s,"裂解",at,dir);audio.skill_sound(s,2)
	else:
		add_effect(s,"运行",at,dir,8.0 if kind=="field" else -1.0)
		add_effect(s,"裂解",at,dir)
		audio.skill_sound(s,1)
		if not s.sounds.has("1"):audio.skill_sound(s,2)
	match kind:
		"projectile","bolt": hurt(victim,65.0 if s.name=="大火球" else 48.0)
		"pierce","cleave","line":
			var facing:=Vector2(ClassicNavigation.DIRECTIONS[dir]).normalized()
			for a in actors:
				if a.ally:continue
				var offset:=Vector2(a.cell-origin);var along:=offset.dot(facing);var side:=absf(offset.cross(facing))
				var hit:=along>0 and along<= (6.0 if kind=="line" else 2.9) and side<0.6
				if kind=="cleave":hit=along>=0 and offset.length()<=1.5
				if hit and line_clear(origin,a.cell):hurt(a,48.0,kind=="line",kind=="pierce" and offset.length()>1.5)
			if job=="战士":audio.play_sound("01010034")
		"aoe","nova":
			for a in actors:
				if not a.ally and distance(a.cell,target)<=2.5 and line_clear(target,a.cell):hurt(a,52.0)
		"field":fields.append({"cell":target,"until":clock+8.0})
		"poison":
			if not victim.is_empty():victim.statuses["红毒" if red_poison else "绿毒"]=clock+12.0
		"repel":
			for a in actors:
				if not a.ally and distance(origin,a.cell)<=2.5:push_actor(a,ClassicNavigation.DIRECTIONS[aim(a.cell)],2)
		"charge":
			var direction: Vector2i=ClassicNavigation.DIRECTIONS[dir]
			for i in range(3):
				var next:=player.cell+direction
				if not nav.can_step(player.cell,next):break
				for a in actors:
					if a.cell==next:push_actor(a,direction,1)
				if occupied(next):break
				player.reset(next);player.direction=dir
			audio.play_sound("01000003")
		"teleport":
			for i in range(100):
				var next:=player.cell+Vector2i(rng.randi_range(-8,8),rng.randi_range(-8,8))
				if nav.walkable(next) and not occupied(next):
					player.reset(next);add_effect(s,"裂解",player.anchor,dir);break
		"shield":buffs["魔法盾"]=clock+15.0
		"fireblade":buffs["烈火"]=clock+15.0
		"invisible":buffs["隐身"]=clock+15.0
		"group_invisible","magic_armor","armor","group_heal","heal":
			var key: String={"group_invisible":"隐身","magic_armor":"幽灵盾","armor":"战甲","group_heal":"治愈","heal":"治愈"}[kind]
			var radius:=2.5 if kind!="heal" else 1.1
			if distance(player.cell,target)<=radius:buffs[key]=clock+(6.0 if key=="治愈" else 15.0)
			for a in actors:
				if a.ally and distance(a.cell,target)<=radius:a.statuses[key]=clock+(6.0 if key=="治愈" else 15.0)
		"summon":
			actors=actors.filter(func(a):return not a.get("summoned",false))
			for d in ClassicNavigation.DIRECTIONS:
				var next: Vector2i=player.cell+d
				if nav.can_step(player.cell,next) and not occupied(next):
					var pet:=spawn_actor("beast" if s.name=="召唤神兽" else "pet_skeleton",next,true)
					pet["summoned"]=true;break
		"holy":
			if not victim.is_empty() and victim.kind=="skeleton":hurt(victim,1000.0,true,true)
			else:message="圣言术对不死系有效；鸡是生物。"
		"charm":
			if not victim.is_empty() and victim.kind=="chicken":
				var count:=int(victim.get("charm_count",0))+1;victim["charm_count"]=count
				if count>=2:
					for a in actors:
						if a.get("charmed",false):a.ally=false;a.erase("charmed")
					victim.ally=true;victim["charmed"]=true;message="诱惑成功，鸡成为同伴。"
				else:message="鸡意志动摇，再施放一次可完成试练诱惑。"
			else:message="此陪练为不死系，不能诱惑。"
		"trap":
			for a in actors:
				if not a.ally and distance(a.cell,target)<=2.5:a.statuses["禁锢"]=clock+8.0
		"reveal":
			if not victim.is_empty():victim.statuses["洞察"]=clock+15;message="心灵启示：目标生命 %d / %d（专用声画待补）" % [victim.hp,victim.max_hp]

func update(delta: float) -> void:
	if not enabled:return
	clock+=delta;tick+=delta;cooldown=maxf(0,cooldown-delta);cast_time=maxf(0,cast_time-delta)
	mp=minf(300,mp+delta*8)
	if player.action in ["walk","run"]:buffs.erase("隐身")
	for key in buffs.keys():
		if clock>=float(buffs[key]):buffs.erase(key)
	for e in effects:
		e.time+=delta
		if e.has("follow") and e.follow.hp>0:e.end=e.follow.anchor
	effects=effects.filter(func(e):return e.time<e.duration)
	var ready: Array[Dictionary]=[]
	for event in pending:
		event.time-=delta
		if event.time<=0:ready.append(event)
	pending=pending.filter(func(e):return e.time>0)
	for e in ready:
		match e.type:
			"projectile":
				add_effect(e.skill,"运行",e.at,e.direction,e.duration,e.end)
				if not e.locked.is_empty() and not effects.is_empty():effects.back()["follow"]=e.locked
				audio.skill_sound(e.skill,1)
			"impact":
				if not e.locked.is_empty():
					if e.locked.hp<=0 or not line_clear(e.origin,e.locked.cell):continue
					e.cell=e.locked.cell
				apply_skill(e.skill,e.cell,e.origin,e.direction)
			"strike":hurt(e.target,e.damage,false)
	fields=fields.filter(func(f):return f.until>clock)
	if tick>=1:
		tick-=1
		if buffs.has("治愈"):hp=minf(360,hp+25)
		for a in actors:
			if a.hp<=0:continue
			if a.statuses.has("绿毒"):hurt(a,12.0)
			if a.statuses.has("治愈"):a.hp=minf(a.max_hp,a.hp+25)
			for f in fields:
				if not a.ally and distance(a.cell,f.cell)<=1.5 and line_clear(f.cell,a.cell):hurt(a,19.0)
	for a in actors:update_actor(a,delta)
	actors=actors.filter(func(a):return a.hp>0 or a.dead>0)
	if hp<=0:
		hp=360;mp=300;buffs.clear();hostile=false;message="试练结束，生命已恢复，陪练反击已关闭。"

func update_actor(a: Dictionary,delta: float) -> void:
	a.anim+=delta;a.timer-=delta
	for key in a.statuses.keys():
		if clock>=float(a.statuses[key]):a.statuses.erase(key)
	if a.hp<=0:a.dead-=delta;return
	if a.progress<1:
		a.progress=minf(1,a.progress+delta/0.4)
		a.anchor=Vector2(a.from).lerp(Vector2(a.cell),a.progress)*ClassicPlayer.CELL
		return
	if a.statuses.has("禁锢"):a.action="stand";return
	if a.timer>0:return
	a.timer=0.6
	var goal: Vector2i=player.cell
	var enemy: Dictionary={}
	if a.ally:
		enemy=near(a.cell,false,8.0)
		if not enemy.is_empty():goal=enemy.cell
	else:
		if not hostile or buffs.has("隐身"):a.action="stand";return
	if distance(a.cell,goal)<=1.5 and line_clear(a.cell,goal):
		if a.ally and enemy.is_empty():a.action="stand";return
		a.action="attack";a.anim=0
		if a.ally:hurt(enemy,38.0 if a.kind=="beast" else 22.0)
		else:
			var damage:=14.0
			if buffs.has("战甲") and not hostile_magic:damage-=7
			if buffs.has("幽灵盾") and hostile_magic:damage-=7
			if buffs.has("魔法盾"):damage*=0.4
			hp-=damage;audio.play_sound(hurt_sound,0.4)
		return
	var route:=nav.path(a.cell,goal)
	if route.size()>1 and not occupied(route[1],a.id) and route[1]!=player.cell:
		a.from=a.cell;a.cell=route[1];a.direction=ClassicNavigation.DIRECTIONS.find(a.cell-a.from);a.progress=0;a.action="walk";a.anim=0
	else:a.action="stand"
