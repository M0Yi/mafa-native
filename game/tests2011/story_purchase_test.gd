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
	app.store.path="/tmp/story-purchase-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"buy","name":"实际购药","gender":"男","job":"战士"});app.world.hide()
	var q: Dictionary=Story.quest("story_moon_purchase");var npc: Dictionary=app.rules.story_npc(q.start_npc)
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_moon_indoor_supplies="done";next.gold=10000
	expect(app.rules.apply(next,"purchase_fixture"),"prerequisite and budget fixture")
	expect(app.rules.reference_trade("server:merchant:116","potion",true,0),"purchase before accepting")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])),"accept")
	expect(Story.progress(app.rules.state,q,0)==0 and not Story.ready(app.rules.state,q),"old inventory and prior purchase do not count")
	expect(app.rules.reference_trade("server:merchant:5","potion",true,0),"buy from other shop")
	expect(Story.progress(app.rules.state,q,0)==0,"other shop does not count")
	app.rules.reference_trade("server:merchant:116","potion",false,0)
	expect(Story.progress(app.rules.state,q,0)==0,"selling does not count")
	next=app.rules.state.duplicate(true);next.gold=0;expect(app.rules.apply(next,"empty_purse_fixture"),"empty budget fixture")
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.reference_trade("server:merchant:116","potion",true,0) and app.rules.state==before,"insufficient gold cannot advance task")
	next=app.rules.state.duplicate(true);next.gold=10000;expect(app.rules.apply(next,"restore_budget_fixture"),"restore budget")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.reference_trade("server:merchant:116","potion",true,0) and app.rules.state==before,"failed commit preserves stock gold item and progress")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.reference_trade("server:merchant:116","potion",true,0),"named red purchase")
	expect(Story.progress(app.rules.state,q,0)==1 and not Story.ready(app.rules.state,q),"red does not replace blue")
	expect(app.rules.reference_trade("server:merchant:116","mana",true,0) and Story.ready(app.rules.state,q),"named blue purchase completes requirements")
	var inventory: Dictionary=app.rules.state.inventory.duplicate(true)
	expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])) and app.rules.state.inventory==inventory,"delivery does not confiscate purchases")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])) and app.rules.state==before,"no duplicated reward")
	var report:={"checks":checks,"failures":failures,"scope":"actual reference shop transactions, failure and named merchant progress; prerequisites, budget and interaction locations are fixtures, not mouse purchase or travel"}
	FileAccess.open("res://../artifacts/world-story/purchase-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
