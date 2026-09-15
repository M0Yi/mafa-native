extends SceneTree
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
	app.store.path="/tmp/fire-supplies-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"supplies","name":"道术备战","gender":"男","job":"道士"});app.world.hide();app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.level=60;next.mp=560;next.gold=10000
	expect(app.rules.apply(next,"level_budget_fixture"),"prepare book learning level")
	expect("尚未学会" in app.fire_dragon.supplies_text(),"briefing does not invent learned skills")
	app.world.metadata.id="d2083";app.world.navigation.configure({"size":[3,1],"walkable":[[1,1,1]]});app.world.player.reset(Vector2i.ZERO)
	app.world.entities=[{"id":"target","kind":"monster","name":"施法目标","cell":[1,0],"generation":0,"hp":1000,"max_hp":1000}]
	for id in ["talisman","poison"]:
		var book:=""
		for key in EditionRules.ITEMS:
			if EditionRules.ITEMS[key].get("skill_book","")==id:book=key;break
		expect(not book.is_empty() and app.rules.shop(book,1) and app.rules.use_item(book),"learn by actual book "+id)
		var material: String=EditionSkills.material_costs(id).keys()[0]
		var before: Dictionary=app.rules.state.duplicate(true)
		expect("背包 %d"%int(before.inventory[material]) in app.fire_dragon.supplies_text(),"briefing shows carried supply "+id)
		app.fight_timer=0;app.pending_attack.clear();app.elapsed+=10
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.gameplay.cast(id) and app.rules.state==before,"failed cast preserves mana and material")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.gameplay.cast(id),"learned skill casts")
		expect(int(app.rules.state.inventory[material])==int(before.inventory[material])-1,"exact one material consumed")
		expect(int(app.rules.state.mp)==int(before.mp)-int(EditionSkills.DEFINITIONS[id].mp),"actual mana matches definition")
		expect("背包 %d"%int(app.rules.state.inventory[material]) in app.fire_dragon.supplies_text(),"briefing reflects consumption")
		while app.rules.state.inventory.get(material,0)>0:app.rules.warehouse(material,true)
		before=app.rules.state.duplicate(true);app.fight_timer=0;app.pending_attack.clear();app.elapsed+=10
		expect(not app.gameplay.cast(id) and app.rules.state==before,"warehouse stock cannot fuel spell")
		expect("背包 0" in app.fire_dragon.supplies_text(),"warehouse stock excluded from briefing")
	expect(app.rules.reference_trade("server:merchant:75","ref:44",true,app.elapsed),"actual Mengzhong merchant sells powder")
	var packed: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.use_item("ref:44") and app.rules.state==packed,"unpack write failure preserves packet")
	app.store.db.query("PRAGMA query_only=OFF;")
	var heavy: Dictionary=packed.duplicate(true)
	app.rules.count_item(heavy,"potion",400-app.rules.weight(heavy))
	expect(app.rules.apply(heavy,"full_weight_fixture"),"fill allowed carrying capacity")
	heavy=app.rules.state.duplicate(true)
	expect(not app.rules.use_item("ref:44") and app.rules.state==heavy,"unpack overweight preserves all goods")
	var light: Dictionary=app.rules.state.duplicate(true)
	app.rules.count_item(light,"potion",int(packed.inventory.get("potion",0))-int(light.inventory.get("potion",0)))
	expect(app.rules.apply(light,"restore_carry_fixture"),"restore initial packet")
	expect(app.rules.use_item("ref:44"),"NPC powder packet unpacks")
	expect(not app.rules.state.inventory.has("ref:44") and app.rules.state.inventory.get("poison",0)==50,"one small packet becomes fifty single-player doses")
	expect("50" in EditionRules.material_bundle_text("ref:44") and "单机适配" in EditionRules.material_bundle_text("ref:44"),"UI identifies quantity and adaptation")
	app.fight_timer=0;app.pending_attack.clear();app.elapsed+=10
	expect(app.gameplay.cast("poison") and app.rules.state.inventory.get("poison",0)==49,"NPC purchased powder now fuels real skill")
	var before: Dictionary=app.rules.state.duplicate(true);app.fire_dragon.supplies_text()
	expect(app.rules.state==before,"reading is read only")
	var report:={"checks":checks,"failures":failures,"scope":"actual book learning, spell resource transaction, failure rollback and warehouse separation; level and target geometry fixtures, no full battle or panel screenshot"}
	FileAccess.open("res://../artifacts/world-story/fire-supplies-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
