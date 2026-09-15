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
	app.store.path="/tmp/mongchon-storage-live-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"storage","name":"城内见闻","job":"战士","gender":"男"});app.world.hide()
	var elder: Dictionary=app.rules.story_npc("server:merchant:80")
	app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1]));app.world.paused=false
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_mongchon_medicine_purchase="done";prepared.gold=500
	expect(app.rules.apply(prepared,"prior_mongchon_fixture"),"prepare delivered letter")
	expect(app.rules.story_action("story_mongchon_storage","accept",elder.id,elder.map,app.world.player.cell),"accept town errand at elder")
	for mid in ["0145","3"]:
		var route: Array=Planner.plan(app.resources.connections.by_map,app.world.metadata.id,mid,app.world.player.cell,app.world.navigation)
		expect(not route.is_empty(),"planned town route to "+mid)
		for gate in route:
			expect(gate.kind=="reference","town errand follows original doorway")
			expect(app.world.approach(Vector2i(gate.cell[0],gate.cell[1])),"approach doorway")
			walk(gate.target_map)
			expect(app.world.metadata.id==gate.target_map and app.rules.state.hp>0,"cross live doorway")
			if app.world.metadata.id!=gate.target_map:break
		if mid=="0145" and app.world.metadata.id==mid:
			var keeper: Dictionary=app.rules.story_npc("server:merchant:65")
			var q: Dictionary=EditionRules.Story.quest("story_mongchon_storage")
			expect(app.world.approach(Vector2i(keeper.cell[0],keeper.cell[1])),"approach warehouse keeper")
			walk();app.interact(keeper);app.windows.close_all()
			expect(not EditionRules.Story.ready(app.rules.state,q),"entry and conversation do not count as storage")
			var original_items: Dictionary=app.rules.state.inventory.duplicate(true)
			for deposit in [true,false]:
				var before: Dictionary=app.rules.state.duplicate(true)
				app.store.db.query("PRAGMA query_only=ON;")
				expect(not app.rules.warehouse("potion",deposit) and app.rules.state==before,"failed storage transaction preserves items and progress")
				app.store.db.query("PRAGMA query_only=OFF;")
				expect(app.rules.warehouse("potion",deposit),"actual store or retrieve")
				expect(EditionRules.Story.ready(app.rules.state,q)==not deposit,"both storage stages required")
			expect(app.rules.state.inventory==original_items,"round trip returns same medicine quantity")
	expect(app.world.approach(Vector2i(elder.cell[0],elder.cell[1])),"walk back to elder");walk()
	var before_reward: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action("story_mongchon_storage","submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before_reward,"failed delivery preserves completed journey and wealth")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action("story_mongchon_storage","submit",elder.id,elder.map,app.world.player.cell),"deliver after all rooms and conversation")
	expect(app.store.load_world("storage").quests.story_mongchon_storage=="done","storage completion persisted")
	expect(app.rules.state.gold==before_reward.gold+60,"delivery awards exact configured gold")
	expect(app.rules.state.inventory==before_reward.inventory,"delivery preserves retrieved medicines")
	var rewarded: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.story_action("story_mongchon_storage","submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==rewarded,"repeat delivery cannot duplicate rewards")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.quests["story_mongchon_storage"]=="done" and app.rules.state.gold==rewarded.gold and app.rules.state.skills==rewarded.skills,"reloaded character retains delivered task and gold")
	var report:={"checks":checks,"failures":failures,"simulated_seconds":frames/60.0,"scope":"full main loop, original doors, town rooms and actual conversation/delivery; initial elder position/prior Mongchon and budget fixtures, no hardware input or performance measurement"}
	FileAccess.open("res://../artifacts/world-story/mongchon-storage-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
