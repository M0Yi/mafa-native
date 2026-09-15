extends SceneTree
var app
var checks:=0
var failures: Array=[]
var sounds: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func run() -> void:
	var Mining=preload("res://scripts/edition2011/mining.gd")
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/mining-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"miner","name":"采矿验证","job":"战士","gender":"男"});app.world.hide()
	expect(app.enter_map("d401",Vector2i(-1,-1),false),"enter mining map")
	var spawn: Vector2i=app.world.player.cell
	var found:=false
	for y in range(app.world.navigation.size.y):
		if found:break
		for x in range(app.world.navigation.size.x):
			var at:=Vector2i(x,y)
			if app.world.navigation.path(spawn,at).is_empty():continue
			for direction in range(8):
				if Mining.wall(app.world.navigation,at,direction):
					app.world.player.cell=at;app.world.player.direction=direction;found=true;break
			if found:break
	expect(found,"reachable natural wall exists")
	var mining_cell: Vector2i=app.world.player.cell
	var mining_direction: int=app.world.player.direction
	var next: Dictionary=app.rules.state.duplicate(true);next.level=100;next.quests.story_mine="done";next.map="d401";next.cell=[app.world.player.cell.x,app.world.player.cell.y]
	next.items=[EditionInventory.make_item("ref:87",1,"equipment",0)];EditionInventory.mirror(next)
	var attempt:=1
	while attempt<10000:
		var ore: Dictionary=Mining.result("miner",attempt)
		if ore.get("type")=="ref:132" and int(ore.get("purity",0))>=18:break
		attempt+=1
	expect(attempt<10000,"reconstructed sequence can yield craft gold")
	var wall_cell: Vector2i=mining_cell+ClassicNavigation.DIRECTIONS[mining_direction]
	var vein_key: String="d401:%d:%d"%[wall_cell.x,wall_cell.y]
	next.mining={"attempts":attempt-1,"ready":0.0,"veins":{vein_key:{"used":199,"restore_at":0.0}}}
	expect(app.rules.apply(next,"mining_fixture"),"prepare equipped tool and deterministic attempt")
	var practice_before: Dictionary=EditionRules.Story.quest("story_mine_practice")
	var teacher: Dictionary=app.rules.story_npc(practice_before.start_npc)
	expect(app.rules.story_action(practice_before.id,"accept",teacher.id,teacher.map,Vector2i(teacher.cell[0],teacher.cell[1])),"accept before transactional mining")
	var isolated: Dictionary=app.rules.state.duplicate(true)
	var unchanged: Dictionary=isolated.duplicate(true)
	expect(not EditionRules.Story.observe(isolated,"mine",{"map":"d402","item":"ref:132"}) and isolated==unchanged,"other mining map does not count")
	expect(not EditionRules.Story.observe(isolated,"mine",{"map":"d401","item":"potion"}) and isolated==unchanged,"non ore event does not count")
	expect(not EditionRules.Story.observe(isolated,"purchase",{"npc":teacher.id,"item":"ore"}) and isolated==unchanged,"purchase is not mining progress")
	app.sound_started.connect(func(id):sounds.append(id))
	app.world.paused=false;app.elapsed=10
	var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(Mining.swing(app) and app.rules.state==before,"failed write preserves roll tool and ground")
	expect(EditionRules.Story.progress(app.rules.state,practice_before,0)==0,"failed mining commit grants no task progress")
	expect(sounds.is_empty(),"failed mining does not play strike sound")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(Mining.swing(app),"retry mining")
	expect(sounds==[91],"successful swing plays dedicated stone strike once")
	expect(EditionRules.Story.progress(app.rules.state,practice_before,0)==1,"retry counts once with saved ore")
	expect(app.rules.state.mining.attempts==attempt and app.rules.state.items[0].durability==99,"one attempt and durability cost")
	expect(app.rules.state.inventory.get("ref:132",0)==0,"ore not automatically put in bag")
	var loot: Dictionary=app.rules.state.ground_loot[-1]
	expect(loot.type=="ref:132" and loot.purity>=18 and loot.map=="d401","graded gold placed on current ground")
	before=app.rules.state.duplicate(true)
	expect(Mining.swing(app) and app.rules.state==before,"cooldown prevents duplicate swing")
	expect(sounds==[91],"cooldown does not repeat stone strike")
	expect(app.rules.pickup(loot.uid,"d401",app.world.player.cell),"pick up mined ore")
	expect(app.rules.state.items.filter(func(i):return i.type=="ref:132" and i.get("purity",0)==loot.purity).size()==1,"pickup retains mining purity")
	expect(EditionRules.Story.progress(app.rules.state,practice_before,0)==1,"pickup does not count the same ore twice")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(EditionRules.Story.progress(app.rules.state,practice_before,0)==1,"partial task progress survives reload")
	expect(app.rules.state.mining.attempts==attempt and app.rules.state.mining.ready==11,"attempt and cooldown survive reload")
	expect(app.rules.state.mining.veins[vein_key].used==200 and app.rules.state.mining.veins[vein_key].restore_at==610,"last vein swing and restoration deadline saved")
	app.enter_map("d401",mining_cell,false);app.world.player.direction=mining_direction;app.world.paused=false
	before=app.rules.state.duplicate(true);app.elapsed=609.99
	expect(Mining.swing(app) and app.rules.state==before,"exhausted vein blocks ore wear and progress before deadline")
	app.elapsed=610;app.world.paused=true
	expect(Mining.swing(app) and app.rules.state==before,"paused world cannot restore vein")
	app.world.paused=false;app.store.db.query("PRAGMA query_only=ON;")
	expect(Mining.swing(app) and app.rules.state==before,"restoration write failure preserves exhaustion")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(Mining.swing(app) and app.rules.state.mining.veins[vein_key].used==1 and app.rules.state.mining.veins[vein_key].restore_at==0,"exact deadline resets vein and consumes one swing")
	var invalid: Dictionary=app.rules.state.mining.duplicate(true);invalid.veins[vein_key].used=201
	expect(not Mining.valid(invalid),"overfull vein state rejected")
	expect(not Mining.valid({"attempts":-1,"ready":0}) and not Mining.valid({"attempts":1,"ready":NAN}),"invalid mining persistence rejected")
	app.start_character({"id":"natural-miner","name":"连续采矿","job":"战士","gender":"男"});app.world.hide()
	var merchant: Dictionary=app.rules.story_npc("server:merchant:56")
	next=app.rules.state.duplicate(true);next.level=21;next.quests.story_mine="done";next.gold=10000;next.map=merchant.map;next.cell=merchant.cell.duplicate()
	expect(app.rules.apply(next,"funds_level_shop_fixture"),"prepare shop funds and level")
	expect(app.rules.story_action("story_mine_practice","accept",merchant.id,merchant.map,Vector2i(merchant.cell[0],merchant.cell[1])),"accept mining practice from blacksmith")
	var practice: Dictionary=EditionRules.Story.quest("story_mine_practice")
	expect(EditionRules.Story.progress(app.rules.state,practice,0)==0,"practice begins at zero")
	expect(app.rules.reference_trade(merchant.id,"ref:87",true,0),"buy pickaxe from actual blacksmith stock")
	var tools: Array=app.rules.state.items.filter(func(i):return i.type=="ref:87")
	expect(tools.size()==1,"purchased pickaxe has one instance")
	var tool_uid: String=tools[0].uid
	expect(not app.rules.inventory_action("use",{"uid":tool_uid}),"level 21 cannot equip level 22 pickaxe")
	next=app.rules.state.duplicate(true);next.level=22
	expect(app.rules.apply(next,"level22_fixture") and app.rules.inventory_action("use",{"uid":tool_uid}),"level 22 equips purchased pickaxe")
	expect(app.enter_map("d401",mining_cell,false),"enter reachable mining wall")
	app.world.player.direction=mining_direction;app.world.paused=false;app.selected={}
	app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
	for swing in range(100):
		app.elapsed=100+swing;app.fight_timer=0
		app.attack_target()
		expect(int(app.rules.state.get("mining",{}).get("attempts",0))==swing+1,"attack entry commits consecutive swing "+str(swing))
	expect(EditionRules.Story.progress(app.rules.state,practice,0)==3 and EditionRules.Story.ready(app.rules.state,practice),"actual mined output completes bounded progress")
	expect(EditionInventory.find_item(app.rules.state,tool_uid).durability==0,"100 swings exhaust purchased pickaxe")
	var outputs: Array=app.rules.state.get("ground_loot",[])
	expect(not outputs.is_empty(),"unmodified attempt sequence produces ore")
	for loot_record in outputs:
		expect(loot_record.map=="d401" and loot_record.purity>=1 and loot_record.purity<=20,"all natural outputs retain valid purity")
	before=app.rules.state.duplicate(true);app.elapsed+=1;app.fight_timer=0;app.attack_target()
	expect(app.rules.state==before,"broken pickaxe cannot create further ore or attempts")
	expect(app.enter_map(merchant.map,Vector2i(-1,-1),false),"load actual smith interior for repair")
	expect(app.world.approach(Vector2i(merchant.cell[0],merchant.cell[1])),"path from interior landing to smith")
	for frame in range(12000):
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
		app.world.player.update(1.0/60,Vector2i.ZERO,false)
	expect(app.near_reference_npc(merchant),"walk to smith service range")
	var quote: Dictionary=app.rules.reference_repair_quote(merchant.id)
	expect(quote.items.size()==1 and quote.items[0].uid==tool_uid and quote.cost>0,"repair quote targets the purchased broken tool")
	before=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.reference_repair(merchant.id) and app.rules.state==before,"failed repair preserves tool money mining and ground ore")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.reference_repair(merchant.id),"retry actual smith repair")
	expect(EditionInventory.find_item(app.rules.state,tool_uid).durability==100 and app.rules.state.gold==before.gold-int(quote.cost),"same tool repaired for exact quoted cost")
	expect(app.rules.state.ground_loot==before.ground_loot and app.rules.state.mining==before.mining,"repair preserves all mined ore and sequence")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.reference_repair(merchant.id) and app.rules.state==before,"already repaired tool cannot be charged twice")
	expect(app.save_world(),"save smith position before reload")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(EditionInventory.find_item(app.rules.state,tool_uid).durability==100 and app.rules.state.mining.attempts==100,"repaired original tool and sequence survive reload")
	expect(app.enter_map("d401",mining_cell,false),"return to mine after repair")
	app.world.player.direction=mining_direction;app.world.paused=false;app.selected={};app.pending_attack.clear()
	app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
	app.elapsed=maxf(app.elapsed+1,float(app.rules.state.mining.ready));app.fight_timer=0;app.attack_target()
	expect(app.rules.state.mining.attempts==101 and EditionInventory.find_item(app.rules.state,tool_uid).durability==99,"repaired tool continues next attempt without resetting sequence")
	expect(app.rules.story_action(practice.id,"submit",merchant.id,merchant.map,Vector2i(merchant.cell[0],merchant.cell[1])),"submit practice at blacksmith")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(practice.id,"submit",merchant.id,merchant.map,Vector2i(merchant.cell[0],merchant.cell[1])) and app.rules.state==before,"cannot claim practice twice")
	expect(EditionRules.ITEMS["ref:178"].name=="黑铁矿石" and int(EditionRules.ITEMS["ref:178"].std_mode)==43,"black iron maps to actual ore catalog entry")
	expect(not app.resources.frame("items",284).is_empty(),"black iron original icon available")
	var iron_attempt:=1
	while iron_attempt<10000 and Mining.result("black-iron",iron_attempt).get("type")!="ref:178":iron_attempt+=1
	expect(iron_attempt<10000,"current distribution yields black iron")
	var black_ore: Dictionary=Mining.result("black-iron",iron_attempt)
	next=app.rules.state.duplicate(true)
	app.rules.add_ground(next,{"map":"d401","cell":[mining_cell.x,mining_cell.y]},black_ore.type,1)
	next.ground_loot[-1].purity=black_ore.purity
	var black_uid: String=next.ground_loot[-1].uid
	expect(app.rules.apply(next,"black_iron_ground_fixture") and app.rules.pickup(black_uid,"d401",mining_cell),"black iron mined-format drop can be picked up")
	expect(app.rules.state.items.any(func(i):return i.type=="ref:178" and i.get("purity",0)==black_ore.purity),"black iron keeps its own type and purity")
	var report:={"checks":checks,"failures":failures,"scope":"runtime mining/SQLite/ground pickup, actual shop purchase, level gate, 100 attack-entry swings from attempt one and broken tool; funds/level/location and first isolated successful roll prepared, monsters removed; no physical input or full crafting journey"}
	FileAccess.open("res://../artifacts/world-story/mining-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
