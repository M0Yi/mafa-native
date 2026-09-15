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
	for i in range(3):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/demon-purchase-failure-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"fullbag","name":"采购异常","gender":"男","job":"战士"});app.world.hide()
	var q: Dictionary=Story.quest("story_demon_return_supplies");var npc: Dictionary=app.rules.story_npc(q.start_npc)
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_demon_repair="done";next.gold=100000;next.items=[]
	for slot in range(48):next.items.append(EditionInventory.make_item("potion",1,"inventory",slot))
	EditionInventory.mirror(next)
	expect(app.rules.apply(next,"full_inventory_budget_fixture"),"full bag fixture")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])),"accept return supply task")
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.reference_trade("server:merchant:156","return_stone",true,0),"full bag refuses new item type")
	expect(app.rules.state==before and Story.progress(app.rules.state,q,0)==0,"full bag preserves gold stock items and quest")
	expect("空格" in app.rules.message,"full bag error identifies missing space")
	next=app.rules.state.duplicate(true);next.items.pop_back();EditionInventory.mirror(next)
	expect(app.rules.apply(next,"free_one_slot_fixture"),"free one bag slot")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.reference_trade("server:merchant:156","return_stone",true,0) and app.rules.state==before,"save failure preserves entire purchase")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.reference_trade("server:merchant:156","return_stone",true,0),"retry buys after space and write restored")
	expect(Story.ready(app.rules.state,q) and app.rules.state.inventory.get("return_stone",0)==1,"only successful purchase advances objective")
	for i in range(19):expect(app.rules.reference_trade("server:merchant:156","return_stone",true,0),"existing stack can fill remaining stock")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.reference_trade("server:merchant:156","return_stone",true,179.9) and app.rules.state==before,"sold out remains unchanged before restock boundary")
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.reference_trade("server:merchant:156","return_stone",true,180) and app.rules.state==before,"failed restock purchase preserves previous exhausted stock")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.reference_trade("server:merchant:156","return_stone",true,180),"exact restock boundary accepts purchase")
	var stock: Dictionary=app.rules.state.merchant_stock["server:merchant:156:return_stone"]
	expect(int(stock.count)==19 and float(stock.at)==180 and app.rules.state.inventory.get("return_stone",0)==21,"restock and purchase settle once")
	expect(app.rules.state.gold==100000-21*500,"only 21 successful purchases charged")
	expect(Story.progress(app.rules.state,q,0)==1,"repeat purchases do not duplicate objective credit")
	var items: Dictionary=app.rules.state.inventory.duplicate(true)
	expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])) and app.rules.state.inventory==items,"delivery preserves all purchased stones")
	var saved: Dictionary=app.store.load_world(app.rules.character.id)
	expect(saved.inventory.get("return_stone",0)==21 and int(saved.merchant_stock["server:merchant:156:return_stone"].count)==19,"items and remaining merchant stock persist")
	var report:={"checks":checks,"failures":failures,"scope":"actual merchant purchase/quest transactions under full bag, failed save, depleted stock and restock boundary; budget, prior quests, item slots and time fixtures, no physical input or world travel"}
	FileAccess.open("res://../artifacts/world-story/demon-purchase-failure-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
