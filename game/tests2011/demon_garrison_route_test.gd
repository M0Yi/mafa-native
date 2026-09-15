extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var checks:=0
var failures: Array=[]
var frames:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func clear_encounters() -> void:
	app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
func walk() -> void:
	for i in range(18000):
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
		app.world.player.update(1.0/60,Vector2i.ZERO,false);frames+=1
		var gate: Dictionary=app.resources.connections.poll(app.world.player)
		if not gate.is_empty():app.cross_passage(gate);clear_encounters();break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/demon-garrison-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"garrison","name":"军营见闻","job":"战士","gender":"男"});app.world.hide()
	var elder: Dictionary=app.rules.story_npc("server:merchant:162");var q: Dictionary=EditionRules.Story.quest("story_demon_garrison_survey")
	expect(app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1])),"prepare giver position");app.world.paused=false
	expect(not app.rules.story_action(q.id,"accept",elder.id,elder.map,app.world.player.cell),"prior expedition required")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_demon_homecoming="done";expect(app.rules.apply(next,"prior_demon_report_fixture"),"prepare completed demon expedition")
	expect(app.rules.story_action(q.id,"accept",elder.id,elder.map,app.world.player.cell),"accept garrison survey")
	app.rules.story_talk(elder.id,elder.map,app.world.player.cell)
	expect(EditionRules.Story.progress(app.rules.state,q,3)==0,"early elder talk does not count as returning report")
	expect(app.enter_map("6",Vector2i(114,148)),"prepare near city entrance");app.world.paused=false;clear_encounters()
	var possessions: Dictionary={"gold":app.rules.state.gold,"items":app.rules.state.items.duplicate(true)}
	for target in ["b357","ga1","6"]:
		var route: Array=Planner.plan(app.resources.connections.by_map,app.world.metadata.id,target,app.world.player.cell,app.world.navigation)
		expect(not route.is_empty(),"route to "+target)
		for gate in route:
			expect(gate.kind=="reference","uses reference passage")
			var before_frames: int=frames
			expect(app.world.approach(Vector2i(gate.cell[0],gate.cell[1])),"approach doorway");walk()
			expect(frames>before_frames,"each doorway requires actual movement")
			expect(app.world.metadata.id==gate.target_map,"walking crosses doorway to "+gate.target_map)
			if app.world.metadata.id!=gate.target_map:break
		if target=="b357":expect(not EditionRules.Story.ready(app.rules.state,q),"barracks alone insufficient")
		if target=="ga1":
			expect(not EditionRules.Story.ready(app.rules.state,q),"palace arrival still requires witnesses")
			var guard: Dictionary=app.rules.story_npc("reconstructed:ga1:guard")
			expect(app.world.entities.any(func(e):return e.id==guard.id),"guard loaded in live scene")
			expect(Vector2i(guard.cell[0],guard.cell[1])==Vector2i(15,25) and int(guard.frames)==4,"reference position and four-frame idle")
			for frame in range(guard.frame,guard.frame+guard.frames):
				var bounds: Rect2=app.resources.frame_bounds("npc",frame)
				expect(bounds.size.x>1 and bounds.size.y>1,"idle contains no placeholder frame")
			expect(not app.world.navigation.walkable(Vector2i(15,25)),"guard tile blocks player")
			expect(app.world.approach(Vector2i(15,25)),"approach palace guard");walk()
			expect(app.near_reference_npc(guard) and app.world.player.cell!=Vector2i(15,25),"reach guard without occupying same cell")
			var before_talk: Dictionary=app.rules.state.duplicate(true)
			app.interact(guard);app.windows.close_all()
			expect(EditionRules.Story.progress(app.rules.state,q,2)==1,"guard testimony recorded")
			expect(app.rules.state.gold==before_talk.gold and app.rules.state.items==before_talk.items,"testimony costs nothing")
			expect(not EditionRules.Story.ready(app.rules.state,q),"guard testimony still requires elder report")
	expect(app.rules.state.gold==possessions.gold and app.rules.state.items==possessions.items,"survey passage consumes no credentials or gold")
	expect(app.world.metadata.id=="6","round trip returns to city")
	expect(app.world.approach(Vector2i(elder.cell[0],elder.cell[1])),"approach elder from return landing");walk()
	expect(app.near_reference_npc(elder),"continuous return walk reaches elder")
	app.interact(elder);app.windows.close_all()
	expect(EditionRules.Story.ready(app.rules.state,q),"both visits and report recorded")
	var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action(q.id,"submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before,"failed delivery retains progress and wealth")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action(q.id,"submit",elder.id,elder.map,app.world.player.cell),"deliver survey")
	expect(app.rules.state.gold==before.gold+240,"configured easy-world reward")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before,"duplicate reward refused")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.quests[q.id]=="done" and app.rules.state.gold==before.gold,"reload retains completed survey")
	var report:={"checks":checks,"failures":failures,"simulated_walk_seconds":frames/60.0,"scope":"reference city/barracks/palace round trip and walking to elder; prior quest and initial city doorway fixture; monsters removed and combat not advanced, no scheduled legion event or physical input verification"}
	FileAccess.open("res://../artifacts/world-story/demon-garrison-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
