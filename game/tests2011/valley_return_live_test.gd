extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var checks:=0
var failures: Array=[]
var frames:=0
var retries:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func walk(target: String="") -> void:
	for i in range(60*600):
		app._process(1.0/60);frames+=1
		if app.rules.state.hp<=0:break
		if not target.is_empty() and app.world.metadata.id==target:break
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/valley-return-live-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"return","name":"回村路上","job":"战士","gender":"男"});app.world.hide()
	var host: Dictionary=app.rules.story_npc("server:merchant:60")
	app.enter_map(host.map,Vector2i(host.cell[0]+1,host.cell[1]));app.world.paused=false
	var elder: Dictionary=app.rules.story_npc("border:elder")
	var components: Array=Planner.npc_components(app.resources,elder)
	var route: Array=Planner.plan(app.resources.connections.by_map,app.world.metadata.id,"0",app.world.player.cell,app.world.navigation,components)
	expect(not route.is_empty(),"route from valley to village component")
	for gate in route:
		expect(gate.kind=="reference","return uses original map doorway")
		expect(app.world.approach(Vector2i(gate.cell[0],gate.cell[1])),"can approach exit")
		walk(gate.target_map)
		expect(app.world.metadata.id==gate.target_map and app.rules.state.hp>0,"cross doorway alive")
		if app.world.metadata.id!=gate.target_map or app.rules.state.hp<=0:break
	expect(app.world.metadata.id=="0","reach Bichon through normal exit")
	app.approach_story_npc(elder.id);walk()
	for retry in range(3):
		if app.rules.story_near(elder.id,app.world.metadata.id,app.world.player.cell) or app.rules.state.hp<=0:break
		for i in range(60):app._process(1.0/60);frames+=1
		retries+=1;app.approach_story_npc(elder.id);walk()
	expect(app.rules.story_near(elder.id,app.world.metadata.id,app.world.player.cell),"walk to actual village elder after crossing")
	expect(app.save_world(),"save returned location")
	var saved: Dictionary=app.store.load_world("return")
	expect(saved.map=="0" and Vector2(saved.cell[0]-elder.cell[0],saved.cell[1]-elder.cell[1]).length()<=4,"saved return location near village elder")
	var report:={"checks":checks,"failures":failures,"simulated_seconds":frames/60.0,"hp":app.rules.state.hp,"navigation_retries":retries,"scope":"full main loop, original door crossing and walk to elder with up to three explicit retries after waiting; initial valley merchant position fixture, no stat boost or physical input/performance measurement"}
	FileAccess.open("res://../artifacts/world-story/valley-return-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
