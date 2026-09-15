extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func button_named(text: String) -> Button:
	for node in app.find_children("*","Button",true,false):
		if node.text==text and node.is_visible_in_tree():return node
	return null
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/cook-entry-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for job in ["战士","法师","道士"]:
		app.start_character({"id":job,"name":"厨师考验","job":job,"gender":"男"});app.world.hide()
		var npc: Dictionary=app.rules.story_npc(app.cook_trials.NPC)
		app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
		expect(app.world.approach(Vector2i(npc.cell[0],npc.cell[1])),"approach forest elder")
		for step in range(30000):
			if app.world.player.route.is_empty() and app.world.player.progress>=1:break
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
		expect(app.near_reference_npc(npc),"reach elder before entry tests: "+str(app.world.player.cell))
		var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_feast_cook_trail="done";expect(app.rules.apply(next,"prior_cook_fixture"),"prepare prerequisite")
		app.show_reference_npc(npc)
		expect(button_named("厨师考验 · 职业挑战")!=null,"elder exposes trial panel")
		app.cook_trials.panel()
		expect(button_named("接受考验 · 60 秒")!=null,"eligible panel exposes entry")
		var before: Dictionary=app.rules.state.duplicate(true)
		app.world.paused=true;expect(not app.cook_trials.enter() and app.rules.state==before,"paused entry refused");app.world.paused=false
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.cook_trials.enter() and app.rules.state==before and app.world.metadata.id=="1","failed entry restores forest")
		app.store.db.query("PRAGMA query_only=OFF;")
		var entered: bool=app.cook_trials.enter()
		expect(entered,"enter correct profession room: "+app.pending_message)
		if not entered:app.queue_free();await settle();quit(1);return
		var session: Dictionary=app.rules.state.cook_trial.duplicate(true)
		expect(app.world.metadata.id==session.map and app.rules.state.map==session.map,"scene and saved map agree")
		var monsters: Array=app.world.entities.filter(func(e):return e.has("cook_attempt"))
		expect(monsters.size()==1 and monsters[0].reference_name==app.cook_trials.Session.MONSTERS[job],"exactly one profession monster")
		app.cook_trials.ensure_monster();expect(app.world.entities.filter(func(e):return e.has("cook_attempt")).size()==1,"spawn update does not duplicate enemy")
		var injured: int=maxi(1,int(monsters[0].max_hp)/2);monsters[0].hp=injured
		app.world.actors.brains[monsters[0].id].cooldown=1.75
		app.elapsed=float(session.started)+10
		monsters[0].trap_status=preload("res://scripts/edition2011/trap_status.gd").create(monsters[0],100,3,app.elapsed)
		expect(app.save_world(),"save wounded trial at ten seconds")
		app.start_character(app.rules.character.duplicate(true));app.world.hide();app.cook_trials.ensure_monster()
		var restored: Array=app.world.entities.filter(func(e):return e.has("cook_attempt"))
		expect(restored.size()==1 and restored[0].has("trap_status") and restored[0].trap_status.expires==float(session.started)+26,"challenge restores original trap deadline")
		expect(restored.size()==1 and restored[0].hp==injured,"reload restores wounded enemy without duplicate")
		expect(app.elapsed==float(session.started)+10 and app.rules.state.cook_trial.deadline==session.deadline,"reload preserves remaining time without offline advance")
		expect(app.world.actors.brains[restored[0].id].cooldown==1.75,"reload preserves attack cooldown")
		restored[0].hp=maxi(1,injured-1)
		app.elapsed=session.deadline;app.world.paused=true
		expect(not app.cook_trials.expire() and app.rules.state.cook_trial.active,"pause prevents recall")
		app.world.paused=false;before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.cook_trials.expire() and app.rules.state==before and app.world.metadata.id==session.map,"failed recall restores trial scene and timer")
		var after_failure: Array=app.world.entities.filter(func(e):return e.has("cook_attempt"))
		expect(after_failure.size()==1 and after_failure[0].hp==maxi(1,injured-1),"failed recall preserves latest unsaved injury")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.cook_trials.expire(),"deadline recalls player")
		expect(app.world.metadata.id=="1" and not app.rules.state.cook_trial.active and app.near_reference_npc(npc),"returns near original elder")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(not app.rules.state.cook_trial.active and app.rules.state.map=="1","ended visit survives reload")
		app.world.paused=false
		app.cook_trials.panel()
		expect(button_named("放弃本次战果并重试")!=null and button_named("接受考验 · 60 秒")==null,"unfinished attempt requires reset")
		before=app.rules.state.duplicate(true)
		app.cook_trials.request_reset()
		expect(app.windows.modal.visible and app.rules.state==before,"reset opens confirmation without mutation")
		app.windows.modal.hide()
		expect(app.rules.state==before,"cancel preserves attempt")
		expect(app.cook_trials.reset(),"panel reset operation succeeds")
		expect(button_named("接受考验 · 60 秒")!=null,"reset exposes fresh entry")
	var report:={"checks":checks,"failures":failures,"scope":"three profession entry/spawn and deadline recall, pause rejection and SQLite failures; prerequisite and deadline advanced as fixtures, panel controls and reset confirmation constructed; no actual combat or physical input"}
	FileAccess.open("res://../artifacts/world-story/cook-trial-entry-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
