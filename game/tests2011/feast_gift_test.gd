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
	var Gift=preload("res://scripts/edition2011/feast_gift.gd")
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/feast-gift-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var npc: Dictionary=app.rules.story_npc(Gift.NPC);var at:=Vector2i(npc.cell[0],npc.cell[1])
	var paths: Array=[["calm"],["angry"],["generous","indifferent"],["generous","happy"],["generous","unhappy","funny"],["generous","unhappy","dislike"]]
	for index in range(paths.size()):
		app.start_character({"id":str(index),"name":"谢礼分支","job":"战士","gender":"男"});app.world.hide()
		expect(not Gift.choose(app.rules,paths[index][0],npc.map,at),"delivery prerequisite required")
		var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_feast_delivery="done";next.quests.story_feast_old_liu="accepted"
		expect(app.rules.apply(next,"delivery_fixture"),"prepare delivery")
		for answer in paths[index]:
			var before: Dictionary=app.rules.state.duplicate(true)
			expect(not Gift.choose(app.rules,"invalid",npc.map,at) and app.rules.state==before,"invalid answer changes nothing")
			app.store.db.query("PRAGMA query_only=ON;")
			expect(not Gift.choose(app.rules,answer,npc.map,at) and app.rules.state==before,"failed answer rolls back reward and progress")
			app.store.db.query("PRAGMA query_only=OFF;")
			expect(Gift.choose(app.rules,answer,npc.map,at),"answer commits")
			var saved: Dictionary=app.rules.state.feast_gift.duplicate(true)
			app.start_character(app.rules.character.duplicate(true));app.world.hide()
			expect(app.rules.state.feast_gift==JSON.parse_string(JSON.stringify(saved)),"question and random decision survive reload")
		var q: Dictionary=EditionRules.Story.quest("story_feast_old_liu")
		var elder: Dictionary=app.rules.story_npc(q.end_npc);var at_liu:=Vector2i(elder.cell[0],elder.cell[1])
		expect(EditionRules.Story.progress(app.rules.state,q,0)==1,"all reward outcomes satisfy gift objective")
		app.rules.story_talk(elder.id,elder.map,at_liu)
		expect(app.rules.story_action(q.id,"submit",elder.id,elder.map,at_liu),"hear Liu story and register completion")
		var gift: Dictionary=app.rules.state.feast_gift
		expect(gift.stage=="done" and gift.answers==paths[index],"complete exact path")
		var expected: Dictionary={}
		if paths[index][-1] in ["calm","happy","funny"]:expected={"ref:159":1}
		if paths[index][-1]=="dislike":
			expected={"ref:193":1}
			if gift.bonus:expected["ref:159"]=1
		expect(gift.rewards==JSON.parse_string(JSON.stringify(expected)),"source branch reward matches")
		var before: Dictionary=app.rules.state.duplicate(true)
		expect(not Gift.choose(app.rules,paths[index][-1],npc.map,at) and app.rules.state==before,"cannot claim twice")
	for bonus in [false,true]:
		app.start_character({"id":"capacity-"+str(bonus),"name":"谢礼容量","job":"道士","gender":"女"});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.level=100;next.quests.story_feast_delivery="done"
		next.inventory={"wood_sword":48};next.items=[]
		next.feast_gift={"stage":"friend","answers":["generous","unhappy"],"bonus":bonus,"rewards":{}}
		expect(app.rules.apply(next,"full_bag_and_bonus_fixture"),"prepare full bag and both random outcomes")
		var before: Dictionary=app.rules.state.duplicate(true)
		expect(not Gift.choose(app.rules,"dislike",npc.map,at) and app.rules.state==before,"full bag preserves last question and bonus")
		next=app.rules.state.duplicate(true);app.rules.count_item(next,"wood_sword",-2)
		expect(app.rules.apply(next,"free_slots_fixture"),"make two spaces")
		expect(Gift.choose(app.rules,"dislike",npc.map,at),"same answer retries after capacity restored")
		expect(int(app.rules.state.inventory.get("ref:193",0))==1 and int(app.rules.state.inventory.get("ref:159",0))==int(bonus),"exact items granted for each random outcome")
		before=app.rules.state.duplicate(true)
		next=before.duplicate(true);next.feast_gift.answers=["invalid"]
		expect(not app.rules.apply(next,"corrupt_path_fixture") and app.rules.state==before,"invalid saved path rejected without replacing progress")
		next=before.duplicate(true);next.feast_gift.rewards["ref:193"]=2
		expect(not app.rules.apply(next,"corrupt_reward_fixture") and app.rules.state==before,"mismatched saved reward rejected")
	var report:={"checks":checks,"failures":failures,"scope":"six dialogue paths, SQLite failure rollback and reload, expected rewards; prerequisite and positions fixtures, full bag retry and both random outcomes fixtures, corrupt path/reward rejection; no physical UI or random-distribution test"}
	FileAccess.open("res://../artifacts/world-story/feast-gift-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
