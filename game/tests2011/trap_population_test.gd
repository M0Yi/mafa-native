extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func talk(id: String) -> void:
	var npc: Dictionary=app.rules.story_npc(id)
	app.rules.story_talk(id,npc.map,Vector2i(npc.cell[0],npc.cell[1]))
var database:="/tmp/trap-population-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
func open_app() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path=database;root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"population","name":"真实怪物恢复","job":"道士","gender":"男"});app.world.hide();app.world.paused=false
func run() -> void:
	var Trap=preload("res://scripts/edition2011/trap_status.gd")
	await open_app()
	app.enter_map("1",Vector2i(300,299));app.world.paused=false
	var candidates: Array=app.world.entities.filter(func(e):return e.has("spawn_id") and Trap.eligible(e,100))
	expect(not candidates.is_empty(),"natural population contains eligible monster")
	if candidates.is_empty():app.queue_free();await settle();quit(1);return
	var monster: Dictionary=candidates[0];var id: String=monster.id
	app.elapsed=10;app.world.elapsed=10;monster.trap_status=Trap.create(monster,100,3,10)
	var generation: int=int(monster.generation)
	expect(app.save_world(),"save naturally generated controlled monster")
	app.queue_free();await settle();await open_app()
	var found: Array=app.world.entities.filter(func(e):return e.id==id)
	expect(found.size()==1,"fresh scene restores same natural monster once")
	if found.size()==1:
		monster=found[0]
		expect(monster.has("trap_status") and int(monster.generation)==generation,"fresh population receives saved control")
		expect(app.elapsed==10 and monster.get("trap_status",{}).get("expires",0)==26,"remaining time does not reset or advance offline")
		var motion=app.world.actors.mover(monster);var anchor=motion.anchor
		app.world.actors.update(1.0/60,[])
		expect(motion.anchor==anchor and monster.motion=="stand","restored actor obeys control")
		monster.hp-=1;app.world.actors.update(1.0/60,[])
		expect(not monster.has("trap_status"),"damage removes restored control")
		var routes: Array=app.resources.connections.by_map[app.world.metadata.id].duplicate()
		routes.sort_custom(func(a,b):return Vector2(a.cell[0],a.cell[1]).distance_squared_to(Vector2(app.world.player.cell))<Vector2(b.cell[0],b.cell[1]).distance_squared_to(Vector2(app.world.player.cell)))
		var target: Dictionary={}
		for route in routes:
			if route.target_map!=app.world.metadata.id and app.world.approach(Vector2i(route.cell[0],route.cell[1])):target=route;break
		expect(not target.is_empty(),"find walkable inter-map doorway")
		var crossed:=false
		for frame in range(60000):
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
			var gate: Dictionary=app.resources.connections.poll(app.world.player)
			if not gate.is_empty():crossed=app.cross_passage(gate);break
			if app.world.player.route.is_empty() and app.world.player.progress>=1:break
		expect(crossed,"actual doorway saves changed map")
		expect(app.store.load_world(app.rules.character.id).get("trapped_monsters",{}).is_empty(),"doorway clears broken control without manual save")
	app.queue_free();await settle();await open_app()
	app.enter_map("1",Vector2i(300,299));app.world.paused=false
	found=app.world.entities.filter(func(e):return e.id==id)
	expect(found.size()==1 and not found[0].has("trap_status"),"second fresh scene does not revive broken control")
	var next: Dictionary=app.rules.state.duplicate(true);app.rules.count_item(next,"return_stone",1)
	expect(app.rules.apply(next,"return_stone_fixture"),"prepare return item")
	if found.size()==1:
		monster=found[0];monster.trap_status=Trap.create(monster,100,3,app.elapsed)
		expect(app.save_world(),"persist control before return item")
		monster.erase("trap_status")
		var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.gameplay.use_type("return_stone") and app.rules.state==before and app.world.metadata.id=="1","failed return retains item and origin")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.gameplay.use_type("return_stone"),"use actual return item")
		expect(app.rules.state.map=="0" and int(app.rules.state.inventory.get("return_stone",0))==0,"return position and item debit commit")
		expect(app.store.load_world(app.rules.character.id).get("trapped_monsters",{}).is_empty(),"return item clears stale control atomically")
	var report:={"checks":checks,"failures":failures,"scope":"natural population and two fresh app instances with same isolated SQLite store; trap, caster level, damage and time injected; no physical input or full cast-to-exit flow"}
	FileAccess.open("res://../artifacts/world-story/trap-population-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
