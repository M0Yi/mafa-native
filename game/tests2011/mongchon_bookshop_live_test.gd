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
	app.store.path="/tmp/mongchon-bookshop-live-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"bookshop","name":"城内见闻","job":"战士","gender":"男"});app.world.hide()
	var elder: Dictionary=app.rules.story_npc("server:merchant:80")
	app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1]));app.world.paused=false
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_mongchon="done";prepared.gold=500
	expect(app.rules.apply(prepared,"prior_mongchon_fixture"),"prepare delivered letter")
	expect(app.rules.story_action("story_mongchon_bookshop","accept",elder.id,elder.map,app.world.player.cell),"accept town errand at elder")
	for mid in ["0161","3"]:
		var route: Array=Planner.plan(app.resources.connections.by_map,app.world.metadata.id,mid,app.world.player.cell,app.world.navigation)
		expect(not route.is_empty(),"planned town route to "+mid)
		for gate in route:
			expect(gate.kind=="reference","town errand follows original doorway")
			expect(app.world.approach(Vector2i(gate.cell[0],gate.cell[1])),"approach doorway")
			walk(gate.target_map)
			expect(app.world.metadata.id==gate.target_map and app.rules.state.hp>0,"cross live doorway")
			if app.world.metadata.id!=gate.target_map:break
		if mid=="0161" and app.world.metadata.id==mid:
			var merchant: Dictionary=app.rules.story_npc("server:merchant:78")
			var before_talk: Dictionary=app.rules.state.duplicate(true)
			expect(not EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_mongchon_bookshop")),"entry alone does not replace bookshop conversation")
			expect(app.world.approach(Vector2i(merchant.cell[0],merchant.cell[1])),"approach bookseller")
			walk();app.interact(merchant);app.windows.close_all()
			expect(EditionRules.Story.progress(app.rules.state,EditionRules.Story.quest("story_mongchon_bookshop"),1)==1,"bookseller conversation recorded")
			expect(app.rules.state.skills==before_talk.skills and app.rules.state.gold==before_talk.gold and app.rules.state.inventory==before_talk.inventory,"inquiry neither teaches skills nor buys or consumes books")
	expect(app.world.approach(Vector2i(elder.cell[0],elder.cell[1])),"walk back to elder");walk()
	var before_reward: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action("story_mongchon_bookshop","submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before_reward,"failed delivery preserves completed journey and wealth")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action("story_mongchon_bookshop","submit",elder.id,elder.map,app.world.player.cell),"deliver after all rooms and conversation")
	expect(app.store.load_world("bookshop").quests.story_mongchon_bookshop=="done","bookshop completion persisted")
	expect(app.rules.state.gold==before_reward.gold+40,"delivery awards exact configured gold")
	expect(app.rules.state.inventory==before_reward.inventory,"delivery does not grant or consume books")
	var rewarded: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.story_action("story_mongchon_bookshop","submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==rewarded,"repeat delivery cannot duplicate rewards")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.quests["story_mongchon_bookshop"]=="done" and app.rules.state.gold==rewarded.gold and app.rules.state.skills==rewarded.skills,"reloaded character retains delivered task and gold")
	var report:={"checks":checks,"failures":failures,"simulated_seconds":frames/60.0,"scope":"full main loop, original doors, town rooms and actual conversation/delivery; initial elder position/prior Mongchon and budget fixtures, no hardware input or performance measurement"}
	FileAccess.open("res://../artifacts/world-story/mongchon-bookshop-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
