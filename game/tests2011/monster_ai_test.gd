extends SceneTree
class Fixture extends RefCounted:
	signal actor_sound(id,position,event)
	signal monster_hit(entity,damage)
	var navigation:=ClassicNavigation.new()
	var player:=ClassicPlayer.new()
	var player_alive:=true
	var metadata:={"id":"ai-fixture"}
	var elapsed:=0.0
	var paused:=false
	var entities: Array=[]
var failures: Array=[]
var checks:=0
func expect(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr(label)
func fixture() -> Fixture:
	var w:=Fixture.new();var cells: Array=[]
	for y in range(40):
		var row: Array=[];row.resize(40);row.fill(true);cells.append(row)
	w.navigation.configure({"size":[40,40],"walkable":cells});w.player.nav=w.navigation;w.player.reset(Vector2i(10,10));return w
func monster() -> Dictionary:
	return {"id":"test","kind":"monster","name":"test","cell":[10,11],"origin":[10,11],"hp":100,"max_hp":100,"passive":false,"dc":1,"dc_max":1,"attack_ms":2000,"walk_ms":400,"walk_step":3,"walk_wait_ms":1000,"appearance":0,"profile":{"sounds":{},"actions":{}}}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var w:=fixture();var e:=monster();var motion:=ClassicPlayer.new();motion.nav=w.navigation;motion.reset(Vector2i(10,11))
	for d in ClassicNavigation.DIRECTIONS:expect(EditionMonsterAI.melee(w.navigation,w.player.cell+d,w.player.cell),"eight equal melee directions "+str(d))
	expect(not EditionMonsterAI.melee(w.navigation,Vector2i(10,12),w.player.cell),"two tiles cannot melee")
	w.navigation.set_occupied([Vector2i(10,11)])
	expect(not EditionMonsterAI.melee(w.navigation,Vector2i(11,11),w.player.cell),"closed corner cannot melee")
	w.navigation.set_occupied([])
	EditionMonsterAI.update_target(w,e,motion,0.5);expect(not e.get("aggro",false),"search waits reference interval")
	EditionMonsterAI.update_target(w,e,motion,0.51);expect(e.aggro,"hostile detects nearby player")
	w.player.reset(Vector2i(30,30));EditionMonsterAI.update_target(w,e,motion,0.1);expect(not e.aggro,"15 Manhattan tiles loses target")
	w.player.reset(Vector2i(10,10));e.aggro=true;w.player_alive=false;EditionMonsterAI.update_target(w,e,motion,0.1);expect(not e.aggro,"dead player cannot retain target")
	w.player_alive=true;e.passive=true;EditionMonsterAI.update_target(w,e,motion,2);expect(not e.aggro,"passive animal does not acquire target")
	e.aggro=true;e.focus_time=0;w.elapsed=31;EditionMonsterAI.update_target(w,e,motion,0.1);expect(not e.aggro,"focus expires after thirty seconds")
	e.hp=50;e.regen_left=6;EditionMonsterAI.update_target(w,e,motion,5.9);expect(e.hp==50,"no early regeneration")
	EditionMonsterAI.update_target(w,e,motion,0.11);expect(e.hp==52,"reference maxHP/75+1 regeneration")
	motion.reset(Vector2i(15,15));EditionMonsterAI.approach(w,motion)
	expect(not motion.route.is_empty() and not w.player.cell in motion.route,"chase path excludes occupied player tile")
	expect(EditionMonsterAI.melee(w.navigation,motion.route.back(),w.player.cell),"chase ends at attack tile")
	var counts: Array=[]
	for fps in [30,60,120]:
		w=fixture();e=monster();e.aggro=true;e.focus_time=0;e.stationary=true;w.entities=[e]
		var actors:=EditionActors.new();actors.world=w;var hits: Array=[]
		w.monster_hit.connect(func(_e,damage):hits.append(damage))
		for i in range(fps*10):w.elapsed+=1.0/fps;actors.update(1.0/fps,[])
		counts.append(hits.size());expect(hits.size()==5,"one hit per attack at "+str(fps)+" FPS")
		var before: int=hits.size();w.paused=true
		for i in range(60):actors.update(1.0,[])
		expect(hits.size()==before,"paused combat frozen "+str(fps))
		w.paused=false;w.player_alive=false
		for i in range(fps*3):w.elapsed+=1.0/fps;actors.update(1.0/fps,[])
		expect(hits.size()==before,"no post-death damage "+str(fps))
	w=fixture();e=monster();w.entities=[e]
	var chasing:=EditionActors.new();chasing.world=w
	e.cell=[15,15];e.origin=e.cell.duplicate()
	for i in range(900):w.elapsed+=1.0/60;chasing.update(1.0/60,[])
	var end: ClassicPlayer=chasing.mover(e)
	expect(end.cell!=w.player.cell and EditionMonsterAI.melee(w.navigation,end.cell,w.player.cell),"live chase stops adjacent after walking")
	var zones: Array=EditionRegion.data().safe_zones
	zones.append({"enabled":true,"map":"ai-fixture","cell":[10,10],"radius":0})
	EditionMonsterAI.update_target(w,e,end,0.1);expect(not e.aggro,"safe zone drops aggro")
	zones.pop_back()
	w=fixture();e=monster();e.aggro=true;e.focus_time=0;e.stationary=true;w.entities=[e]
	var interrupted:=EditionActors.new();interrupted.world=w;var late_hits: Array=[]
	w.monster_hit.connect(func(_e,damage):late_hits.append(damage))
	interrupted.update(0.01,[]);expect(e.get("motion")=="attack","windup began")
	w.player.reset(Vector2i(10,13))
	for i in range(60):w.elapsed+=1.0/60;interrupted.update(1.0/60,[])
	expect(late_hits.is_empty(),"moving out during windup prevents damage")
	# Multiple monsters reserve different attack tiles and never share a step end.
	w=fixture();var group:=EditionActors.new();group.world=w
	for i in range(4):
		var member:=monster();member.id="pack-"+str(i);member.cell=[14,8+i];member.origin=member.cell.duplicate();member.aggro=true;member.focus_time=0;w.entities.append(member)
	var overlap:=false
	for i in range(1200):
		w.elapsed+=1.0/60;group.update(1.0/60,[])
		var reserved: Dictionary={}
		for member in w.entities:
			var moving:=group.mover(member)
			for tile in [moving.cell,moving.destination]:
				if reserved.has(tile) and reserved[tile]!=member.id:overlap=true
				reserved[tile]=member.id
	expect(not overlap,"pack does not overlap current or reserved step tiles")
	expect(w.entities.all(func(member):return EditionMonsterAI.melee(w.navigation,group.mover(member).cell,w.player.cell)),"pack approaches distinct melee slots")
	# Replan around a dynamically occupied direct route, restoring static nav.
	w=fixture();motion=ClassicPlayer.new();motion.nav=w.navigation;motion.reset(Vector2i(14,10))
	EditionMonsterAI.approach(w,motion,{Vector2i(13,10):true,Vector2i(11,10):true})
	expect(not motion.route.is_empty() and Vector2i(13,10) not in motion.route and Vector2i(11,10) not in motion.route,"chase routes around other creatures")
	expect(w.navigation.occupied.is_empty(),"temporary combat occupancy cannot corrupt map navigation")
	var data:=EditionRegion.data()
	for name in data.monsters:
		var spec: Dictionary=data.monsters[name];var race:=int(spec.raw.race)
		var actual:=EditionRegion.entity_from({"runtime_id":"fixture","name":name,"interval":10},spec,"fixture",0,Vector2i.ZERO,0)
		if race==53:expect(not actual.passive,"wolf actively searches "+name)
		if race==80:expect(actual.passive,"base TMonster passive "+name)
		if race==83:expect(actual.attack_ms==(actual.walk_ms+900)*2,"slow race attack doubled "+name)
		if race in [55,85,103,107,110,111,112,115,116]:expect(actual.stationary,"fixed monster cannot wander "+name)
	var hit_target:=monster();hit_target.motion="attack";hit_target.motion_time=5.0;hit_target.strike_done=false
	EditionMonsterAI.react_to_hit(hit_target,5.1)
	expect(hit_target.motion=="attack" and hit_target.motion_time==5.0 and not hit_target.strike_done,"damage cannot cancel committed counterattack")
	hit_target.motion="stand"
	EditionMonsterAI.react_to_hit(hit_target,6.0)
	EditionMonsterAI.react_to_hit(hit_target,6.1)
	expect(hit_target.motion_time==6.0,"rapid hits do not restart flinch")
	EditionMonsterAI.react_to_hit(hit_target,6.7)
	expect(hit_target.motion_time==6.7,"later hit can flinch again")
	hit_target.motion="stand"
	EditionMonsterAI.react_to_hit(hit_target,8.0,true)
	expect(hit_target.motion=="stand" and hit_target.aggro and hit_target.focus_time==8.0,"poison provokes without interrupting motion")
	var result:={"checks":checks,"failures":failures,"hits_at_30_60_120_fps":counts}
	var file:=FileAccess.open("res://../artifacts/combat-passages-0.9.8/behavior-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
