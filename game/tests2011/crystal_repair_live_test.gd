extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var failures: Array=[]
var checks:=0
var frames:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func walk(target: String="") -> void:
	for i in range(18000):
		app._process(1.0/60);frames+=1
		if app.rules.state.hp<=0:break
		if not target.is_empty() and app.world.metadata.id==target:break
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/crystal-repair-live-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"repair","name":"城内见闻","job":"战士","gender":"男"});app.world.hide()
	var elder: Dictionary=app.rules.story_npc("server:merchant:80")
	app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1]));app.world.paused=false
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_centipede_north="done";prepared.gold=500
	expect(app.rules.apply(prepared,"prior_north_survey_fixture"),"prepare completed northwest branch survey")
	expect(app.rules.shop("robe",1) and app.rules.use_item("robe"),"purchase and equip repairable armor")
	var worn: Dictionary=app.rules.state.duplicate(true)
	for item in worn.items:
		if item.type=="robe":item.durability=70
	expect(app.rules.apply(worn,"armor_wear_fixture"),"prepare damaged armor")
	expect(app.rules.story_action("story_centipede_crystal_repair","accept",elder.id,elder.map,app.world.player.cell),"accept underground repair task at elder")
	expect(app.enter_map("d605",Vector2i(43,20)),"fixture starts near underground passage");app.world.paused=false
	for mid in ["d608","d605"]:
		var route: Array=Planner.plan(app.resources.connections.by_map,app.world.metadata.id,mid,app.world.player.cell,app.world.navigation)
		expect(not route.is_empty(),"planned underground route to "+mid)
		for gate in route:
			expect(gate.kind=="reference","underground journey follows reference passage")
			expect(app.world.approach(Vector2i(gate.cell[0],gate.cell[1])),"approach doorway")
			walk(gate.target_map)
			expect(app.world.metadata.id==gate.target_map and app.rules.state.hp>0,"cross live doorway")
			if app.world.metadata.id!=gate.target_map:break
		if mid=="d608" and app.world.metadata.id==mid:
			var tailor: Dictionary=app.rules.story_npc("server:merchant:96")
			expect(app.world.approach(Vector2i(tailor.cell[0],tailor.cell[1])),"approach tailor")
			walk();app.interact(tailor);app.windows.close_all()
			expect(not EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_centipede_crystal_repair")),"visiting and talking do not count as repair")
			expect(app.rules.reference_repair(tailor.id),"actual tailor repair transaction")
			expect(EditionRules.Story.progress(app.rules.state,EditionRules.Story.quest("story_centipede_crystal_repair"),1)==1,"named tailor repair recorded")
	expect(app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1])),"fixture returns to elder after testing passage exit");app.world.paused=false
	var before_reward: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action("story_centipede_crystal_repair","submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before_reward,"failed delivery preserves completed journey and wealth")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action("story_centipede_crystal_repair","submit",elder.id,elder.map,app.world.player.cell),"deliver after passage visit and actual repair")
	expect(app.store.load_world("repair").quests.story_centipede_crystal_repair=="done","underground repair completion persisted")
	expect(app.rules.state.gold==before_reward.gold+160,"delivery awards exact configured gold")
	var rewarded: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.story_action("story_centipede_crystal_repair","submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==rewarded,"repeat delivery cannot duplicate rewards")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.quests["story_centipede_crystal_repair"]=="done" and app.rules.state.gold==rewarded.gold,"reloaded character retains delivered task and gold")
	var report:={"checks":checks,"failures":failures,"simulated_seconds":frames/60.0,"scope":"full main loop, d605 to d608 original passage round trip and actual repair/delivery; prior quest, damaged armor, starting passage and return to elder are fixtures; no natural full journey, hardware input or performance measurement"}
	FileAccess.open("res://../artifacts/world-story/crystal-repair-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
