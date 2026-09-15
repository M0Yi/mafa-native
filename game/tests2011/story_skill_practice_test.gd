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
	app.store.path="/tmp/skill-practice-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var q: Dictionary=Story.quest("story_formation_practice")
	for job in ["战士","法师","道士"]:
		app.start_character({"id":"practice-"+job,"name":"招式练习","gender":"男","job":job});app.world.hide();app.world.paused=false
		var next: Dictionary=app.rules.state.duplicate(true);next.level=60;next.mp=560;next.gold=10000;next.quests.story_formation_book="done"
		expect(app.rules.apply(next,"practice_prerequisite_fixture"),"prepare level and prerequisite")
		var npc: Dictionary=app.rules.story_npc(q.start_npc);var skill: String=q.objectives[0].skills_by_job[job]
		var book:=""
		for id in EditionRules.ITEMS:
			if EditionRules.ITEMS[id].get("skill_book","")==skill:book=id;break
		expect(app.rules.shop(book,1) and app.rules.use_item(book),"actual book learns profession skill")
		expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])),"accept practice")
		expect(not Story.ready(app.rules.state,q),"learning alone does not finish practice")
		expect(app.rules.track_story(q.id),"track practice")
		var tour: Dictionary=Story.quest("story_training_room")
		expect(app.rules.story_action(tour.id,"accept",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])),"accept training room tour")
		var entrances: Array=app.resources.connections.by_map["0"].filter(func(g):return g.target_map=="0111" and g.kind=="reference")
		expect(not entrances.is_empty(),"reference training room entrance exists")
		if entrances.is_empty():continue
		var entrance: Dictionary=entrances[0]
		app.enter_map("0",Vector2i(entrance.cell[0],entrance.cell[1]));app.world.paused=false
		expect(app.cross_passage(entrance),"enter training room through actual reference gate")
		expect(Story.ready(app.rules.state,tour),"actual entry credits room discovery")
		expect(app.world.entities.any(func(e):return e.get("reference_name","")=="练功师"),"real reference trainers loaded")
		expect(int(app.rules.state.skills[skill].proficiency)==0,"room discovery does not award practice")

		app.pending_attack.clear();app.fight_timer=0;app.elapsed+=10
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.gameplay.cast(skill) and app.rules.state==before,"failed cast cannot advance practice")
		app.store.db.query("PRAGMA query_only=OFF;")
		for i in range(5):
			app.pending_attack.clear();app.fight_timer=0;app.elapsed+=10
			expect(app.gameplay.cast(skill),"successful real cast "+job)
			expect(int(app.rules.state.skills[skill].proficiency)==i+1,"exact practice count")
			expect(Story.ready(app.rules.state,q)==(i==4),"only fifth cast readies task")
			expect(("%d/5"%(i+1)) in Story.objective_text(app.rules.state,q,0),"details show each committed practice")
			if i<4:expect(("%d/5"%(i+1)) in Story.tracker_text(app.rules.state),"tracker shows partial practice")
			expect(app.chat_history.any(func(line):return q.title in line and ("%d/5"%(i+1)) in line),"chat shows each practice step")

		expect("5 / 5" in Story.skill_brief(app.rules.state,q.objectives[0],job),"both UI consumers can show proficiency")
		expect(app.chat_history.any(func(line):return q.title in line and "5/5" in line),"threshold completion announced in task chat")
		var prior: Dictionary=app.rules.state.duplicate(true);prior.quests.erase(q.id)
		expect(Story.progress(prior,q,0)==1,"earlier legitimate practice remains eligible")
		var exits: Array=app.resources.connections.by_map["0111"].filter(func(g):return g.target_map=="0" and g.kind=="reference")
		expect(not exits.is_empty() and app.world.player.go_to(Vector2i(exits[0].cell[0],exits[0].cell[1])),"room exit is reachable")
		for frame in range(600):
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
			var gate: Dictionary=app.resources.connections.poll(app.world.player)
			if not gate.is_empty():app.cross_passage(gate);break
		expect(app.world.metadata.id=="0","walk out through reference return")
		var end: Dictionary=app.rules.story_npc(q.end_npc)
		expect(app.rules.story_action(tour.id,"submit",end.id,end.map,Vector2i(end.cell[0],end.cell[1])),"discovery tour delivers independently")
		expect(app.rules.story_action(q.id,"submit",end.id,end.map,Vector2i(end.cell[0],end.cell[1])),"practice delivers")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",end.id,end.map,Vector2i(end.cell[0],end.cell[1])) and app.rules.state==before,"practice reward cannot duplicate")
	var report:={"checks":checks,"failures":failures,"scope":"three professions learn actual books and cast five times with real costs, write failure and task reward; prerequisite/level and initial gate position fixtures, actual research-room trainers and return walking, casts not full combat"}
	FileAccess.open("res://../artifacts/world-story/skill-practice-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
