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
	app.store.path="/tmp/zuma-tailor-live-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"repair","name":"城内见闻","job":"战士","gender":"男"});app.world.hide()
	var elder: Dictionary=app.rules.story_npc("server:merchant:80")
	app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1]));app.world.paused=false
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_zuma="done";prepared.gold=500
	expect(app.rules.apply(prepared,"prior_zuma_fixture"),"prepare completed Zuma introduction")
	expect(app.rules.story_action("story_zuma_tailor","accept",elder.id,elder.map,app.world.player.cell),"accept tailor inquiry at elder")
	var person: Dictionary=app.rules.story_npc("server:merchant:97")
	var components: Array=Planner.npc_components(app.resources,person)
	var planned: Array=Planner.plan(app.resources.connections.by_map,app.world.metadata.id,person.map,app.world.player.cell,app.world.navigation,components)
	expect(not planned.is_empty() and planned.back().target_component in components,"NPC route from elder targets reachable service component")
	expect(EditionRules.Story.next_objective(app.rules.state,EditionRules.Story.quest("story_zuma_tailor")).type=="talk","first navigation uses NPC component rather than generic map")
	expect(app.enter_map("d513",Vector2i(23,17)),"fixture starts near underground passage");app.world.paused=false
	for mid in ["d514","d513"]:
		var route: Array=Planner.plan(app.resources.connections.by_map,app.world.metadata.id,mid,app.world.player.cell,app.world.navigation)
		expect(not route.is_empty(),"planned underground route to "+mid)
		for gate in route:
			expect(gate.kind=="reconstructed_passage","journey explicitly uses reconstructed passage")
			expect(app.world.approach(Vector2i(gate.cell[0],gate.cell[1])),"approach doorway")
			walk(gate.target_map)
			expect(app.world.metadata.id==gate.target_map and app.rules.state.hp>0,"cross live doorway")
			if app.world.metadata.id!=gate.target_map:break
		if mid=="d514" and app.world.metadata.id==mid:
			var tailor: Dictionary=app.rules.story_npc("server:merchant:97")
			expect(app.world.approach(Vector2i(tailor.cell[0],tailor.cell[1])),"approach tailor")
			walk()
			expect(not EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_zuma_tailor")),"visit alone does not complete inquiry")
			var possessions: Dictionary={"gold":app.rules.state.gold,"items":app.rules.state.items.duplicate(true)}
			app.interact(tailor);app.windows.close_all()
			expect(app.rules.state.gold==possessions.gold and app.rules.state.items==possessions.items,"talk does not charge or repair items")
			expect(EditionRules.Story.progress(app.rules.state,EditionRules.Story.quest("story_zuma_tailor"),0)==1,"named tailor conversation recorded")
	expect(app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1])),"fixture returns to elder after testing passage exit");app.world.paused=false
	var before_reward: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action("story_zuma_tailor","submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before_reward,"failed delivery preserves completed journey and wealth")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action("story_zuma_tailor","submit",elder.id,elder.map,app.world.player.cell),"deliver after passage visit and conversation")
	expect(app.store.load_world("repair").quests.story_zuma_tailor=="done","tailor inquiry completion persisted")
	expect(app.rules.state.gold==before_reward.gold+120,"delivery awards exact configured gold")
	var rewarded: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.story_action("story_zuma_tailor","submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==rewarded,"repeat delivery cannot duplicate rewards")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.quests["story_zuma_tailor"]=="done" and app.rules.state.gold==rewarded.gold,"reloaded character retains delivered task and gold")
	var report:={"checks":checks,"failures":failures,"simulated_seconds":frames/60.0,"scope":"full main loop, d513 to d514 reconstructed passage round trip and actual NPC conversation/delivery; prior quest, initial door position and return to elder fixtures; no natural full journey or hardware input"}
	FileAccess.open("res://../artifacts/world-story/zuma-tailor-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
