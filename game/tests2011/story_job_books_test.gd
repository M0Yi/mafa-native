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
	app.store.path="/tmp/job-books-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for id in ["story_mage_blizzard_book","story_tao_ghostshield_book"]:
		var q: Dictionary=Story.quest(id)
		for job in ["战士","法师","道士"]:
			app.start_character({"id":id+job,"name":"职业书页","gender":"男","job":job});app.world.hide()
			var next: Dictionary=app.rules.state.duplicate(true);next.level=60;next.gold=10000;next.hp=1000;next.mp=560
			for prior in q.requires:next.quests[prior]="done"
			expect(app.rules.apply(next,"level_prerequisite_fixture"),"fixture")
			var eligible: bool=job in q.jobs
			expect(Story.available(app.rules.state,q)==eligible,"eligibility matches actual job")
			var accepted: bool=app.rules.story_action(id,"accept",q.start_npc,"0",Vector2i(325,250))
			expect(accepted==eligible,"rule rejects other professions")
			if not eligible:
				expect("限定职业" in app.rules.message,"clear job rejection")
				var brief: String=Story.skill_brief(app.rules.state,q.objectives[0],job)
				expect("限定职业" in brief and "配置缺失" not in brief,"other job is a restriction, not a missing configuration")
				app.enter_map("0",Vector2i(325,251));app.world.paused=false
				app.controller_interact(app.rules.story_npc(q.start_npc));await settle()
				var view=app.form.get_child(1)
				for index in range(view.rows.size()):
					if view.rows[index].id==id:view.cursor=index;break
				view.open_detail()
				expect("限定职业" in view.text.text and "配置缺失" not in view.text.text,"controller detail identifies profession restriction")
				expect("不适用于当前职业" in view.hint.text and "A 接取" not in view.hint.text,"controller does not advertise unavailable acceptance")
				app.windows.close_all();continue
			expect(not Story.ready(app.rules.state,q),"unlearned prerequisite skill blocks reward")
			var skill: String=q.objectives[0].skills_by_job[job];var book:=""
			for item in EditionRules.ITEMS:
				if EditionRules.ITEMS[item].get("skill_book")==skill:book=item;break
			expect(app.rules.shop(book,1) and app.rules.use_item(book),"real book teaches prerequisite skill")
			expect(Story.ready(app.rules.state,q),"learned skill enables delivery")
			var before: Dictionary=app.rules.state.duplicate(true)
			app.store.db.query("PRAGMA query_only=ON;")
			expect(not app.rules.story_action(id,"submit",q.end_npc,"0",Vector2i(325,250)) and app.rules.state==before,"failed delivery preserves reward")
			app.store.db.query("PRAGMA query_only=OFF;")
			expect(app.rules.story_action(id,"submit",q.end_npc,"0",Vector2i(325,250)),"deliver book")
			var reward: String=q.rewards.books_by_job[job];var learned: String=EditionRules.ITEMS[reward].skill_book
			expect(app.rules.state.inventory.get(reward,0)==1 and not app.rules.state.skills.has(learned),"reward is book, no automatic learning")
			expect(app.rules.use_item(reward) and app.rules.state.skills.has(learned),"use rewarded book learns intended skill")
			before=app.rules.state.duplicate(true)
			expect(not app.rules.story_action(id,"submit",q.end_npc,"0",Vector2i(325,250)) and app.rules.state==before,"no repeat reward")
			var practice: Dictionary=Story.quest(id+"_practice")
			expect(app.rules.story_action(practice.id,"accept",q.start_npc,"0",Vector2i(325,250)),"accept skill practice")
			app.world.player.reset(Vector2i(300,618));app.world.paused=false
			var targets: Array=[]
			for x in [301,302,304]:targets.append({"id":"spell-target-"+str(x),"kind":"monster","name":"施法靶子","hp":10000,"max_hp":10000,"generation":0,"cell":[x,618],"profile":{"sounds":{},"actions":{}},"race":81})
			app.world.entities=targets;app.selected=targets[0]
			for attempt in range(5):
				app.elapsed+=70;app.fight_timer=0;app.pending_attack.clear()
				var mana: int=app.rules.state.mp
				expect(app.gameplay.cast(learned),"actual rewarded skill casts")
				expect(app.rules.state.mp==mana-int(EditionSkills.DEFINITIONS[learned].mp),"spell cost matches definition")
				expect(int(app.rules.state.skills[learned].proficiency)==attempt+1,"one proficiency per successful cast")
				expect(Story.ready(app.rules.state,practice)==(attempt==4),"practice needs five casts")
				if job=="法师":
					var health: Array=targets.map(func(e):return e.hp)
					app.elapsed+=0.3;app.resolve_attack()
					expect(targets[0].hp<health[0] and targets[1].hp<health[1] and targets[2].hp==health[2],"blizzard hits chosen cluster, excludes outside area")
					var after: Array=targets.map(func(e):return e.hp);app.resolve_attack()
					expect(targets.map(func(e):return e.hp)==after,"impact cannot repeat")
				else:
					expect(float(app.rules.state.ghostshield_until)==app.elapsed+60,"shield has bounded duration")
					var hp: int=app.rules.state.hp;var defense: int=app.rules.defense(app.elapsed)
					app.world.monster_hit.emit({"magic_attack":true},30)
					expect(app.rules.state.hp==hp-maxi(1,30-defense-8),"ghost shield reduces actual magic hit")
			expect(app.rules.story_action(practice.id,"submit",q.end_npc,"0",Vector2i(325,250)),"submit practiced branch")

			# A paid cast can be canceled by a real passage before impact; it is not refunded.
			app.elapsed+=70;app.fight_timer=0;app.pending_attack.clear()
			expect(app.gameplay.cast(learned),"cast before passage")
			var paid_mp: int=app.rules.state.mp;var paid_practice: int=app.rules.state.skills[learned].proficiency
			var health_before: Array=targets.map(func(e):return e.hp)
			expect(not app.gameplay.visuals.is_empty() and not app.gameplay.spell_events.is_empty(),"cast queues transient presentation")
			var gates: Array=app.resources.connections.by_map["0"].filter(func(g):return g.target_map=="0111" and g.kind=="reference")
			expect(not gates.is_empty(),"reference passage exists")
			if not gates.is_empty():
				var gate: Dictionary=gates[0];app.world.player.reset(Vector2i(gate.cell[0],gate.cell[1]))
				expect(app.cross_passage(gate),"actual passage saves destination")
				expect(app.pending_attack.is_empty() and app.gameplay.visuals.is_empty() and app.gameplay.spell_events.is_empty(),"passage clears old attack visuals and staged sound")
				app.elapsed+=1;app.resolve_attack()
				expect(targets.map(func(e):return e.hp)==health_before,"old targets are not hit after passage")
				expect(app.rules.state.mp==paid_mp and int(app.rules.state.skills[learned].proficiency)==paid_practice,"canceled impact neither refunds cost nor repeats practice")
				expect(app.store.load_world(app.rules.character.id).map=="0111","destination persists")

	app.elapsed+=70;app.fight_timer=0;app.world.paused=false
	expect(app.gameplay.cast("ghostshield") and not app.gameplay.visuals.is_empty(),"active visual before fatal hit")
	app.world.monster_hit.emit({"magic_attack":true},100000)
	expect(app.rules.state.hp==0 and is_instance_valid(app.gameplay.death_layer),"fatal event enters death wait")
	expect(app.gameplay.visuals.is_empty() and app.gameplay.spell_events.is_empty() and app.pending_attack.is_empty(),"death clears pending transient effects")
	expect(float(app.rules.state.death_due)==app.elapsed+30 and app.world.metadata.id=="0111","death cleanup preserves thirty-second wait in place")

	var report:={"checks":checks,"failures":failures,"scope":"all three professions, actual books and transactions; level/prerequisites/NPC location and nonlethal targets are fixtures; actual casts and damage resolve, not full travel or real monster combat"}
	FileAccess.open("res://../artifacts/world-story/job-books-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
