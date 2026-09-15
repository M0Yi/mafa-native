extends SceneTree
var app
var checks:=0
var failures: Array=[]
var frames:=0
var minimum_hp:=100
var potions_used:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func step() -> void:
	app._process(1.0/60);frames+=1;minimum_hp=mini(minimum_hp,int(app.rules.state.hp))
	if app.rules.state.hp>0 and app.rules.state.hp<50:
		if app.gameplay.use_type("potion"):potions_used+=1
func walk(stop_map: String="") -> void:
	for i in range(18000):
		step()
		if app.rules.state.hp<=0:break
		if not stop_map.is_empty() and app.world.metadata.id==stop_map:break
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/old-mine-live-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"mine-live","name":"旧矿归途","job":"战士","gender":"男"});app.world.hide()
	var npc: Dictionary=app.rules.story_npc("server:merchant:141")
	app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_seal="done"
	expect(app.rules.apply(prepared,"prior_story_fixture"),"prepare prior valley introduction")
	expect(app.rules.story_action("story_seal_mine","accept",npc.id,npc.map,app.world.player.cell),"accept beside actual elder")
	var routes: Array=[]
	for mid in ["4","d2000"]:
		for route in app.resources.connections.by_map.get(mid,[]):
			if route.source.get("rule","")=="sealed_old_mine_investigation_v1":routes.append(route)
	for route in routes:
		expect(app.world.metadata.id==route.map,"continue route without teleport fixture")
		var at:=Vector2i(route.cell[0],route.cell[1])
		if app.world.player.cell==at:
			for direction in ClassicNavigation.DIRECTIONS:
				if app.world.navigation.can_step(at,at+direction) and not app.resources.connections.current.has(at+direction):
					app.world.player.go_to(at+direction);walk();break
		expect(app.world.approach(at),"plan walk to branch threshold")
		walk(route.target_map)
		expect(app.world.metadata.id==route.target_map and app.rules.state.hp>0,"cross branch alive with live actors")
		if app.world.metadata.id!=route.target_map:break
	expect(app.world.metadata.id==npc.map,"return to valley")
	expect(app.world.approach(Vector2i(npc.cell[0],npc.cell[1])),"plan return to elder")
	walk()
	expect(app.near_reference_npc(npc),"reach elder after round trip")
	expect(app.rules.story_action("story_seal_mine","submit",npc.id,npc.map,app.world.player.cell),"deliver actual exploration")
	expect(app.store.load_world("mine-live").quests.story_seal_mine=="done","delivery persisted")
	expect(app.rules.story_action("story_seal_scorpion","accept",npc.id,npc.map,app.world.player.cell),"old mine delivery unlocks active-mine commission at elder")
	var planner=preload("res://scripts/edition2011/story_routes.gd")
	var active_route: Array=planner.plan(app.resources.connections.by_map,app.world.metadata.id,"d2001",app.world.player.cell,app.world.navigation)
	expect(active_route.size()==1 and active_route[0].target_map=="d2001" and active_route[0].kind=="reference","next commission uses active reference mine entrance, not old branch")
	expect(app.rules.track_story("story_seal_scorpion"),"track next mine commission")
	var intact: Dictionary=app.rules.state.duplicate(true)
	app.navigate_tracked_quest()
	expect(app.windows.windows.has("任务远行路线") and app.rules.state==intact,"tracking shows next mine route without granting visit or teleport")
	var report:={"checks":checks,"failures":failures,"minimum_hp":minimum_hp,"potions_used":potions_used,"simulated_seconds":frames/60.0,"scope":"elder to old mine and back with full main loop at 60 Hz; initial elder position and prior quest fixtures, initial character stats, default carried potions used through gameplay below 50 HP, no hardware input or performance measurement"}
	FileAccess.open("res://../artifacts/world-story/old-mine-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
