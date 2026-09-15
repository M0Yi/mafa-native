extends "res://tests2011/mining_journey_test.gd"
func meet(id: String) -> bool:
	var npc: Dictionary=app.rules.story_npc(id)
	if app.world.metadata.id!=npc.map and not travel(npc.map):return false
	if not app.world.approach(Vector2i(npc.cell[0],npc.cell[1])):return false
	walk();return app.near_reference_npc(npc)
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/valley-inn-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var q: Dictionary=EditionRules.Story.quest("story_valley_inn")
	for job in ["战士","法师","道士"]:
		app.start_character({"id":"inn-"+job,"name":"客栈行路","job":job,"gender":"男"});app.world.hide()
		expect(app.enter_map("2",Vector2i(-1,-1),false),job+" initial valley fixture")
		app.world.paused=false;clear_encounters()
		var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_valley="done"
		expect(app.rules.apply(next,"inn_prerequisite_fixture"),job+" prerequisite")
		expect(meet(q.start_npc),job+" reach quest giver")
		expect(app.rules.story_action(q.id,"accept",q.start_npc,"2",app.world.player.cell),job+" accept")
		expect(meet("server:merchant:59"),job+" reach medicine shop before inn")
		app.rules.story_talk("server:merchant:59","2",app.world.player.cell)
		expect(EditionRules.Story.progress(app.rules.state,q,1)==0,job+" early talk does not count")
		expect(travel("0116"),job+" actual inn doorway entry")
		expect(EditionRules.Story.progress(app.rules.state,q,0)==1,job+" doorway records visit")
		expect(meet("server:merchant:59"),job+" leave inn and return to pharmacy")
		expect(app.rules.story_talk("server:merchant:59","2",app.world.player.cell),job+" supply dialogue")
		expect(EditionRules.Story.ready(app.rules.state,q),job+" ready")
		expect(meet(q.end_npc),job+" return to giver")
		expect(app.rules.story_action(q.id,"submit",q.end_npc,"2",app.world.player.cell),job+" submit")
		expect(not app.rules.story_action(q.id,"submit",q.end_npc,"2",app.world.player.cell),job+" no duplicate reward")
		expect(app.save_world(),job+" save")
		app.start_character(app.rules.character.duplicate(true));app.world.paused=false;clear_encounters()
		expect(app.rules.state.quests.get(q.id)=="done",job+" completion survives reload")
	var report={"checks":checks,"failures":failures,"gates":gates,"movement_frames":frames,"scope":"three professions actual path/door polling; prerequisite and initial valley fixtures, monsters removed, signal/rules calls not physical input"}
	FileAccess.open("res://../artifacts/world-story/valley-inn-journey-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
