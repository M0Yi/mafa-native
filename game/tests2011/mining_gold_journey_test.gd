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
func travel(target: String,reference_only:=false) -> bool:
	var connections: Dictionary=app.resources.connections.by_map
	if reference_only:
		connections=connections.duplicate(true)
		for mid in connections:connections[mid]=connections[mid].filter(func(g):return g.kind=="reference")
	for hop in range(30):
		if app.world.metadata.id==target:return true
		var route: Array=Planner.plan(connections,app.world.metadata.id,target,app.world.player.cell,app.world.navigation)
		if route.is_empty():return false
		var gate: Dictionary=route[0]
		if not app.world.approach(Vector2i(gate.cell[0],gate.cell[1])):return false
		var before:=gates.size();walk()
		if gates.size()==before:return false
	return false
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/mining-gold-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"journey-gold","name":"高纯度金矿往返","job":"战士","gender":"男"});app.world.hide()
	var smith: Dictionary=app.rules.story_npc("server:merchant:56")
	expect(app.enter_map(smith.map,Vector2i(-1,-1),false),"initial smith room fixture")
	app.world.paused=false;clear_encounters()
	expect(app.world.approach(Vector2i(smith.cell[0],smith.cell[1])),"approach smith");walk()
	expect(app.near_reference_npc(smith),"reach actual smith")
	var next: Dictionary=app.rules.state.duplicate(true);next.level=22;next.gold=1500000;next.quests.story_mine="done";next.quests.story_feast_old_liu="done"
	expect(app.rules.apply(next,"level_funds_prerequisite_fixture"),"prepare level funds and prior exploration")
	expect(app.rules.reference_trade(smith.id,"ref:87",true,app.elapsed) and app.rules.use_item("ref:87"),"buy and equip pickaxe")
	var q: Dictionary=EditionRules.Story.quest("story_mine_practice")
	expect(app.rules.story_action(q.id,"accept",smith.id,smith.map,app.world.player.cell),"accept mining practice")
	var cycles:=0
	while gold_count()<5 and cycles<20:
		cycles+=1
		expect(travel("d401"),"walk smith to mine cycle "+str(cycles))
		if app.world.metadata.id!="d401":break
		var origin: Vector2i=app.world.player.cell
		var destination:=Vector2i(-1,-1);var facing:=0
		for radius in range(1,50):
			if destination.x>=0:break
			for y in range(origin.y-radius,origin.y+radius+1):
				for x in range(origin.x-radius,origin.x+radius+1):
					var at:=Vector2i(x,y)
					if app.world.navigation.path(origin,at).is_empty():continue
					for direction in range(8):
						if not Mining.wall(app.world.navigation,at,direction):continue
						var target: Vector2i=at+ClassicNavigation.DIRECTIONS[direction]
						var key: String="d401:%d:%d"%[target.x,target.y]
						var vein: Dictionary=app.rules.state.get("mining",{}).get("veins",{}).get(key,{"used":0,"restore_at":0})
						if int(vein.used)>=Mining.VEIN_SWINGS and app.elapsed<float(vein.restore_at):continue
						destination=at;facing=direction;break
					if destination.x>=0:break
				if destination.x>=0:break
		expect(destination.x>=0 and app.world.player.go_to(destination),"walk to nondepleted wall");walk()
		expect(app.world.metadata.id=="d401" and app.world.player.cell==destination,"reach selected wall")
		if app.world.metadata.id!="d401":break
		app.world.player.direction=facing
		for swing in range(100):
			if gold_count()>=5:break
			var attempts:=int(app.rules.state.get("mining",{}).get("attempts",0))
			app.elapsed+=1;app.fight_timer=0;app.attack_target()
			if int(app.rules.state.get("mining",{}).get("attempts",0))==attempts:break
			for loot in app.rules.state.get("ground_loot",[]).duplicate(true):
				if loot.type=="ref:132" and int(loot.get("purity",0))>=18 and loot.map=="d401" and Vector2(loot.cell[0]-app.world.player.cell.x,loot.cell[1]-app.world.player.cell.y).length()<=1.5:
					expect(app.gameplay.pickup(loot),"pickup naturally generated crafting gold")
		expect(travel(smith.map),"walk to smith for repair cycle "+str(cycles))
		if app.world.metadata.id!=smith.map:break
		expect(app.world.approach(Vector2i(smith.cell[0],smith.cell[1])),"approach smith");walk()
		expect(app.near_reference_npc(smith) and app.rules.reference_repair(smith.id),"actual repair after round trip")
		expect(app.save_world(),"save journey position and all mined material")
		app.start_character(app.rules.character.duplicate(true));app.world.hide();app.world.paused=false;clear_encounters()
		print(JSON.stringify({"cycle":cycles,"gold_ore":gold_count(),"attempts":app.rules.state.get("mining",{}).get("attempts",0)}))
	expect(gold_count()>=5,"natural mining and repair cycles provide warrior recipe gold")
	expect(app.rules.story_action(q.id,"submit",smith.id,smith.map,app.world.player.cell),"deliver practice after final actual return")
	var prepared_gold:=gold_count()
	var exchange: Dictionary=app.rules.story_npc("server:merchant:105")
	expect(reach(exchange),"walk to gold bar exchanger")
	expect(app.near_reference_npc(exchange) and app.rules.exchange_gold_bar(exchange.id,exchange.map,app.world.player.cell,true),"exchange actual gold bar with carried money")
	var elder: Dictionary=app.rules.story_npc("server:merchant:108")
	expect(reach(elder),"walk to maze elder")
	var Clues=preload("res://scripts/edition2011/bagua_clues.gd")
	for index in range(4):expect(app.near_reference_npc(elder) and Clues.buy(app.rules,index,elder.map,app.world.player.cell),"buy clue "+str(index))
	expect(Clues.travel(app,false),"enter maze through actual elder service");clear_encounters()
	var maze_start:=gates.size()
	expect(travel("q016",true),"follow reference maze passage network")
	expect(gates.slice(maze_start).all(func(g):return g.kind=="reference"),"maze uses only reference gates")
	var maker: Dictionary=app.rules.story_npc("server:merchant:109")
	expect(reach(maker),"walk to mystery craftsman")
	var craft_quest: String="story_mystery_forge_warrior"
	expect(app.near_reference_npc(maker) and app.rules.story_action(craft_quest,"accept",maker.id,maker.map,app.world.player.cell),"accept warrior craft report")
	var Books=preload("res://scripts/edition2011/mystery_books.gd")
	expect(Books.craft(app,int(app.rules.state.revision)),"craft with naturally mined gold and purchased bar");clear_encounters()
	expect(app.rules.state.inventory.get("ref:35",0)==1 and gold_count()==0 and not app.rules.state.inventory.has("ref:226"),"exact natural recipe becomes weapon")
	var liu: Dictionary=app.rules.story_npc("server:merchant:53")
	expect(reach(liu),"walk after crafting return to Liu")
	expect(app.near_reference_npc(liu) and app.rules.story_action(craft_quest,"submit",liu.id,liu.map,app.world.player.cell),"deliver crafted weapon report")
	expect(app.save_world(),"save completed mining craft journey")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.quests.get(craft_quest)=="done" and app.rules.state.inventory.get("ref:35",0)==1,"full journey weapon and task survive reload")
	expect(frames>0 and gates.size()>=4,"journey performed movement and crossings")
	var report:={"checks":checks,"failures":failures,"gates":gates,"movement_frames":frames,"cycles":cycles,"gold_before_craft":prepared_gold,"crafting_gold":gold_count(),"mining_attempts":app.rules.state.get("mining",{}).get("attempts",0),"scope":"continuous natural rolls and repeated repair/reload, only qualifying gold picked; actual player updates and passage polling, purchase/equip/mine/pickup/repair/quest delivery; initial smith room, funds, level and prerequisite fixtures, monsters removed; no physical input or combat"}
	FileAccess.open("res://../artifacts/world-story/mining-gold-journey-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)

func gold_count() -> int:
	var count:=0
	for item in app.rules.state.items:
		if item.container=="inventory" and item.type=="ref:132" and int(item.get("purity",0))>=18:count+=int(item.count)
	return count

func reach(npc: Dictionary) -> bool:
	if not travel(npc.map):return false
	if not app.world.approach(Vector2i(npc.cell[0],npc.cell[1])):return false
	walk()
	return app.near_reference_npc(npc)
