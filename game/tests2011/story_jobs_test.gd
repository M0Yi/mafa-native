extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-jobs-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for job in ["战士","法师","道士"]:
		app.start_character({"id":"jobs-"+job,"name":"修习验收","gender":"男","job":job});app.world.paused=false
		for entry in Story.data().quests:
			if not entry.rewards.has("books_by_job"):continue
			var id: String=entry.id
			var q: Dictionary=Story.quest(id);var npc: Dictionary=app.rules.story_npc(q.start_npc);var cell:=Vector2i(npc.cell[0],npc.cell[1])
			var next: Dictionary=app.rules.state.duplicate(true)
			for previous in q.requires:next.quests[previous]="done"
			expect(app.rules.apply(next,"prerequisite_fixture"),"seed prerequisites "+job+id)
			expect(app.rules.story_action(id,"accept",npc.id,npc.map,cell),"accept "+job+id)
			for o in q.objectives:
				if o.type=="talk":
					var person: Dictionary=app.rules.story_npc(o.npc);app.rules.story_talk(person.id,person.map,Vector2i(person.cell[0],person.cell[1]))
			for objective in q.objectives:
				if objective.type=="skill" and objective.has("skills_by_job"):
					var target: String=objective.skills_by_job[job]
					expect(EditionSkills.DEFINITIONS[target].name in Story.skill_brief(app.rules.state,objective) and "已学会" in Story.skill_brief(app.rules.state,objective),"learned objective names actual profession skill")
					var unlearned: Dictionary=app.rules.state.duplicate(true);unlearned.skills.erase(target)
					var brief:=Story.skill_brief(unlearned,objective)
					expect(str(EditionSkills.DEFINITIONS[target].level)+" 级学习" in brief and "背包使用" in brief and "仅持有" in brief,"unlearned objective explains exact level and book use")
			expect(Story.ready(app.rules.state,q),"previous skill actually learned "+job+id)
			var book: String=q.rewards.books_by_job[job];var skill: String=EditionRules.ITEMS[book].skill_book
			var before: Dictionary=app.rules.state.duplicate(true)
			app.store.db.query("PRAGMA query_only=ON;")
			expect(not app.rules.story_action(id,"submit",npc.id,npc.map,cell) and app.rules.state==before,"failed reward write preserves state")
			app.store.db.query("PRAGMA query_only=OFF;")
			var room: Dictionary=app.rules.state.duplicate(true)
			next=app.rules.state.duplicate(true);next.items=[]
			for slot in range(48):next.items.append(EditionInventory.make_item("potion",1,"inventory",slot))
			EditionInventory.mirror(next);expect(app.rules.apply(next,"full_bag_fixture"),"fill inventory slots")
			var full: Dictionary=app.rules.state.duplicate(true)
			expect(not app.rules.story_action(id,"submit",npc.id,npc.map,cell) and app.rules.state==full,"full bag preserves pending reward and wealth")
			room.revision=app.rules.state.revision;expect(app.rules.apply(room,"restore_inventory_fixture"),"free room before retry")
			expect(app.rules.story_action(id,"submit",npc.id,npc.map,cell),"submit "+job+id)
			expect(app.rules.state.inventory.get(book)==1 and not app.rules.state.skills.has(skill),"quest gives book only")
			expect(EditionSkills.DEFINITIONS[skill].job==job,"reward matches profession")
			expect(not app.rules.story_action(id,"submit",npc.id,npc.map,cell) and app.rules.state.inventory[book]==1,"book reward cannot repeat")
			next=app.rules.state.duplicate(true);next.level=1;app.rules.apply(next,"low_level_fixture")
			expect(not app.rules.use_item(book) and app.rules.state.inventory[book]==1,"learning level still required")
			next=app.rules.state.duplicate(true);next.level=int(EditionSkills.DEFINITIONS[skill].level);app.rules.apply(next,"learning_level_fixture")
			expect(app.rules.use_item(book),"learn awarded book")
			expect(app.rules.state.skills.has(skill) and not app.rules.state.inventory.has(book),"book consumed exactly once")
			var saved: Dictionary=app.store.load_world(app.rules.character.id)
			expect(saved.skills.has(skill) and saved.quests[id]=="done","learning and reward persist")
			var altered: Dictionary=q.duplicate(true);altered.rewards.books_by_job[job]="potion"
			expect(app.rules.story_reward_items(altered).is_empty(),"invalid book configuration rejected")
		var mastery: Dictionary=Story.quest("story_mastery_return")
		var teacher: Dictionary=app.rules.story_npc(mastery.start_npc)
		var at:=Vector2i(teacher.cell[0],teacher.cell[1])
		var mastery_skill: String=mastery.objectives[0].skills_by_job[job]
		var mastery_book: String=Story.quest("story_veteran_book").rewards.books_by_job[job]
		var setup_state: Dictionary=app.rules.state.duplicate(true)
		for prerequisite in mastery.requires:setup_state.quests[prerequisite]="done"
		setup_state.skills.erase(mastery_skill);setup_state.gold=100000
		expect(app.rules.apply(setup_state,"mastery_prerequisite_fixture"),"prepare expedition return without learned skill")
		expect(app.rules.story_action(mastery.id,"accept",teacher.id,teacher.map,at),"accept final mastery "+job)
		expect(app.rules.shop(mastery_book,1),"obtain mastery book fixture")
		expect(not Story.ready(app.rules.state,mastery),"carried mastery book does not satisfy task")
		var before: Dictionary=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(mastery.id,"submit",teacher.id,teacher.map,at) and app.rules.state==before,"unlearned mastery cannot submit")
		expect(app.rules.use_item(mastery_book) and Story.ready(app.rules.state,mastery),"actual book use satisfies profession mastery")
		app.store.db.query("PRAGMA query_only=ON;");before=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(mastery.id,"submit",teacher.id,teacher.map,at) and app.rules.state==before,"mastery reward failure rolls back")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.story_action(mastery.id,"submit",teacher.id,teacher.map,at),"mastery delivery retries")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(mastery.id,"submit",teacher.id,teacher.map,at) and app.rules.state==before,"mastery reward cannot duplicate")
		expect(app.store.load_world(app.rules.character.id).quests.get(mastery.id)=="done","mastery completion saved")
	var report:={"checks":checks,"failures":failures,"jobs":3,"quest_stages":Story.data().quests.filter(func(q):return q.rewards.has("books_by_job")).size(),"scope":"rule and persistence integration; earlier regional prerequisites are fixtures"}
	FileAccess.open("res://../artifacts/world-story/jobs-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
