extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/novice-meat-nav-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"meat-nav","name":"寻找鸡肉","job":"战士","gender":"男"});app.world.hide();app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests={"nv_arrival":"done","nv_equip":"done","nv_hunt":"accepted"};next.novice={"chickens":3,"patrol":false}
	var target: Vector2i=EditionVillage.SPAWN
	for delta in [Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]:
		if not app.world.navigation.path(EditionVillage.SPAWN,EditionVillage.SPAWN+delta).is_empty():target=EditionVillage.SPAWN+delta;break
	expect(target!=EditionVillage.SPAWN,"reachable drop fixture")
	app.rules.add_ground(next,{"map":"0","cell":[target.x,target.y]},"chicken_meat",3)
	expect(app.rules.apply(next,"accepted_kills_drop_fixture"),"prepare hunt and dropped meat")
	var before: Dictionary=app.rules.state.duplicate(true)
	app.navigate_village_objective("nv_hunt")
	expect("正在接近鸡肉" in app.pending_message,"hunt guide targets ground meat after required kills")
	expect(app.rules.state==before and app.rules.state.inventory.get("chicken_meat",0)==0,"guidance does not auto-pickup or grant meat")
	expect(not app.world.player.route.is_empty() and app.world.player.route.back()==target,"path ends at dropped meat")
	next=app.rules.state.duplicate(true);next.ground_loot=[];next.warehouse.chicken_meat=3
	expect(app.rules.apply(next,"stored_meat_fixture"),"prepare stored meat")
	before=app.rules.state.duplicate(true);app.navigate_village_objective("nv_hunt");await settle()
	expect(app.windows.windows.has("取回任务材料") and app.rules.state==before,"stored meat opens retrieval guide without moving inventory")
	app.windows.close_all();app.world.paused=true
	var route: Array=app.world.player.route.duplicate()
	app.navigate_village_objective("nv_hunt")
	expect(app.world.player.route==route and app.rules.state==before,"paused navigation leaves route and state unchanged")
	app.world.paused=false;app.enter_map("0",Vector2i(325,250));app.world.hide()
	next=app.rules.state.duplicate(true);next.warehouse.clear();next.ground_loot=[]
	app.rules.add_ground(next,{"map":"0","cell":[app.world.player.cell.x,app.world.player.cell.y]},"chicken_meat",3)
	expect(app.rules.apply(next,"outside_village_drop_fixture"),"prepare meat outside village bounds")
	before=app.rules.state.duplicate(true);app.navigate_village_objective("nv_hunt")
	expect("正在接近鸡肉" in app.pending_message and app.rules.state==before,"nearby meat prioritized outside village bounds")
	app.enter_map("2",Vector2i(500,500));app.world.hide();app.world.paused=false
	var map_before: String=app.world.metadata.id
	app.return_to_village();await settle()
	expect(map_before=="2" and app.windows.windows.has("任务远行路线") and app.world.metadata.id==map_before,"cross-map return displays route without teleporting")
	var report:={"checks":checks,"failures":failures,"scope":"prepared accepted kills/drop/warehouse fixtures; normal navigation and retrieval UI, no combat, travel completion or hardware input"}
	FileAccess.open("res://../artifacts/world-story/novice-meat-navigation-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
