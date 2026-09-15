extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/unlock-notice-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for job in ["战士","法师","道士"]:
		app.start_character({"id":"unlock-"+job,"name":"后续委托","job":job,"gender":"男"});app.world.hide()
		var q: Dictionary=EditionRules.Story.quest("story_mastery_return")
		var npc: Dictionary=app.rules.story_npc(q.end_npc)
		app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
		var prepared: Dictionary=app.rules.state.duplicate(true)
		for id in q.requires:prepared.quests[id]="done"
		prepared.quests[q.id]="accepted";prepared.skills[q.objectives[0].skills_by_job[job]]={"rank":1,"proficiency":int(q.objectives[0].get("min_proficiency",0))}
		expect(app.rules.apply(prepared,"prior_skill_fixture"),"prepare ready profession commission")
		expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,app.world.player.cell),"deliver profession commission")
		var notification: String=app.rules.message.get_slice("新委托：",1)
		var mage: String=EditionRules.Story.quest("story_mage_blizzard_book").title
		var warrior: String=EditionRules.Story.quest("story_mentor_visit_warrior").title
		expect((mage in notification)==(job=="法师"),"mage branch notification restricted to mage")
		expect((warrior in notification)==(job=="战士"),"warrior branch notification restricted to warrior")
	for mode in ["missing","ready","accepted","done"]:
		app.start_character({"id":"multi-"+mode,"name":"封魔报告","job":"战士","gender":"男"});app.world.hide()
		var q: Dictionary=EditionRules.Story.quest("story_hongmo")
		var npc: Dictionary=app.rules.story_npc(q.end_npc)
		app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
		var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_seal_mine="done";prepared.quests[q.id]="accepted"
		if mode!="missing":prepared.quests.story_seal_deep="done"
		if mode in ["accepted","done"]:prepared.quests.story_seal_report=mode
		EditionRules.Story.observe(prepared,"kill",{"map":"d2013","name":"虹魔教主"})
		expect(app.rules.apply(prepared,"kill_and_prerequisites_fixture"),"prepare boss record and prerequisite variant")
		expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,app.world.player.cell),"deliver boss commission")
		expect(app.rules.state.quests.get("story_seal_report","")==prepared.quests.get("story_seal_report",""),"notification does not accept or change follow-up quest")
		var notification: String=app.rules.message.get_slice("新委托：",1)
		expect((EditionRules.Story.quest("story_seal_report").title in notification)==(mode=="ready"),"multi-prerequisite notice only when newly available and unaccepted")
	var report:={"checks":checks,"failures":failures,"scope":"actual submission with prepared skills/kill/prerequisite fixtures; profession and multiple prerequisites, no travel or combat"}
	FileAccess.open("res://../artifacts/world-story/unlock-notice-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
