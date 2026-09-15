extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(3):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/archive-routes-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"archive","name":"见闻归档","gender":"男","job":"战士"});app.world.hide()
	var legs: Array=[]
	for pair in [["server:merchant:118","server:merchant:9"],["server:merchant:9","server:merchant:4"],["server:merchant:4","server:merchant:118"],["server:merchant:118","server:merchant:4"]]:
		var origin: Dictionary=app.rules.story_npc(pair[0]);var target: Dictionary=app.rules.story_npc(pair[1])
		expect(app.enter_map(origin.map,Vector2i(origin.cell[0],origin.cell[1])+Vector2i.DOWN),"load actual source neighborhood")
		app.world.paused=false
		var path: Array=[]
		if origin.map!=target.map:
			path=Planner.plan(app.resources.connections.by_map,origin.map,target.map,app.world.player.cell,app.world.navigation,Planner.npc_components(app.resources,target))
			expect(not path.is_empty() and path.size()<=4,"archive recipient reachable within four crossings "+str(pair))
			for gate in path:
				expect(not app.world.navigation.path_avoiding(app.world.player.cell,Vector2i(gate.cell[0],gate.cell[1]),app.world.player.path_avoid).is_empty(),"departure is geometrically reachable")
				expect(app.enter_map(gate.target_map,Vector2i(gate.target_cell[0],gate.target_cell[1])),"actual intermediate landing")
				app.world.paused=false
			expect(app.world.metadata.id==target.map,"route ends on recipient map")
		expect(app.world.approach(Vector2i(target.cell[0],target.cell[1])),"recipient has a reachable unoccupied approach")
		legs.append({"from":pair[0],"to":pair[1],"crossings":path.size()})
	var report:={"checks":checks,"failures":failures,"legs":legs,"scope":"actual map geometry, landing and live occupancy for archive NPC routes; source and intermediate positions are fixtures, not continuous travel or combat"}
	FileAccess.open("res://../artifacts/world-story/archive-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
