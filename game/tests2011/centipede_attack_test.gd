extends SceneTree
const CentipedeAttack=preload("res://scripts/edition2011/centipede_attack.gd")
var app
var checks:=0
var failures: Array=[]
var hits:=0
var magic_hits:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/centipede-attack-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(5):await process_frame
	app.set_process(false);app.start_character({"id":"centipede","name":"攻击范围检查","gender":"男","job":"战士"})
	expect(app.enter_map("d606",Vector2i(69,153)),"centipede source map loads")
	var boss: Dictionary={}
	for entity in app.world.entities:
		if entity.get("reference_name","")=="触龙神":boss=entity;break
	expect(not boss.is_empty(),"real regional centipede loaded")
	if boss.is_empty():quit(1);return
	var motion: ClassicPlayer=app.world.actors.mover(boss)
	app.world.entities=[boss];boss.dc=10;boss.dc_max=10
	app.world.monster_hit.connect(func(entity,_damage):hits+=1;if entity.get("magic_attack",false):magic_hits+=1)
	for x in range(-6,7):
		for y in range(-6,7):expect(CentipedeAttack.in_area(Vector2i.ZERO,Vector2i(x,y))==(absi(x)<=5 and absi(y)<=5),"strict square area boundary")
	for fps in [30,60,120]:
		var next: Dictionary=app.rules.state.duplicate(true);next.hp=100;next.armor_until=100;next.ghostshield_until=0;next.shield_until=0;app.rules.apply(next,"centipede_health_fixture")
		app.world.player.reset(motion.cell+Vector2i(2,0));app.world.player_alive=true;app.world.paused=false;app.world.elapsed=0;app.elapsed=0
		boss.centipede_phase="exposed";boss.aggro=true;boss.motion="stand";boss.erase("centipede_last_attack");var before:=hits
		app.world.actors.update(0,[])
		expect(boss.has("centipede_last_attack"),"actor update selects special branch")
		for frame in range(1,fps*3+1):
			app.world.elapsed=float(frame)/fps;CentipedeAttack.update(app.world,boss,motion,false)
		expect(hits==before,"no hit before strict three-second boundary")
		app.world.elapsed=3.001;CentipedeAttack.update(app.world,boss,motion,false)
		expect(hits==before+1 and app.rules.state.hp==90,"ranged magic hit reaches transaction without physical armor")
		CentipedeAttack.update(app.world,boss,motion,false);expect(hits==before+1,"same instant cannot duplicate damage")
		app.world.elapsed=6.0;CentipedeAttack.update(app.world,boss,motion,false);expect(hits==before+1,"cooldown measured from actual attack")
	var before:=hits
	app.world.player.reset(motion.cell+Vector2i(6,0));app.world.elapsed=10;CentipedeAttack.update(app.world,boss,motion,false)
	expect(hits==before and boss.motion=="attack","sixth tile triggers visual but lies outside actual damage square")
	app.world.player.reset(motion.cell+Vector2i(2,0));app.world.elapsed=14;app.world.paused=true
	CentipedeAttack.update(app.world,boss,motion,false);expect(hits==before,"paused update never hits")
	app.world.paused=false;CentipedeAttack.update(app.world,boss,motion,true);expect(hits==before,"protected target never hit")
	boss.aggro=false;CentipedeAttack.update(app.world,boss,motion,false);expect(hits==before,"no target prevents attack")
	boss.aggro=true;boss.hp=0;CentipedeAttack.update(app.world,boss,motion,false);expect(hits==before,"dead boss cannot attack")
	expect(magic_hits==hits,"all special hits carry magic channel")
	boss.hp=500;boss.aggro=true;boss.centipede_last_attack=14;app.world.elapsed=18;app.elapsed=18
	var ally: Dictionary={"id":"ally-near","name":"青禾","kind":"traveler","hp":250,"generation":0,"cell":[motion.cell.x+5,motion.cell.y],"ac":999,"mac":3}
	var far: Dictionary={"id":"ally-far","name":"远山","kind":"traveler","hp":250,"generation":0,"cell":[motion.cell.x+6,motion.cell.y]}
	var dead: Dictionary={"id":"ally-dead","name":"轻舟","kind":"traveler","hp":0,"generation":1,"cell":[motion.cell.x+4,motion.cell.y]}
	app.world.entities=[boss,ally,far,dead]
	var state_before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	CentipedeAttack.update(app.world,boss,motion,false)
	expect(app.rules.state==state_before and ally.hp==250,"failed area damage does not change persisted or live traveler health")
	app.store.db.query("PRAGMA query_only=OFF;");app.world.elapsed=22;app.elapsed=22
	CentipedeAttack.update(app.world,boss,motion,false)
	expect(ally.hp==243 and app.rules.state.traveler_health[ally.id].hp==243,"near traveler takes magic damage without physical AC subtraction")
	expect(far.hp==250 and dead.hp==0 and dead.generation==1,"outside and dead travelers unchanged")
	var saved: Dictionary=app.store.load_world(app.rules.character.id)
	expect(saved.traveler_health[ally.id].hp==243,"traveler area damage persists")
	var hp_before: int=ally.hp;CentipedeAttack.update(app.world,boss,motion,false)
	expect(ally.hp==hp_before,"same area pulse cannot duplicate traveler damage")
	var next: Dictionary=app.rules.state.duplicate(true);next.traveler_health[ally.id].hp=5;app.rules.apply(next,"low_ally_health_fixture");ally.hp=5
	app.world.elapsed=26;app.elapsed=26;CentipedeAttack.update(app.world,boss,motion,false)
	expect(ally.hp==0 and ally.generation==1 and app.rules.state.traveler_health[ally.id].respawn==56,"lethal area damage records one death and recovery deadline")
	state_before=app.rules.state.duplicate(true);app.gameplay.hit_traveler(ally,{"damage":100,"magic_attack":true})
	expect(app.rules.state==state_before and ally.generation==1,"dead traveler rejects repeated damage")
	expect(app.rules.recover_travelers([ally.id],55.9) and app.rules.state.traveler_health[ally.id].hp==0,"dead traveler waits full recovery interval")
	expect(app.rules.recover_travelers([ally.id],56) and app.rules.state.traveler_health[ally.id].hp==250,"area casualty recovers through existing persisted rules")
	for fps in [30,60,120]:
		boss.hp=1;boss.centipede_phase="hidden";boss.centipede_last_attack=0;boss.aggro=true;app.world.elapsed=0;app.world.paused=false
		app.world.player.reset(motion.cell+Vector2i(3,0))
		expect(not app.gameplay.can_target(boss) and app.world.actor_frame(boss)==-1,"burrow is invisible and untargetable")
		expect(motion.cell not in app.world.actors.player_reserved_cells(),"hidden boss does not occupy movement tile")
		for frame in range(1,fps*10+1):
			app.world.elapsed=float(frame)/fps;CentipedeAttack.update(app.world,boss,motion,false)
		expect(boss.centipede_phase=="hidden","strict ten second emergence cooldown")
		app.world.elapsed=10.001;CentipedeAttack.update(app.world,boss,motion,false)
		expect(boss.centipede_phase=="emerging" and boss.hp==boss.max_hp,"near target causes emergence and full health")
		expect(app.gameplay.can_target(boss) and app.world.actor_frame(boss)==70,"emergence body starts original walk frame and is attackable")
		var emerging_hp: int=boss.hp
		for hit in range(1,4):
			app.world.elapsed=10.001+float(hit)*0.5
			app.apply_attack_hit(boss,{"damage":1,"skill":"halfmoon"})
			expect(boss.motion=="emerge" and is_equal_approx(float(boss.motion_time),10.001),"nonlethal hits preserve emergence animation and clock")
		expect(boss.hp==emerging_hp-3,"emerging boss still takes damage")
		app.world.elapsed=12.002;CentipedeAttack.update(app.world,boss,motion,false)
		expect(boss.centipede_phase=="exposed","emergence finishes before ordinary attacks")
		app.world.player.reset(motion.cell+Vector2i(7,0));app.world.elapsed=20.001;CentipedeAttack.update(app.world,boss,motion,false)
		expect(boss.centipede_phase=="exposed","no retreat at exact cooldown")
		app.world.elapsed=20.002;CentipedeAttack.update(app.world,boss,motion,false)
		expect(boss.centipede_phase=="receding" and not app.gameplay.can_target(boss) and app.world.actor_frame(boss)==80,"retreat animates and immediately rejects targeting")
		var health_before: int=boss.hp;app.apply_attack_hit(boss,{"damage":9999})
		expect(boss.hp==health_before,"already dispatched hit cannot damage retreating boss")
		app.world.elapsed=22.003;CentipedeAttack.update(app.world,boss,motion,false)
		expect(boss.centipede_phase=="hidden" and app.world.actor_frame(boss)==-1,"retreat returns to invisible state")
	boss.hp=123;boss.centipede_phase="emerging";boss.centipede_last_attack=70;boss.motion="emerge";boss.motion_time=70
	app.elapsed=70.5;app.world.elapsed=70.5;app.world.player.reset(Vector2i(69,153))
	var saved_phase: Dictionary=CentipedeAttack.snapshot(boss)
	expect(app.save_world(),"save special phase with ordinary world state")
	var disk: Dictionary=app.store.load_world(app.rules.character.id)
	expect(disk.special_monsters[boss.id].phase=="emerging" and disk.special_monsters[boss.id].hp==123,"phase and health persisted")
	boss.hp=100;app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.save_world() and app.store.load_world(app.rules.character.id).special_monsters[boss.id].hp==123,"failed save leaves previous boss record")
	app.store.db.query("PRAGMA query_only=OFF;")
	var fresh: Dictionary=boss.duplicate(true);fresh.centipede_phase="hidden";fresh.generation=int(boss.generation)+1;fresh.hp=fresh.max_hp
	CentipedeAttack.restore(fresh,saved_phase)
	expect(fresh.centipede_phase=="hidden" and fresh.hp==fresh.max_hp,"old generation cannot overwrite respawn")
	fresh.generation=boss.generation
	var corrupt: Dictionary=saved_phase.duplicate(true);corrupt.last_attack="bad"
	CentipedeAttack.restore(fresh,corrupt);expect(fresh.centipede_phase=="hidden","invalid phase time ignored")
	var character: Dictionary=app.rules.character.duplicate(true);var boss_id: String=boss.id
	app.world.entities=[];app.region.remembered.clear();app.region.owner_id="";app.start_character(character)
	var restored: Dictionary={}
	for entity in app.world.entities:
		if entity.id==boss_id:restored=entity;break
	expect(not restored.is_empty(),"fresh regional population restores saved boss")
	if not restored.is_empty():
		expect(restored.centipede_phase=="emerging" and restored.hp==123 and restored.motion_time==70,"reload restores phase health and animation time")
		expect(app.elapsed==70.5 and app.world.elapsed==70.5,"offline time is not added")
		var restored_motion: ClassicPlayer=app.world.actors.mover(restored)
		app.world.elapsed=71.9;CentipedeAttack.update(app.world,restored,restored_motion,false)
		expect(restored.centipede_phase=="emerging","remaining emergence time retained")
		app.world.elapsed=72.01;CentipedeAttack.update(app.world,restored,restored_motion,false)
		expect(restored.centipede_phase=="exposed","reloaded emergence completes normally")
	for invalid in [[],{"bad":"not a record"},{"bad":{"spawn_id":"x","phase":"wrong"}}]:
		var broken: Dictionary=app.rules.state.duplicate(true);broken.special_monsters=invalid
		expect(not app.rules.valid(broken),"malformed persisted special state rejected")
	var report:={"checks":checks,"failures":failures,"scope":"actual regional boss and actor branch, 30/60/120 simulated timing, strict square range, magic damage transaction, pause/protection/death; isolated boss, positions and low damage fixtures; near/far/dead AI player damage, magic defense, write failure, repeat prevention, death/recovery persistence covered with traveler fixtures; burrow/near emergence/full heal/retreat/late-hit rejection covered at 30/60/120; phase save/reload, write failure and stale generation rejection covered; poison and full combat pending"}
	FileAccess.open("res://../artifacts/world-story/centipede-attack-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
