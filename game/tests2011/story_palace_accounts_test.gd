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
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/palace-accounts-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"palace_accounts","name":"楼上账目","gender":"男","job":"战士"});app.world.hide()
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_letter="done"
	expect(app.rules.apply(prepared,"village_patrol_fixture"),"prepare village patrol prerequisite")
	var legs: Array=[]
	for pair in [["server:merchant:10","server:merchant:105"],["server:merchant:105","server:merchant:10"]]:
		var origin: Dictionary=app.rules.story_npc(pair[0]);var target: Dictionary=app.rules.story_npc(pair[1]);origin.id=pair[0];target.id=pair[1];target.kind="npc"
		if legs.is_empty():expect(app.enter_map(origin.map,Vector2i(origin.cell[0],origin.cell[1])+Vector2i.DOWN),"load initial source neighborhood")
		else:expect(app.world.metadata.id==origin.map,"continue return journey without resetting location")
		app.world.paused=false
		var quest_id: String="story_palace_accounts"
		if legs.is_empty():expect(app.rules.story_action(quest_id,"accept",origin.id,origin.map,app.world.player.cell),"accept at actual origin neighbor")
		var path: Array=[]
		if origin.map!=target.map:
			path=Planner.plan(app.resources.connections.by_map,origin.map,target.map,app.world.player.cell,app.world.navigation,Planner.npc_components(app.resources,target))
			expect(not path.is_empty() and path.size()<=32,"village recipient reachable within thirty-two crossings "+str(pair))
			for gate in path:
				expect(app.resources.connections.approach_cells(Vector2i(gate.cell[0],gate.cell[1])).any(func(at):return not app.world.navigation.path_avoiding(app.world.player.cell,at,app.world.player.path_avoid).is_empty()),"departure is geometrically reachable")
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
					print(JSON.stringify({"blocked_map":app.world.metadata.id,"cell":str(app.world.player.cell),"gate":gate,"plain_path_size":app.world.navigation.path(app.world.player.cell,Vector2i(gate.cell[0],gate.cell[1])).size(),"near_doors":app.world.player.path_avoid.filter(func(c):return c.distance_to(app.world.player.cell)<4).map(func(c):return str(c)),"near_npcs":app.world.entities.filter(func(e):return e.kind=="npc" and Vector2(e.cell[0],e.cell[1]).distance_to(Vector2(app.world.player.cell))<4)}))
					break
				app.world.paused=false
			expect(app.world.metadata.id==target.map,"route ends on recipient map")
		expect(app.world.approach(Vector2i(target.cell[0],target.cell[1])),"recipient has a reachable unoccupied approach "+target.id)
		for frame in range(12000):
			if app.world.player.route.is_empty() and app.world.player.progress>=1.0:break
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
		expect((app.world.player.cell-Vector2i(target.cell[0],target.cell[1])).length()<=4.0,"continuous walk reaches NPC neighbor "+target.id)
		app.interact(target);await settle()
		if legs.size()>0:expect(EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest(quest_id)),"both floor visits and merchant conversation recorded")
		if target.id=="server:merchant:10":expect(app.rules.story_action(quest_id,"submit",target.id,target.map,app.world.player.cell),"submit at walked downstairs merchant")
		app.windows.close_all()
		legs.append({"from":pair[0],"to":pair[1],"crossings":path.size()})
	var report:={"checks":checks,"failures":failures,"legs":legs,"scope":"actual map geometry, landing and live occupancy for palace floor merchant routes; one initial source neighborhood and prior quest fixture; continuous two-leg walking, real recipient interaction and delivery rules; other actors remain stationary, no combat or physical input"}
	FileAccess.open("res://../artifacts/world-story/palace-accounts-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
