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
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/oil-materials-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var q: Dictionary=EditionRules.Story.quest("story_feast_oil_materials")
	var npc: Dictionary=app.rules.story_npc(q.end_npc);var at:=Vector2i(npc.cell[0],npc.cell[1])
	for job in ["战士","法师","道士"]:
		app.start_character({"id":job,"name":"特殊油材料","job":job,"gender":"男"});app.world.hide()
		expect(not app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"recipe inquiry prerequisite required")
		var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_feast_oil_trail="done"
		expect(app.rules.apply(next,"oil_prior_fixture"),"prepare inquiry completion")
		expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"accept material commission")
		next=app.rules.state.duplicate(true);app.rules.count_item(next,"ref:219",1)
		expect(app.rules.apply(next,"antler_fixture"),"prepare one material")
		var before: Dictionary=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"missing blood does not consume antler")
		next=app.rules.state.duplicate(true);app.rules.count_item(next,"ref:228",1)
		expect(app.rules.apply(next,"blood_fixture"),"prepare rare blood; not drop verification")
		before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"failed write preserves both materials")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,at),"retry commits material delivery")
		expect(int(app.rules.state.inventory.get("ref:219",0))==0 and int(app.rules.state.inventory.get("ref:228",0))==0,"both ingredients consumed")
		expect(app.rules.state.gold==before.gold and app.rules.state.xp==before.xp,"no invented currency or xp reward")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"duplicate submission refused")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(app.rules.state.quests.get(q.id)=="done" and int(app.rules.state.inventory.get("ref:228",0))==0,"delivery survives reload")
	var report:={"checks":checks,"failures":failures,"scope":"three professions actual SQLite ingredient delivery, missing ingredient and readonly failure; prerequisite, materials and positions are fixtures, no drop probability or natural travel verification"}
	FileAccess.open("res://../artifacts/world-story/feast-oil-materials-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
