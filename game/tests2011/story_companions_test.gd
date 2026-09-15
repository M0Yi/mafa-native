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
	for i in range(4):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-companions-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for suffix in ["qinghe","yuanshan","qingzhou"]:
		app.start_character({"id":suffix,"name":"同行见闻","gender":"男","job":"战士"});app.world.paused=false
		var q: Dictionary=Story.quest("story_companion_"+suffix);var member: String=q.objectives[0].name;var mid: String=q.objectives[1].map
		var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_traveler_friend="done";app.rules.apply(next,"prerequisite_fixture")
		var elder: Dictionary=app.rules.story_npc(q.start_npc)
		expect(app.rules.story_action(q.id,"accept",elder.id,elder.map,Vector2i(elder.cell[0],elder.cell[1])),"accept "+suffix)
		var witness: Dictionary=app.rules.story_npc(q.end_npc)
		expect(Story.objective_text(app.rules.state,q,2).contains("先完成前面的目标"),"blocked report explains required order")
		expect(Story.npc_task_priority(app.rules.state,q,witness.id)!=1,"blocked report does not advertise actionable testimony")
		app.rules.story_talk(witness.id,witness.map,Vector2i(witness.cell[0],witness.cell[1]))
		expect(Story.progress(app.rules.state,q,2)==0,"conversation before journey does not count "+suffix)
		app.rules.social("party","云游客");app.enter_map(mid)
		expect(Story.progress(app.rules.state,q,1)==0,"wrong companion cannot satisfy arrival "+suffix)
		app.rules.social("party",member)
		expect(Story.progress(app.rules.state,q,1)==0,"late invitation does not backfill "+suffix)
		app.rules.story_talk(witness.id,witness.map,Vector2i(witness.cell[0],witness.cell[1]))
		expect(Story.progress(app.rules.state,q,2)==0,"invitation without grouped arrival does not unlock report "+suffix)
		app.enter_map("0")
		var traveler: Dictionary=app.world.entities.filter(func(e):return e.kind=="traveler" and e.name==member)[0]
		app.gameplay.hit_traveler(traveler,{"damage":1000});app.enter_map(mid)
		expect(Story.progress(app.rules.state,q,1)==0,"dead companion does not satisfy arrival")
		app.elapsed+=30;app.gameplay.sync_travelers()
		expect(Story.progress(app.rules.state,q,1)==0,"recovery in destination does not backfill visit")
		app.enter_map("0");app.enter_map(mid)
		expect(Story.progress(app.rules.state,q,1)==1,"actual grouped map entry recorded "+suffix)
		expect(not Story.objective_text(app.rules.state,q,2).contains("先完成前面的目标"),"report hint updates after arrival")
		expect(Story.npc_task_priority(app.rules.state,q,witness.id)==1,"report becomes actionable after arrival")
		expect(app.world.entities.any(func(e):return e.kind=="traveler" and e.name==member),"named companion actually present on map")
		var npc: Dictionary=app.rules.story_npc(q.end_npc);var at:=Vector2i(npc.cell[0],npc.cell[1])
		app.rules.story_talk(npc.id,npc.map,at)
		expect(Story.ready(app.rules.state,q),"authored conversation completes objectives")
		app.rules.social("party",member);expect(not Story.ready(app.rules.state,q),"leaving before submission blocks reward")
		app.rules.social("party",member)
		expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,at),"submit named companion journey")
		var before: Dictionary=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"no repeat reward")
		expect(app.store.load_world(app.rules.character.id).quests[q.id]=="done","journey persisted")
	var report:={"checks":checks,"failures":failures,"scope":"three actual map entries and named companion entities, wrong member/late invite/leave/rejoin/reward rules; prerequisite and NPC interaction positions fixtures, continuous walking untested"}
	FileAccess.open("res://../artifacts/world-story/companions-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
