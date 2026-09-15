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
	app.store.path="/tmp/pig-shops-routes-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"pig_shops","name":"石墓后勤","gender":"男","job":"战士"});app.world.hide()
	var legs: Array=[]
	for pair in [["server:merchant:80", "server:merchant:99"], ["server:merchant:99", "server:merchant:100"], ["server:merchant:100", "server:merchant:102"], ["server:merchant:102", "server:merchant:101"], ["server:merchant:101", "server:merchant:80"]]:
		var origin: Dictionary=app.rules.story_npc(pair[0]);var target: Dictionary=app.rules.story_npc(pair[1])
		expect(app.enter_map(origin.map,Vector2i(origin.cell[0],origin.cell[1])+Vector2i.DOWN),"load actual source neighborhood")
		app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
		app.world.paused=false
		var path: Array=[]
		if origin.map!=target.map:
			path=Planner.plan(app.resources.connections.by_map,origin.map,target.map,app.world.player.cell,app.world.navigation,Planner.npc_components(app.resources,target))
			expect(not path.is_empty() and path.size()<=32,"pig shop recipient reachable within thirty-two crossings "+str(pair))
			for gate in path:
				expect(not app.world.navigation.path_avoiding(app.world.player.cell,Vector2i(gate.cell[0],gate.cell[1]),app.world.player.path_avoid).is_empty(),"departure is geometrically reachable")
				expect(app.world.approach(Vector2i(gate.cell[0],gate.cell[1])),"walk toward planned door")
				var crossed:=false
				for frame in range(12000):
					app.world.player.update(1.0/60,Vector2i.ZERO,false)
					var reached: Dictionary=app.resources.connections.poll(app.world.player)
					if not reached.is_empty():
						expect(reached.target_map==gate.target_map,"walk reaches intended door")
						app.cross_passage(reached);crossed=true;break
				expect(crossed and app.world.metadata.id==gate.target_map,"continuous walk crosses actual door")
				if not crossed:
					print(JSON.stringify({"blocked_map":app.world.metadata.id,"cell":str(app.world.player.cell),"gate":gate,"occupants":app.world.actors.player_reserved_cells().map(func(c):return str(c))}))
					break
				app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
				app.world.paused=false
			expect(app.world.metadata.id==target.map,"route ends on recipient map")
		expect(app.world.approach(Vector2i(target.cell[0],target.cell[1])),"recipient has a reachable unoccupied approach")
		for frame in range(12000):
			if app.world.player.route.is_empty() and app.world.player.progress>=1.0:break
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
		expect((app.world.player.cell-Vector2i(target.cell[0],target.cell[1])).length()<2.0,"continuous walk reaches NPC neighbor")
		legs.append({"from":pair[0],"to":pair[1],"crossings":path.size()})
	var report:={"checks":checks,"failures":failures,"legs":legs,"scope":"actual map geometry and NPC occupancy for pig shop routes with monster-free encounter fixtures; source neighborhoods are fixtures; doors and NPC approaches use continuous player movement; monsters removed from fixture to isolate geometry; not proof of travel through populated encounters"}
	FileAccess.open("res://../artifacts/world-story/pig-shops-cleared-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
