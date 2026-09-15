extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
const Mining=preload("res://scripts/edition2011/mining.gd")
var app
var checks:=0
var failures: Array=[]
var frames:=0
var gates: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func clear_encounters() -> void:app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
func walk() -> void:
	for i in range(60000):
		if app.world.player.route.is_empty() and app.world.player.progress>=1:return
		app.world.player.update(1.0/60,Vector2i.ZERO,false);frames+=1;app.elapsed+=1.0/60;app.world.elapsed=app.elapsed
		var gate: Dictionary=app.resources.connections.poll(app.world.player)
		if not gate.is_empty():
			gates.append({"id":gate.id,"kind":gate.kind,"from":app.world.metadata.id,"to":gate.target_map})
			app.cross_passage(gate);clear_encounters();return
func travel(target: String) -> bool:
	for hop in range(30):
		if app.world.metadata.id==target:return true
		var route: Array=Planner.plan(app.resources.connections.by_map,app.world.metadata.id,target,app.world.player.cell,app.world.navigation)
		if route.is_empty():return false
		var gate: Dictionary=route[0]
		if not app.world.approach(Vector2i(gate.cell[0],gate.cell[1])):return false
		var before:=gates.size();walk()
		if gates.size()==before:return false
	return false
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/mining-journey-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"journey","name":"矿区往返","job":"战士","gender":"男"});app.world.hide()
	var smith: Dictionary=app.rules.story_npc("server:merchant:56")
	expect(app.enter_map(smith.map,Vector2i(-1,-1),false),"initial smith room fixture")
	app.world.paused=false;clear_encounters()
	expect(app.world.approach(Vector2i(smith.cell[0],smith.cell[1])),"approach smith");walk()
	expect(app.near_reference_npc(smith),"reach actual smith")
	var next: Dictionary=app.rules.state.duplicate(true);next.level=22;next.gold=10000;next.quests.story_mine="done"
	expect(app.rules.apply(next,"level_funds_prerequisite_fixture"),"prepare level funds and prior exploration")
	expect(app.rules.reference_trade(smith.id,"ref:87",true,app.elapsed) and app.rules.use_item("ref:87"),"buy and equip pickaxe")
	var q: Dictionary=EditionRules.Story.quest("story_mine_practice")
	expect(app.rules.story_action(q.id,"accept",smith.id,smith.map,app.world.player.cell),"accept mining practice")
	expect(travel("d401"),"walk from smith through actual passages to mine")
	expect(app.rules.story_materials_text(q).contains("已装备鹤嘴锄"),"task preparation reflects equipped mining tool")
	if app.world.metadata.id=="d401":
		var spot: Dictionary=Mining.nearby_wall(app.world.navigation,app.world.player.cell,"d401",app.rules.state.get("mining",{}),app.elapsed)
		expect(not spot.is_empty(),"task helper finds mine wall")
		var destination: Vector2i=spot.get("cell",Vector2i(-1,-1))
		var facing: int=int(spot.get("direction",0))
		preload("res://scripts/edition2011/peach_crafting.gd").sources_panel(app,{"name":"金矿来源","materials":{"ref:132":5}})
		await settle()
		var buttons: Array=app.panel.find_children("*","Button",true,false).filter(func(b):return b.text=="前往废矿寻找矿壁")
		expect(buttons.size()==1,"source panel has one mine navigation action")
		if buttons.size()==1:
			app.world.paused=true
			var before: Dictionary=app.rules.state.duplicate(true)
			var route_before: Array=app.world.player.route.duplicate()
			buttons[0].pressed.emit()
			expect(app.world.player.route==route_before and app.rules.state==before,"paused source navigation preserves route and persistent state")
			expect(app.windows.windows.has("合成材料来源"),"paused navigation keeps source page available")
			app.world.paused=false
			buttons[0].pressed.emit()
			expect(not app.windows.windows.has("合成材料来源"),"successful source navigation closes page")
		walk()
		expect(app.world.metadata.id=="d401" and app.world.player.cell==destination,"task navigation reaches wall without unintended passage")
		app.world.player.direction=facing
		for swing in range(100):
			if EditionRules.Story.ready(app.rules.state,q):break
			app.elapsed+=1;app.fight_timer=0;app.attack_target()
			for loot in app.rules.state.get("ground_loot",[]).duplicate(true):
				expect(app.gameplay.pickup(loot),"pick actual mined ore")
		expect(EditionRules.Story.ready(app.rules.state,q),"mining completes practice during journey")
		expect(not app.rules.story_materials_text(q).contains("采矿准备"),"completed mining removes preparation requirement")
		expect(travel(smith.map),"walk mine to smith through actual passages")
	if app.world.metadata.id==smith.map:
		expect(app.world.approach(Vector2i(smith.cell[0],smith.cell[1])),"approach smith on return");walk()
		expect(app.near_reference_npc(smith),"return to smith service range")
		expect(app.rules.reference_repair(smith.id),"repair mining wear after actual return")
		expect(app.rules.story_action(q.id,"submit",smith.id,smith.map,app.world.player.cell),"deliver practice after actual return")
	expect(frames>0 and gates.size()>=4,"journey performed movement and crossings")
	var report:={"checks":checks,"failures":failures,"gates":gates,"movement_frames":frames,"scope":"source-panel signal navigation with pause/retry, actual player updates and passage polling, purchase/equip/mine/pickup/repair/quest delivery; initial smith room, funds, level and prerequisite fixtures, monsters removed; no physical input or combat"}
	FileAccess.open("res://../artifacts/world-story/mining-journey-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
