extends SceneTree
var app
var checks:=0
var failures: Array=[]
var seeds: Dictionary={}
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func chosen_seed(drops: Array,target: String) -> int:
	for candidate in range(50000):
		seed(candidate)
		for drop in drops:
			var denominator:=int(str(drop.prob).get_slice("/",1))
			if denominator<=0:continue
			var hit:=randi_range(1,denominator)==1
			if drop.name==target and hit:return candidate
	return -1
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/peach-material-loot-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var definition: Dictionary=EditionRegion.data().monsters["多钩猫"]
	for index in range(285,291):
		var type:="ref:"+str(index);app.start_character({"id":type,"name":"材料拾取","job":"战士","gender":"男"});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.preset="classic";next.level=100
		expect(app.rules.apply(next,"level_and_drop_preset_fixture"),"prepare classic drop trial")
		var sample:=chosen_seed(definition.drops,EditionRules.ITEMS[type].name);seeds[type]=sample;expect(sample>=0,"original drop table has reachable RNG outcome")
		var monster:={"id":"loot-"+type,"spawn_id":"loot-fixture","respawn_seconds":60,"exp":int(definition.raw.exp),"name":"多钩猫","map":"0","cell":[287,618],"drops":definition.drops}
		var before: Dictionary=app.rules.state.duplicate(true);seed(sample)
		expect(app.rules.reward_kill("material-"+type,"",monster,1),"full original drop table settles")
		var rows: Array=app.rules.state.ground_loot.filter(func(l):return l.type==type)
		expect(not rows.is_empty() and not app.rules.state.inventory.has(type),"shrine material lands on ground, not bag")
		if rows.is_empty():continue
		var loot: Dictionary=rows[0];before=app.rules.state.duplicate(true)
		expect(not app.rules.reward_kill("material-"+type,"",monster,1) and app.rules.state==before,"same monster life cannot duplicate material")
		expect(not app.rules.pickup(loot.uid,"0",Vector2i(300,630)) and app.rules.state==before,"remote pickup refused")
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.pickup(loot.uid,"0",Vector2i(287,618)) and app.rules.state==before,"pickup failure retains ground material")
		app.store.db.query("PRAGMA query_only=OFF;")
		next=app.rules.state.duplicate(true)
		while EditionInventory.free_slot(next.items,"inventory")<48:
			next.items.append(EditionInventory.make_item("wood_sword",1,"inventory",EditionInventory.free_slot(next.items,"inventory")))
		EditionInventory.mirror(next);expect(app.rules.apply(next,"full_bag_fixture"),"prepare full bag")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.pickup(loot.uid,"0",Vector2i(287,618)) and app.rules.state==before,"full bag leaves material on ground")
		next=app.rules.state.duplicate(true);next.items.pop_back();EditionInventory.mirror(next);app.rules.apply(next,"free_slot_fixture")
		expect(app.rules.pickup(loot.uid,"0",Vector2i(287,618)),"pickup succeeds after freeing one slot")
		before=app.rules.state.duplicate(true)
		var item: Dictionary=app.rules.state.items.filter(func(i):return i.type==type)[0]
		expect(not app.rules.inventory_action("use",{"uid":item.uid}) and app.rules.state==before and "饮用效果尚未接入" in app.rules.message,"inventory use preserves crafting-only material with explicit reason")
		expect(not app.rules.pickup(loot.uid,"0",Vector2i(287,618)) and app.rules.state==before,"same drop cannot be picked twice")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(int(app.rules.state.inventory.get(type,0))==1 and not app.rules.state.ground_loot.any(func(l):return l.uid==loot.uid),"reload keeps material in bag and removes picked ground entry")
	var report:={"checks":checks,"failures":failures,"seeds":seeds,"scope":"six materials through original full monster drop table with selected RNG seeds and kill fixtures; pickup failure/full bag/reload; not natural combat or drop-rate/time measurement"}
	FileAccess.open("res://../artifacts/world-story/peach-material-loot-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
