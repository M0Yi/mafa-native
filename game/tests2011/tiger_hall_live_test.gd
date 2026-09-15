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
	app.store.path="/tmp/tiger-hall-live-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"tiger-live","name":"虎卫堂见闻","job":"战士","gender":"男"});app.world.hide()
	var npc: Dictionary=app.rules.story_npc("server:merchant:118")
	app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_moon="done"
	expect(app.rules.apply(prepared,"prior_story_fixture"),"prepare prior Bairimen introduction")
	expect(app.rules.story_action("story_tiger_hall","accept",npc.id,npc.map,app.world.player.cell),"accept beside actual elder")
	var routes: Array=[]
	for mid in ["11","1002"]:
		for route in app.resources.connections.by_map.get(mid,[]):
			if route.id in ["d36610e697311460","a3a8b2a244d8bf18"]:routes.append(route)
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
		if route.target_map=="1002":
			var teacher: Dictionary=app.rules.story_npc("server:merchant:111")
			expect(app.world.approach(Vector2i(teacher.cell[0],teacher.cell[1])),"approach Tianzun inside hall")
			walk();var skills: Dictionary=app.rules.state.skills.duplicate(true)
			app.interact(teacher);app.windows.close_all()
			expect(EditionRules.Story.progress(app.rules.state,EditionRules.Story.quest("story_tiger_hall"),1)==1,"actual interaction records warning")
			expect(app.rules.state.skills==skills,"visiting teacher does not teach a skill")
	expect(app.world.metadata.id==npc.map,"return to valley")
	expect(app.world.approach(Vector2i(npc.cell[0],npc.cell[1])),"plan return to elder")
	walk()
	expect(app.near_reference_npc(npc),"reach elder after round trip")
	var before_reward: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action("story_tiger_hall","submit",npc.id,npc.map,app.world.player.cell) and app.rules.state==before_reward,"failed delivery preserves completed journey and wealth")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action("story_tiger_hall","submit",npc.id,npc.map,app.world.player.cell),"deliver actual exploration")
	expect(app.store.load_world("tiger-live").quests.story_tiger_hall=="done","delivery persisted")
	expect(app.rules.state.gold==before_reward.gold+0,"delivery awards exact configured gold")
	var rewarded: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.story_action("story_tiger_hall","submit",npc.id,npc.map,app.world.player.cell) and app.rules.state==rewarded,"repeat delivery cannot duplicate rewards")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.quests["story_tiger_hall"]=="done" and app.rules.state.gold==rewarded.gold,"reloaded character retains delivered task and gold")
	var report:={"checks":checks,"failures":failures,"minimum_hp":minimum_hp,"potions_used":potions_used,"simulated_seconds":frames/60.0,"scope":"Bairimen guide to Tiger Hall, Tianzun dialogue and back with full main loop at 60 Hz; initial elder position and prior quest fixtures, initial character stats, default carried potions used through gameplay below 50 HP, no hardware input or performance measurement"}
	FileAccess.open("res://../artifacts/world-story/tiger-hall-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
