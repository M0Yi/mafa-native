extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(3):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/mentor-story-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for suffix in ["warrior","mage","tao"]:
		var q: Dictionary=Story.quest("story_mentor_visit_"+suffix)
		app.start_character({"id":suffix,"name":"职业前辈","gender":"男","job":q.jobs[0]});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true)
		for prior in q.requires:next.quests[prior]="done"
		expect(app.rules.apply(next,"mentor_prerequisite_fixture"),"prerequisite fixture")
		expect(app.rules.story_action(q.id,"accept",q.start_npc,"0",Vector2i(325,250)),"accept profession visit")
		var npc: Dictionary=app.rules.story_npc(q.objectives[1].npc)
		expect(app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN) and app.save_world(),"load and save actual mentor map")
		app.world.paused=false
		expect(Story.progress(app.rules.state,q,0)==1 and not Story.ready(app.rules.state,q),"arrival does not replace conversation")
		var live: Dictionary={}
		for e in app.world.entities:
			if e.id==npc.id:live=e;break
		expect(not live.is_empty(),"reference NPC is live")
		var skills: Dictionary=app.rules.state.skills.duplicate(true)
		if not live.is_empty():app.interact(live)
		expect(Story.ready(app.rules.state,q),"actual NPC interaction records authored talk")
		expect(app.rules.state.skills==skills,"conversation does not grant skills")
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.story_action(q.id,"submit",q.end_npc,"0",Vector2i(325,250)) and app.rules.state==before,"failed return reward remains retryable")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.story_action(q.id,"submit",q.end_npc,"0",Vector2i(325,250)),"submit return fixture")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",q.end_npc,"0",Vector2i(325,250)) and app.rules.state==before,"no repeated reward")
		expect(q.objectives[1].dialogue in Story.recap(app.rules.state,q),"authored advice retained in recap")
		app.windows.close_all()
	var report:={"checks":checks,"failures":failures,"scope":"three professions, real map/NPC interaction and reward transactions; prerequisites, starting location and return delivery location are fixtures; route test separately exercises walking"}
	FileAccess.open("res://../artifacts/world-story/mentor-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
