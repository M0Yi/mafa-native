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
	for i in range(4):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-forge-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	var q: Dictionary=Story.quest("story_dragon_forge")
	for job in ["战士","法师","道士"]:
		app.start_character({"id":"forge"+job,"name":"换装验收","gender":"男","job":job});app.world.paused=true
		var npc: Dictionary=app.rules.story_npc(q.start_npc);var cell:=Vector2i(npc.cell[0],npc.cell[1])
		expect(not app.rules.story_action(q.id,"accept",npc.id,npc.map,cell),"requires expedition homecoming")
		var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_homecoming="done";next.level=100;next.gold=20000;app.rules.apply(next,"forge_prerequisite_fixture")
		expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,cell),"accept forge "+job)
		var monster:={"id":"forge-dragon","spawn_id":"forge-fixture","respawn_seconds":60,"exp":1,"drops":[],"name":"火龙教主","map":"d2083","cell":[75,75]}
		expect(app.rules.reward_kill("forge-dragon:"+job,"",monster,10.0),"forge quest generates ground material")
		var loot: Dictionary={}
		for row in app.rules.state.get("ground_loot",[]):
			if row.type=="dragon_story_scale":loot=row
		expect(not loot.is_empty() and int(loot.count)==1,"single quest material unaffected by preset")
		expect(not app.rules.state.inventory.has("dragon_story_scale"),"material not automatically bagged")
		expect(app.rules.pickup(loot.uid,"d2083",Vector2i(75,75)),"material pickup")
		expect(app.rules.warehouse("dragon_story_scale",true),"store first scale through warehouse rules")
		expect(not Story.ready(app.rules.state,q) and Story.progress(app.rules.state,q,0)==1,"stored scale does not erase kill or satisfy bag requirement")
		expect("再次击败火龙教主" in app.rules.story_materials_text(q),"material instructions explain replacement expedition")
		expect(app.rules.reward_kill("forge-replacement:"+job,"",monster,70.0),"respawned boss can replace scale after kill objective completed")
		var repeated: Dictionary=app.rules.state.duplicate(true)
		expect(not app.rules.reward_kill("forge-replacement-duplicate:"+job,"",monster,70.0) and app.rules.state==repeated,"same boss generation cannot duplicate replacement")
		var replacements: Array=app.rules.state.ground_loot.filter(func(row):return row.type=="dragon_story_scale")
		expect(replacements.size()==1 and int(replacements[0].count)==1,"replacement is a single ground credential")
		if not replacements.is_empty():expect(app.rules.pickup(replacements[0].uid,"d2083",Vector2i(75,75)),"replacement must be picked up")

		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,cell),"missing ore refuses exchange")
		expect("铁矿可向比奇铁匠铺老板购买" in app.rules.story_materials_text(q),"material detail explains actual supplier")
		var purchase_gold: int=app.rules.state.gold
		for unit in range(10):expect(app.rules.reference_trade(npc.id,"ore",true,100.0),"buy required ore through merchant rules")
		expect(app.rules.state.inventory.get("ore",0)==10 and app.rules.state.gold==purchase_gold-10*int(EditionRules.ITEMS.ore.price),"ten ore bought at catalog price")
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,cell) and app.rules.state==before,"failed write consumes no material")
		app.store.db.query("PRAGMA query_only=OFF;")
		var room: Dictionary=app.rules.state.duplicate(true)
		next=app.rules.state.duplicate(true);next.items=[]
		for slot in range(46):next.items.append(EditionInventory.make_item("potion",1,"inventory",slot))
		next.items.append(EditionInventory.make_item("ore",11,"inventory",46));next.items.append(EditionInventory.make_item("dragon_story_scale",2,"inventory",47));EditionInventory.mirror(next)
		expect(app.rules.apply(next,"forge_full_bag_fixture"),"full bag fixture")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,cell) and app.rules.state==before,"no free reward slot preserves materials")
		room.revision=app.rules.state.revision;app.rules.apply(room,"restore_forge_inventory")
		expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,cell),"exchange succeeds after retry")
		var id: String=q.rewards.equipment_by_job[job]
		expect(app.rules.state.inventory.get(id)==1,"correct profession weapon")
		expect(not app.rules.state.inventory.has("ore") and not app.rules.state.inventory.has("dragon_story_scale"),"exact materials consumed")
		expect(app.rules.state.warehouse.get("dragon_story_scale")==1,"delivery preserves previously stored credential")
		var instances: Array=app.rules.state.items.filter(func(item):return item.type==id)
		expect(instances.size()==1 and not str(instances[0].uid).is_empty(),"equipment has unique instance")
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,cell),"exchange cannot repeat")
		expect(app.store.load_world(app.rules.character.id).inventory.get(id)==1,"equipment survives reload")
		var bad: Dictionary=q.duplicate(true);bad.rewards.equipment_by_job[job]="potion"
		expect(app.rules.story_reward_items(bad).is_empty(),"invalid equipment configuration refused")
	var report:={"checks":checks,"failures":failures,"scope":"three profession material exchange, ground pickup, unique equipment, full bag and failed save recovery; combat and prerequisite state controlled"}
	FileAccess.open("res://../artifacts/world-story/forge-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
