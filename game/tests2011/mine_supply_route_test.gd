extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var checks:=0
var failures: Array=[]
var frames:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func clear_encounters() -> void:
	app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
func walk() -> void:
	for i in range(18000):
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
		app.world.player.update(1.0/60,Vector2i.ZERO,false);frames+=1
		var gate: Dictionary=app.resources.connections.poll(app.world.player)
		if not gate.is_empty():app.cross_passage(gate);clear_encounters();break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/mine-supply-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"mine","name":"矿道补给","job":"战士","gender":"男"});app.world.hide()
	var q: Dictionary=EditionRules.Story.quest("story_mine_remote_supplies");var elder: Dictionary=app.rules.story_npc(q.start_npc)
	app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1]));app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_mine="done";next.gold=1000;expect(app.rules.apply(next,"prior_mine_fixture"),"prepare prerequisite")
	expect(app.rules.shop("wood_sword",1) and app.rules.use_item("wood_sword"),"equip repairable weapon")
	next=app.rules.state.duplicate(true)
	for item in next.items:
		if item.type=="wood_sword":item.durability=70
	expect(app.rules.apply(next,"wear_fixture"),"prepare worn equipment")
	expect(app.rules.story_action(q.id,"accept",elder.id,elder.map,app.world.player.cell),"accept mine logistics")
	for journey in [["d002","dm001",Vector2i(191,232),"server:merchant:54"],["d012","dm011",Vector2i(189,145),"server:merchant:55"]]:
		expect(app.enter_map(journey[0],journey[2]),"prepare cave doorway position");app.world.paused=false;clear_encounters()
		for target in [journey[1],journey[0]]:
			var routes: Array=Planner.plan(app.resources.connections.by_map,app.world.metadata.id,target,app.world.player.cell,app.world.navigation)
			expect(not routes.is_empty(),"route to "+target)
			for gate in routes:
				expect(gate.kind=="reference","original door route")
				var before_frames: int=frames
				expect(app.world.approach(Vector2i(gate.cell[0],gate.cell[1])),"approach door");walk()
				expect(app.world.metadata.id==target and frames>before_frames,"walk across door")
			if target==journey[1]:
				var npc: Dictionary=app.rules.story_npc(journey[3])
				expect(app.world.approach(Vector2i(npc.cell[0],npc.cell[1])),"approach shopkeeper");walk()
				expect(app.near_reference_npc(npc),"counter reached")
				expect(not EditionRules.Story.ready(app.rules.state,q),"visiting cannot replace service")
				if npc.id.ends_with(":54"):
					expect(app.rules.reference_repair(npc.id),"actual small Li repair")
					for medicine in ["potion","mana"]:
						var gold: int=app.rules.state.gold
						var amount: int=app.rules.state.inventory.get(medicine,0)
						expect(app.rules.reference_trade(npc.id,medicine,true,app.elapsed),"buy reconstructed small Li medicine")
						expect(int(app.rules.state.inventory.get(medicine,0))==amount+1 and app.rules.state.gold==gold-maxi(1,int(EditionRules.ITEMS[medicine].price)*180/100),"small Li medicine uses reference shop price")
					expect(EditionRules.Story.progress(app.rules.state,q,3)==0,"small Li purchase cannot replace named small Zhang objective")
				else:
					var restored: Dictionary=app.rules.state.duplicate(true)
					var poor: Dictionary=restored.duplicate(true);poor.gold=0
					expect(app.rules.apply(poor,"poor_fixture"),"prepare insufficient balance")
					var failed: Dictionary=app.rules.state.duplicate(true)
					expect(not app.rules.reference_trade(npc.id,"potion",true,app.elapsed) and app.rules.state==failed,"insufficient gold changes neither stock nor objective")
					restored.revision=app.rules.state.revision
					expect(app.rules.apply(restored.duplicate(true),"restore_balance_fixture"),"restore balance")
					var full: Dictionary=app.rules.state.duplicate(true);full.level=100;full.items=[]
					for slot in range(48):full.items.append(EditionInventory.make_item("wood_sword",1,"inventory",slot))
					EditionInventory.mirror(full)
					expect(app.rules.apply(full,"full_bag_fixture"),"prepare full bag without potion stack")
					failed=app.rules.state.duplicate(true)
					expect(not app.rules.reference_trade(npc.id,"potion",true,app.elapsed) and app.rules.state==failed,"full bag preserves stock money and objective")
					restored.revision=app.rules.state.revision
					expect(app.rules.apply(restored.duplicate(true),"restore_inventory_fixture"),"restore original inventory")
					failed=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
					expect(not app.rules.reference_trade(npc.id,"potion",true,app.elapsed) and app.rules.state==failed,"save failure rolls back purchase and quest progress")
					app.store.db.query("PRAGMA query_only=OFF;")
					expect(app.rules.reference_trade(npc.id,"potion",true,app.elapsed),"actual small Zhang purchase after retry")
	expect(EditionRules.Story.ready(app.rules.state,q),"both visits and services complete")
	app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1]));app.world.paused=false
	var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action(q.id,"submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before,"failed delivery preserves goods and progress")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action(q.id,"submit",elder.id,elder.map,app.world.player.cell),"deliver logistics")
	expect(app.rules.state.items==before.items and app.rules.state.gold==before.gold+160,"keeps purchased medicine and pays configured reward")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before,"duplicate delivery refused")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.quests[q.id]=="done" and app.rules.state.gold==before.gold,"reload retains logistics")
	var report:={"checks":checks,"failures":failures,"simulated_walk_seconds":frames/60.0,"scope":"both original cave/shop door round trips and actual repair/purchase/delivery; initial doorways, prior quest, wear and return to giver fixtures, monsters removed, no natural journey or physical input"}
	FileAccess.open("res://../artifacts/world-story/mine-supply-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
