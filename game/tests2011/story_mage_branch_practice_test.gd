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
func click(button: Button) -> void:
	var node: Node=button.get_parent()
	while node!=null:
		if node is ScrollContainer:node.ensure_control_visible(button)
		node=node.get_parent()
	await settle()
	var e:=InputEventMouseButton.new();e.position=button.get_global_rect().get_center();e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/mage-practice-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for skill in ["hellfire","explosion","helllightning","manafire"]:
		var q: Dictionary=Story.quest("story_mage_"+skill+"_practice")
		for job in ["战士","道士","法师"]:
			app.start_character({"id":skill+job,"name":"法术修习","gender":"男","job":job});app.world.hide()
			var next: Dictionary=app.rules.state.duplicate(true);next.level=60;next.hp=1000;next.mp=560
			for prior in q.requires:next.quests[prior]="done"
			expect(app.rules.apply(next,"prerequisite_fixture"),"save prerequisite fixture")
			var npc: Dictionary=app.rules.story_npc(q.start_npc);var at:=Vector2i(npc.cell[0],npc.cell[1])
			var accepted: bool=app.rules.story_action(q.id,"accept",npc.id,npc.map,at)
			expect(accepted==(job=="法师"),"practice respects job restriction")
			if job!="法师":continue
			expect(not Story.ready(app.rules.state,q) and not app.rules.state.skills.has(skill),"acceptance never teaches skill")
			var book:=""
			for item in EditionRules.ITEMS:
				if EditionRules.ITEMS[item].get("skill_book")==skill:book=item;break
			expect(not book.is_empty(),"actual mapped book exists")
			var monster:={"id":"book-fixture","spawn_id":"book-fixture","respawn_seconds":60,"exp":1,"drops":[{"name":EditionRules.ITEMS[book].name,"prob":"1/1","count":1}],"name":"书页测试怪","map":"0","cell":[300,618]}
			expect(app.rules.reward_kill("book-fixture:"+skill,"",monster,10),"controlled drop through kill transaction")
			expect(not app.rules.state.skills.has(skill) and not app.rules.state.inventory.has(book),"drop stays on ground and unlearned")
			var drops: Array=app.rules.state.ground_loot.filter(func(row):return row.type==book)
			expect(not drops.is_empty(),"book ground instance exists")
			if drops.is_empty():continue
			expect(app.rules.pickup(drops[0].uid,"0",Vector2i(300,618)) and app.rules.use_item(book),"pickup and read actual book")
			app.enter_map("0",Vector2i(300,618));app.world.paused=false
			app.show_story();await settle()
			var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
			var open: Button=null
			for child in view.details.get_children():
				if child is Button and child.text=="打开技能："+str(EditionSkills.DEFINITIONS[skill].name):open=child;break
			expect(open!=null,"task offers specific skill page")
			if open!=null:await click(open)
			expect(app.windows.order.back()=="冒险面板","mouse opens skill journal")
			var journal=app.windows.windows["冒险面板"].body.get_child(1)
			expect(journal.current==3 and journal.content[3].selected==skill,"target skill selected without searching list")
			var select: Button=null
			for child in journal.content[3].details.get_children():
				if child is Button and child.text=="设为当前技能":select=child;break
			expect(select!=null,"learned active skill can be selected")
			if select!=null:await click(select)
			expect(app.gameplay.current_skill()==skill,"manual mouse selection configures current skill")
			app.windows.close_all()
			var target:={"id":"spell-target","kind":"monster","name":"施法靶子","hp":10000,"max_hp":10000,"generation":0,"cell":[301,618],"profile":{"sounds":{},"actions":{}},"race":81}
			app.world.entities=[target];app.selected=target
			for attempt in range(5):
				app.elapsed+=10;app.fight_timer=0;app.pending_attack.clear()
				var mana: int=app.rules.state.mp
				expect(app.gameplay.cast(skill),"actual practice cast "+skill)
				expect(app.rules.state.mp==mana-int(EditionSkills.DEFINITIONS[skill].mp),"one cast mana cost")
				expect(int(app.rules.state.skills[skill].proficiency)==attempt+1,"one practice increment")
				expect(Story.ready(app.rules.state,q)==(attempt==4),"five successful casts required")
				app.elapsed+=1;app.resolve_attack()
			expect(target.hp<10000,"actual impact damages eligible nearby target")
			var before: Dictionary=app.rules.state.duplicate(true)
			app.store.db.query("PRAGMA query_only=ON;")
			expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"failed reward write preserves practice")
			app.store.db.query("PRAGMA query_only=OFF;")
			expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,at),"submit completed practice")
			expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at),"reward cannot repeat")
			expect(app.store.load_world(app.rules.character.id).quests[q.id]=="done","completion survives reload")
	var report:={"checks":checks,"failures":failures,"scope":"four mage practice quests, viewport mouse task-to-skill opening and current skill selection, real book pickup/use and casts; deterministic book drop, prerequisite, level, targets and delivery location fixtures; not natural loot or complete travel"}
	FileAccess.open("res://../artifacts/world-story/mage-branch-practice-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
