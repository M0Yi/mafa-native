extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func walk() -> void:
	for i in range(60*180):
		app._process(1.0/60)
		if app.rules.state.hp<=0 or (app.world.player.route.is_empty() and app.world.player.progress>=1):break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/valley-rumor-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"rumor","name":"核对传闻","job":"战士","gender":"男"});app.world.hide()
	var q: Dictionary=EditionRules.Story.quest("story_valley_rumor_inquiry");var giver: Dictionary=app.rules.story_npc(q.start_npc)
	app.enter_map(giver.map,Vector2i(giver.cell[0]+1,giver.cell[1]));app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_bichon_training_rumor="done"
	expect(app.rules.apply(next,"rumor_fixture"),"prepare rumor heard")
	expect(not app.rules.story_action(q.id,"accept",giver.id,giver.map,app.world.player.cell),"valley prerequisite required too")
	next=app.rules.state.duplicate(true);next.quests.story_valley="done";expect(app.rules.apply(next,"valley_fixture"),"prepare valley arrival")
	expect(app.rules.story_action(q.id,"accept",giver.id,giver.map,app.world.player.cell),"accept investigation")
	for objective in q.objectives:
		app.approach_story_npc(objective.npc);walk()
		var person: Dictionary=app.rules.story_npc(objective.npc)
		expect(app.rules.story_near(person.id,app.world.metadata.id,app.world.player.cell),"walk to witness")
		app.interact(person);app.windows.close_all()
		expect(EditionRules.Story.progress(app.rules.state,q,q.objectives.find(objective))==1,"conversation recorded")
	app.approach_story_npc(giver.id);walk()
	var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action(q.id,"submit",giver.id,giver.map,app.world.player.cell) and app.rules.state==before,"failed delivery retains findings")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action(q.id,"submit",giver.id,giver.map,app.world.player.cell),"deliver investigation")
	expect(app.rules.state.gold==before.gold+80,"exact reward")
	expect(app.store.load_world("rumor").quests.get(q.id)=="done","investigation saved")
	var report:={"checks":checks,"failures":failures,"scope":"main-loop walking and NPC interactions, multi-prerequisite and transaction checks; initial valley location and prerequisites prepared, no full cross-map journey or hardware input"}
	FileAccess.open("res://../artifacts/world-story/valley-rumor-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
