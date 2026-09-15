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
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-warehouse-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"warehouse","name":"寄放取回","gender":"男","job":"战士"});app.world.hide()
	var quest_id:=OS.get_environment("MAFA_WAREHOUSE_QUEST")
	if quest_id.is_empty():quest_id="story_seal_warehouse_practice"
	var q: Dictionary=Story.quest(quest_id)
	var npc: Dictionary=app.rules.story_npc(q.start_npc)
	var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.requires[0]]="done"
	expect(app.rules.apply(next,"prerequisite_fixture"),"prerequisite fixture")
	expect(app.rules.warehouse("potion",true),"store before accepting")
	expect(app.rules.story_action(q.id,"accept",q.start_npc,npc.map,at),"accept")
	expect(app.rules.save_location(npc.map,at,0.0),"money house fixture")
	expect(app.rules.warehouse("potion",false),"withdraw existing potion first")
	expect(Story.progress(app.rules.state,q,1)==0,"withdraw before deposit cannot finish second stage")
	expect(app.rules.story_talk(q.start_npc,npc.map,at),"talk")
	expect(Story.progress(app.rules.state,q,0)==0,"talk is not storage")
	expect(app.rules.save_location("0",Vector2i(1,1),0.0) and app.rules.warehouse("potion",true),"other town deposit")
	expect(Story.progress(app.rules.state,q,0)==0,"wrong map does not count")
	expect(app.rules.save_location(npc.map,at,0.0),"return money house")
	var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.warehouse("potion",true) and app.rules.state==before,"failed deposit rolls back item and progress")
	app.store.db.query("PRAGMA query_only=OFF;")
	var item: Dictionary={}
	for row in app.rules.state.items:
		if row.container=="inventory" and row.type=="potion":item=row;break
	expect(app.rules.inventory_action("move",{"uid":item.uid,"container":"warehouse","slot":4}),"drag stack into warehouse through inventory rules")
	expect(Story.progress(app.rules.state,q,0)==1 and Story.progress(app.rules.state,q,1)==0,"deposit counts once, not withdrawal")
	expect(app.rules.inventory_action("move",{"uid":item.uid,"container":"warehouse","slot":5}),"rearrange warehouse slot")
	expect(Story.progress(app.rules.state,q,1)==0,"warehouse rearrangement is not withdrawal")
	expect(not app.rules.story_action(q.id,"submit",q.end_npc,npc.map,at),"deposit alone cannot claim")
	before=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.warehouse("potion",false) and app.rules.state==before,"failed withdrawal rolls back item and progress")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.warehouse("potion",false) and Story.ready(app.rules.state,q),"service withdrawal finishes task")
	expect(Story.progress(app.store.load_world(app.rules.character.id),q,0)==1 and Story.progress(app.store.load_world(app.rules.character.id),q,1)==1,"both stages persisted")
	expect(app.rules.story_action(q.id,"submit",q.end_npc,npc.map,at),"claim")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit",q.end_npc,npc.map,at) and app.rules.state==before,"reward cannot duplicate")
	var report:={"checks":checks,"failures":failures,"scope":"real warehouse and inventory move transactions; prerequisite and map positions are fixtures, no physical mouse/gamepad input"}
	FileAccess.open("res://../artifacts/world-story/warehouse-"+quest_id+"-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
