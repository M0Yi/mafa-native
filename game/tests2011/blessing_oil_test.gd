extends SceneTree
const Oil=preload("res://scripts/edition2011/blessing_oil.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/blessing-oil-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"oil","name":"祝福验收","job":"战士","gender":"男"});app.world.hide()
	var next: Dictionary=app.rules.state.duplicate(true);next.level=100
	next.items=[]
	var weapon:=EditionInventory.make_item("ref:35",1,"inventory",0,37)
	var oil:=EditionInventory.make_item("ref:135",1,"inventory",1)
	next.items=[weapon,oil];EditionInventory.mirror(next)
	check(app.rules.apply(next,"oil_fixture"),"prepare isolated inventory")
	var before: Dictionary=app.rules.state.duplicate(true)
	check(not app.rules.use_item("ref:135") and app.rules.state==before,"no equipped weapon does not consume")
	check(app.rules.inventory_action("use",{"uid":weapon.uid}),"equip target")
	before=app.rules.state.duplicate(true)
	var events: Array=[];app.rules.item_performed.connect(func(type,event):events.append([type,event]))
	app.store.db.query("PRAGMA query_only=ON;")
	check(not app.rules.use_item("ref:135") and app.rules.state==before and events.is_empty(),"failed write preserves oil weapon and events")
	app.store.db.query("PRAGMA query_only=OFF;")
	check(app.rules.use_item("ref:135"),"retry applies oil")
	var changed:=EditionInventory.find_item(app.rules.state,weapon.uid).duplicate(true)
	check(changed.has("blessing") and changed.has("curse") and changed.durability==37,"same weapon receives outcome preserving durability")
	check(EditionInventory.find_item(app.rules.state,oil.uid).is_empty() and events.size()==1,"consumes exact oil once and emits once")
	before=app.rules.state.duplicate(true)
	check(not app.rules.inventory_action("use",{"uid":oil.uid}) and app.rules.state==before and events.size()==1,"stale oil UID cannot repeat")
	app.start_character(app.rules.character.duplicate(true))
	var loaded:=EditionInventory.find_item(app.rules.state,weapon.uid)
	check(int(loaded.get("blessing",-1))==int(changed.blessing) and int(loaded.get("curse",-1))==int(changed.curse),"outcome survives database reload")
	for sample in [[0,0,1,0,1,0],[3,0,0,0,2,0],[0,2,1,0,0,1],[7,0,1,0,7,0],[0,10,0,0,0,10],[1,0,1,1,1,0],[1,0,1,0,2,0]]:
		var item: Dictionary=weapon.duplicate(true);item.blessing=sample[0];item.curse=sample[1]
		var result:=Oil.outcome(item,sample[2],sample[3])
		check(result.blessing==sample[4] and result.curse==sample[5],"reference branch "+str(sample))
	var Books=preload("res://scripts/edition2011/mystery_books.gd")
	var npc: Dictionary=app.rules.story_npc(Books.NPC)
	check(app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]),false),"prepare crafting location")
	app.world.paused=false
	next=app.rules.state.duplicate(true);next.gold=600000
	app.rules.count_item(next,"ref:193",5)
	check(app.rules.apply(next,"oil_craft_material_fixture"),"prepare oil crafting materials")
	before=app.rules.state.duplicate(true)
	var revision: int=int(before.revision)
	check(not Books.craft(app,revision-1,true) and app.rules.state==before,"stale craft confirmation rejected")
	app.store.db.query("PRAGMA query_only=ON;")
	check(not Books.craft(app,revision,true) and app.rules.state==before and app.world.metadata.id==npc.map,"failed craft restores materials and original scene")
	app.store.db.query("PRAGMA query_only=OFF;")
	check(Books.craft(app,revision,true),"actual oil craft transaction")
	check(int(app.rules.state.gold)==100000 and int(app.rules.state.inventory.get("ref:193",0))==0 and int(app.rules.state.inventory.get("ref:135",0))==1,"exact recipe cost and result")
	check(app.world.metadata.id=="d002" and app.rules.state.map=="d002" and app.world.navigation.walkable(app.world.player.cell),"craft returns to saved walkable mine cell")
	before=app.rules.state.duplicate(true)
	check(not Books.craft(app,revision,true) and app.rules.state==before,"duplicate crafting cannot consume again")
	app.start_character(app.rules.character.duplicate(true))
	check(app.rules.state.map=="d002" and int(app.rules.state.inventory.get("ref:135",0))==1,"crafted item and return survive reload")
	var report={"checks":checks,"failures":failures,"scope":"outcome branches and actual item-use transaction/reload; physical input, original audio timing, full combat not verified"}
	FileAccess.open("res://../artifacts/world-story/blessing-oil-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
