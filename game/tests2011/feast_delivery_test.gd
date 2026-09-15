extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func talk(id: String) -> void:
	var npc: Dictionary=app.rules.story_npc(id)
	app.rules.story_talk(id,npc.map,Vector2i(npc.cell[0],npc.cell[1]))
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/feast-delivery-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var q: Dictionary=EditionRules.Story.quest("story_feast_delivery")
	var giver: Dictionary=app.rules.story_npc(q.start_npc);var end: Dictionary=app.rules.story_npc(q.end_npc)
	for job in ["战士","法师","道士"]:
		app.start_character({"id":job,"name":"宴席送达","job":job,"gender":"男"});app.world.hide();app.world.paused=false
		expect(not app.rules.story_action(q.id,"accept",giver.id,giver.map,Vector2i(giver.cell[0],giver.cell[1])),"oil ingredients required")
		var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_feast_oil_materials="done";expect(app.rules.apply(next,"prior_smith_fixture"),"prepare prerequisite")
		expect(app.rules.story_action(q.id,"accept",giver.id,giver.map,Vector2i(giver.cell[0],giver.cell[1])),"accept cook trail")
		talk(q.objectives[1].npc)
		expect(EditionRules.Story.progress(app.rules.state,q,1)==0,"reverse inquiries do not pre-complete trail")
		for index in range(2):
			talk(q.objectives[index].npc)
			expect(EditionRules.Story.progress(app.rules.state,q,index)==1,"ordered inquiry counted")
			if index<1:expect(not EditionRules.Story.ready(app.rules.state,q),"later witness remains required")
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.story_action(q.id,"submit",end.id,end.map,Vector2i(end.cell[0],end.cell[1])) and app.rules.state==before,"failed submission rolls back")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.story_action(q.id,"submit",end.id,end.map,Vector2i(end.cell[0],end.cell[1])),"submit trail")
		expect(app.rules.state.items==before.items and app.rules.state.gold==before.gold,"trail issues no trial token or money")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",end.id,end.map,Vector2i(end.cell[0],end.cell[1])) and app.rules.state==before,"repeat reward refused")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(app.rules.state.quests[q.id]=="done","trail completion reloads")
	var report:={"checks":checks,"failures":failures,"scope":"three professions, ordered NPC talks, prerequisites and transactional submission; prerequisite and all interaction positions fixtures, no natural travel; verifies oil prerequisite and smith-before-butcher delivery order"}
	FileAccess.open("res://../artifacts/world-story/feast-feast-delivery-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
