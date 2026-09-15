extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var failures: Array=[]
var checks:=0
var observed: Dictionary={}
var moved: Dictionary={}
var simulated_frames:=0
var minimum_hp:=100
func step_live() -> void:
	app._process(1.0/60);simulated_frames+=1;minimum_hp=mini(minimum_hp,int(app.rules.state.hp))
	for entity in app.world.entities:
		if entity.kind not in ["monster","traveler"]:continue
		var key: String=app.world.metadata.id+":"+str(entity.id)
		if observed.has(key) and observed[key]!=entity.cell:moved[key]=entity.kind
		observed[key]=entity.cell.duplicate()
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/sabuk-repair-live-routes-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"sabuk_story","name":"城堡见闻","gender":"男","job":"战士"});app.world.hide()
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_sabuk_storage="done";prepared.gold=1000
	var weapon_slot:=EditionInventory.SLOTS.find("weapon")
	prepared.items=prepared.items.filter(func(item):return item.container!="equipment" or int(item.slot)!=weapon_slot)
	prepared.items.append(EditionInventory.make_item("wood_sword",1,"equipment",weapon_slot,50));EditionInventory.mirror(prepared)
	expect(app.rules.apply(prepared,"sabuk_prerequisite_fixture"),"prepare prior mainland journey")
	var gates:=EditionConnections.new()
	gates.current={Vector2i(1,1):{"target_map":"room","target_component":["room",1]},Vector2i(1,2):{"target_map":"room","target_component":["room",1]},Vector2i(2,1):{"target_map":"room","target_component":["room",2]},Vector2i(2,2):{"target_map":"other","target_component":["other",1]},Vector2i(6,1):{"target_map":"room","target_component":["room",1]}}
	expect(gates.approach_cells(Vector2i(1,1))==[Vector2i(1,1),Vector2i(1,2)],"alternate door excludes different room, disconnected room island and distant entrance")
	expect(gates.approach_cells(Vector2i(9,9))==[Vector2i(9,9)],"ordinary destination unchanged")
	var legs: Array=[]
	for pair in [["server:merchant:90","server:merchant:84"],["server:merchant:84","server:merchant:90"],["server:merchant:90","server:npc:1"]]:
		var origin: Dictionary=app.rules.story_npc(pair[0]);var target: Dictionary=app.rules.story_npc(pair[1])
		if legs.is_empty():expect(app.enter_map(origin.map,Vector2i(origin.cell[0],origin.cell[1])+Vector2i.DOWN),"load initial source neighborhood")
		else:expect(app.world.metadata.id==origin.map,"continue return journey without resetting location")
		app.world.paused=false
		var quest_id: String="story_sabuk_repair" if legs.size()<2 else "story_sabuk_logistics_report"
		if legs.is_empty() or legs.size()==2:expect(app.rules.story_action(quest_id,"accept",origin.id,origin.map,app.world.player.cell),"accept at actual origin neighbor")
		var path: Array=[]
		if origin.map!=target.map:
			path=Planner.plan(app.resources.connections.by_map,origin.map,target.map,app.world.player.cell,app.world.navigation,Planner.npc_components(app.resources,target))
			expect(not path.is_empty() and path.size()<=32,"sabuk recipient reachable within thirty-two crossings "+str(pair))
			for gate in path:
				expect(app.resources.connections.approach_cells(Vector2i(gate.cell[0],gate.cell[1])).any(func(at):return not app.world.navigation.path_avoiding(app.world.player.cell,at,app.world.player.path_avoid).is_empty()),"departure is geometrically reachable")
				expect(app.world.approach(Vector2i(gate.cell[0],gate.cell[1])),"walk toward planned door")
				var crossed:=false
				for frame in range(18000):
					step_live()
					if app.world.metadata.id==gate.target_map:crossed=true;break
					if app.rules.state.hp<=0:break
				expect(crossed and app.world.metadata.id==gate.target_map,"continuous walk crosses actual door")
				if not crossed:
					print(JSON.stringify({"blocked_map":app.world.metadata.id,"cell":str(app.world.player.cell),"gate":gate,"plain_path_size":app.world.navigation.path(app.world.player.cell,Vector2i(gate.cell[0],gate.cell[1])).size(),"near_doors":app.world.player.path_avoid.filter(func(c):return c.distance_to(app.world.player.cell)<4).map(func(c):return str(c)),"near_npcs":app.world.entities.filter(func(e):return e.kind=="npc" and Vector2(e.cell[0],e.cell[1]).distance_to(Vector2(app.world.player.cell))<4)}))
					break
				app.world.paused=false
			expect(app.world.metadata.id==target.map,"route ends on recipient map")
		expect(app.world.approach(Vector2i(target.cell[0],target.cell[1])),"recipient has a reachable unoccupied approach")
		for frame in range(12000):
			if app.world.player.route.is_empty() and app.world.player.progress>=1.0:break
			step_live()
		expect((app.world.player.cell-Vector2i(target.cell[0],target.cell[1])).length()<=4.0,"continuous walk reaches NPC neighbor")
		app.interact(target);await settle()
		if target.id=="server:merchant:84":
			var before: Dictionary=app.rules.state.duplicate(true)
			expect(app.rules.reference_repair(target.id),"repair after walking to actual smith")
			expect(app.rules.state.gold<before.gold and EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest(quest_id)),"repair charges fee and advances commission")
		else:
			expect(app.rules.story_action(quest_id,"submit",target.id,target.map,app.world.player.cell),"deliver at actual reached recipient")
			expect(app.store.load_world(app.rules.character.id).quests[quest_id]=="done","commission saved at reached recipient")
		app.windows.close_all()
		legs.append({"from":pair[0],"to":pair[1],"crossings":path.size()})
	expect(not moved.is_empty(),"world entities moved during route")
	var report:={"simulated_seconds":simulated_frames/60.0,"moving_entities":moved.size(),"minimum_hp":minimum_hp,"checks":checks,"failures":failures,"legs":legs,"scope":"continuous warehouse to smith, back to warehouse and onward to palace; actual repair and both task deliveries; initial position/prerequisite/budget/worn weapon fixtures, all actors and timers update at simulated 60 Hz, no boosted health, no hardware input"}
	FileAccess.open("res://../artifacts/world-story/sabuk-repair-live-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
