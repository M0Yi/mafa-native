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
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/ore-ground-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"ore","name":"矿石流转","job":"战士","gender":"男"});app.world.hide()
	var next: Dictionary=app.rules.state.duplicate(true);next.items=[];next.inventory={};next.equipment={};next.warehouse={}
	var ore:=EditionInventory.make_item("ref:132",2,"inventory",0);ore.purity=18;next.items=[ore];EditionInventory.mirror(next)
	expect(app.rules.apply(next,"graded_ore_fixture"),"prepare graded ore")
	expect(app.rules.inventory_action("drop",{"uid":ore.uid}),"drop ore onto ground")
	var loot: Dictionary=app.rules.state.ground_loot.back()
	expect(loot.purity==18 and loot.count==2 and app.rules.state.inventory.is_empty(),"drop preserves grade and quantity")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.ground_loot.back().purity==18,"ground purity survives reload")
	var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.pickup(loot.uid,loot.map,Vector2i(loot.cell[0],loot.cell[1])) and app.rules.state==before,"failed pickup leaves ground unchanged")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.pickup(loot.uid,loot.map,Vector2i(loot.cell[0],loot.cell[1])),"pickup retry")
	var recovered: Array=app.rules.state.items.filter(func(i):return i.type=="ref:132")
	expect(recovered.size()==1 and recovered[0].purity==18 and recovered[0].count==2,"pickup preserves purity")
	expect(not app.rules.pickup(loot.uid,loot.map,Vector2i(loot.cell[0],loot.cell[1])),"same ground UID cannot duplicate ore")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.warehouse("ref:132",true) and app.rules.state==before,"failed deposit preserves graded instances")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.warehouse("ref:132",true),"legacy warehouse button deposits one graded ore")
	var stored: Array=app.rules.state.items.filter(func(i):return i.type=="ref:132" and i.container=="warehouse")
	expect(stored.size()==1 and stored[0].purity==18 and stored[0].count==1,"warehouse retains grade and single count")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.warehouse("ref:132",false),"withdraw after reload")
	recovered=app.rules.state.items.filter(func(i):return i.type=="ref:132" and i.container=="inventory")
	expect(recovered.size()==1 and recovered[0].purity==18 and recovered[0].count==2,"withdraw merges only same grade")
	for matching in [false,true]:
		next=app.rules.state.duplicate(true);next.level=100;next.items=[]
		for slot in range(48):next.items.append(EditionInventory.make_item("wood_sword",1,"inventory",slot))
		next.items[0]=EditionInventory.make_item("ref:132",1,"inventory",0);next.items[0].purity=18 if matching else 19
		EditionInventory.mirror(next)
		var ground: Dictionary={"uid":Crypto.new().generate_random_bytes(16).hex_encode(),"map":next.map,"cell":next.cell.duplicate(),"type":"ref:132","count":1,"purity":18}
		next.ground_loot=[ground]
		expect(app.rules.apply(next,"full_grade_fixture"),"prepare full bag")
		before=app.rules.state.duplicate(true)
		var picked: bool=app.rules.pickup(ground.uid,ground.map,Vector2i(ground.cell[0],ground.cell[1]))
		expect(picked==matching,"full bag accepts only exact grade stack")
		if not matching:expect(app.rules.state==before,"full unlike-grade bag keeps ground and existing ore")
		else:expect(int(app.rules.state.inventory["ref:132"])==2 and app.rules.state.ground_loot.is_empty(),"same-grade merge keeps total")
	for grade in [-1,18,19]:
		next=app.rules.state.duplicate(true);next.items=[]
		var incoming:=EditionInventory.make_item("ref:132",1,"inventory",0);incoming.purity=18;next.items.append(incoming)
		for slot in range(50):next.items.append(EditionInventory.make_item("wood_sword",1,"warehouse",slot))
		next.items[1]=EditionInventory.make_item("ref:132",1,"warehouse",0)
		if grade>=0:next.items[1].purity=grade
		EditionInventory.mirror(next)
		expect(app.rules.apply(next,"full_warehouse_fixture"),"prepare full warehouse")
		before=app.rules.state.duplicate(true)
		var deposited: bool=app.rules.warehouse("ref:132",true)
		expect(deposited==(grade==18),"full warehouse never blends grades or unknown ore")
		if not deposited:expect(app.rules.state==before,"failed capacity transfer is unchanged")
	var report:={"checks":checks,"failures":failures,"scope":"SQLite graded ore drop/reload/pickup failure and retry; mixed-grade full bag/warehouse rejection and same-grade merge; initial ore fixture, no UI or natural ore generation"}
	FileAccess.open("res://../artifacts/world-story/ore-ground-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
