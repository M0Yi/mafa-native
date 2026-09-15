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
func run() -> void:
	var Books=preload("res://scripts/edition2011/mystery_books.gd")
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/mystery-craft-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for job in Books.WEAPONS:
		app.start_character({"id":job,"name":"神秘打造","job":job,"gender":"男"});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.level=100;next.quests.story_feast_old_liu="done";next.quests.story_mine_practice="done";next.map="q016";next.cell=[14,22];next.items=[];next.inventory={"ref:226":1,"wood_sword":46}
		expect(app.rules.apply(next,"materials_fixture"),"prepare gold bar")
		next=app.rules.state.duplicate(true)
		var ore:=EditionInventory.make_item("ref:132",int(Books.WEAPONS[job].count),"inventory",EditionInventory.free_slot(next.items,"inventory"));ore.purity=18;next.items.append(ore);EditionInventory.mirror(next)
		expect(app.rules.apply(next,"graded_fixture"),"prepare graded ore")
		expect(app.enter_map("q016",Vector2i(14,22),false),"enter merchant room")
		app.world.paused=false
		var quest_id: String={"战士":"story_mystery_forge_warrior","法师":"story_mystery_forge_mage","道士":"story_mystery_forge_taoist"}[job]
		var quest: Dictionary=EditionRules.Story.quest(quest_id)
		expect(app.rules.story_action(quest_id,"accept",Books.NPC,"q016",app.world.player.cell),"accept profession crafting quest")
		var unearned: Dictionary=app.rules.state.duplicate(true)
		expect(not EditionRules.Story.observe(unearned,"purchase",{"npc":Books.NPC,"item":Books.WEAPONS[job].product}) and not EditionRules.Story.ready(unearned,quest),"purchase cannot substitute crafting")
		var summary: String=app.rules.story_materials_text(quest)
		expect(summary.contains("背包合格金矿 %d/%d"%[Books.WEAPONS[job].count,Books.WEAPONS[job].count]) and summary.contains("金条：背包1"),"task preparation shows current profession materials")
		var before: Dictionary=app.rules.state.duplicate(true)
		expect(before.items.size()==48,"full bag fixture")
		var crowded: Dictionary=before.duplicate(true)
		for item in crowded.items:
			if item.type in ["ref:132","ref:226"]:item.count+=1
		EditionInventory.mirror(crowded)
		expect(app.rules.apply(crowded,"no_free_slot_fixture"),"prepare materials that leave both stacks occupied")
		var intact: Dictionary=app.rules.state.duplicate(true)
		expect(not Books.craft(app,int(intact.revision)) and app.rules.state==intact and app.world.metadata.id=="q016","no freed slot rejects craft atomically")
		var restored: Dictionary=app.rules.state.duplicate(true)
		for item in restored.items:
			if item.type in ["ref:132","ref:226"]:item.count-=1
		EditionInventory.mirror(restored)
		expect(app.rules.apply(restored,"restore_exact_materials"),"restore exact materials")
		before=app.rules.state.duplicate(true)
		expect(not Books.craft(app,int(before.revision)-1) and app.rules.state==before,"stale confirmation rejected")
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not Books.craft(app,int(before.revision)) and app.rules.state==before and app.world.metadata.id=="q016","write failure preserves materials and scene")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(Books.craft(app,int(before.revision)),"actual crafting retry "+job)
		expect(app.rules.state.map=="d002" and app.world.metadata.id=="d002","craft returns to source destination")
		expect(int(app.rules.state.inventory.get(Books.WEAPONS[job].product,0))==1 and not app.rules.state.inventory.has("ref:226") and not app.rules.state.inventory.has("ref:132"),"exact recipe consumed and weapon granted")
		var landing: Vector2i=app.world.player.cell
		var elder: Dictionary=app.rules.story_npc("server:merchant:53")
		expect(app.world.approach(Vector2i(elder.cell[0],elder.cell[1])),"return landing has route to Liu")
		for step in range(12000):
			if app.world.player.route.is_empty() and app.world.player.progress>=1:break
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
		expect(app.world.player.cell!=landing and app.near_reference_npc(elder),"actual movement reaches Liu after craft")
		expect(app.world.player.cell!=Vector2i(elder.cell[0],elder.cell[1]),"NPC cell remains blocked")
		expect(EditionRules.Story.ready(app.rules.state,quest),"actual craft completes profession objective")
		expect(app.rules.story_materials_text(quest).is_empty(),"completed craft no longer asks for consumed materials")
		expect(app.rules.story_action(quest_id,"submit",elder.id,"d002",app.world.player.cell),"walk to Liu and submit craft report")
		var claimed: Dictionary=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(quest_id,"submit",elder.id,"d002",app.world.player.cell) and app.rules.state==claimed,"craft quest cannot pay twice")
		before=app.rules.state.duplicate(true)
		expect(not Books.craft(app,int(before.revision)) and app.rules.state==before,"cannot repeat from destination")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(app.rules.state.map=="d002" and int(app.rules.state.inventory.get(Books.WEAPONS[job].product,0))==1,"craft and destination persist")
	var report:={"checks":checks,"failures":failures,"scope":"three job crafting transactions, readonly rollback, repeat rejection, reload; prepared materials/location, no mining or physical input"}
	FileAccess.open("res://../artifacts/world-story/mystery-craft-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
