extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(3):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/old-trials-return-routes-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"return-routes","name":"归程核验","gender":"男","job":"战士"});app.world.hide();app.world.paused=true
	var npc: Dictionary=app.rules.story_npc("server:merchant:80")
	var components: Array=Planner.npc_components(app.resources,npc)
	expect(not components.is_empty(),"recipient has reachable arrival component")
	var recorded: Dictionary={}
	for mid in ["q011","q012","q013","q014","q015"]:
		expect(app.enter_map(mid),"load actual starting map "+mid);app.world.paused=true
		expect(app.world.entities.any(func(e):return e.get("reference_name","")=="沃玛卫士2"),"actual reference guardian present "+mid)
		var path: Array=Planner.plan(app.resources.connections.by_map,mid,npc.map,app.world.player.cell,app.world.navigation,components)
		expect(not path.is_empty(),"return path exists to recipient component "+mid)
		expect(path.size()<=3,"expedition return requires at most three crossings "+mid)
		if path.is_empty():continue
		recorded[mid]=path.map(func(row):return row.id)
		for leg in path:
			expect(app.world.metadata.id==leg.map,"route preserves current map")
			var door:=Vector2i(leg.cell[0],leg.cell[1])
			expect(app.world.player.cell==door or not app.world.navigation.path(app.world.player.cell,door).is_empty(),"actual NPC collision allows departure "+leg.id)
			expect(app.enter_map(leg.target_map,Vector2i(leg.target_cell[0],leg.target_cell[1])),"load registered arrival "+leg.id)
			app.world.paused=true
			expect(app.world.navigation.mobile(app.world.player.cell),"arrival can move "+leg.id)
		expect(app.world.metadata.id==npc.map,"return reaches recipient map")
		var reachable:=false;var at:=Vector2i(npc.cell[0],npc.cell[1])
		for direction in ClassicNavigation.DIRECTIONS:
			var target: Vector2i=at+direction
			if app.world.navigation.walkable(target) and (target==app.world.player.cell or not app.world.navigation.path(app.world.player.cell,target).is_empty()):reachable=true;break
		expect(reachable,"final landing reaches recipient adjacent tile "+mid)
		await settle()
	var crossings:=0
	for mid in ["3","q011","q012","q013","q014","q015"]:
		for leg in app.resources.connections.by_map[mid]:
			if leg.get("source",{}).get("rule","")!="old_trials_expedition_v1":continue
			crossings+=1
			var door:=Vector2i(leg.cell[0],leg.cell[1])
			expect(app.enter_map(mid,door),"load expedition doorway")
			app.world.paused=false
			expect(app.world.player.cell==door,"door is not displaced by NPC collision")
			expect(app.cross_passage(leg),"actual expedition transition "+leg.id)
			expect(app.rules.state.map==leg.target_map,"expedition destination persisted")
			expect(app.world.navigation.mobile(app.world.player.cell),"expedition arrival mobile")
	expect(crossings==12,"six bidirectional expedition connections")
	var report:={"checks":checks,"failures":failures,"routes":recorded,"scope":"actual starting defaults, each return landing and door with NPC collision, final recipient approach; direct map loading rather than time-based walking"}
	FileAccess.open("res://../artifacts/world-story/old-trials-return-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
