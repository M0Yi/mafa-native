extends SceneTree
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/reward-exchange-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"atomic-reward","name":"交付一致性","gender":"男","job":"战士"})
	var q: Dictionary=EditionRules.Story.quest("story_home_food")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_home_tools="done"
	expect(app.rules.apply(next,"prerequisite_fixture"),"prepare prerequisite")
	var elder: Dictionary=app.rules.story_npc("border:elder")
	var at:=Vector2i(elder.cell[0],elder.cell[1])
	expect(app.rules.story_action(q.id,"accept","border:elder",elder.map,at),"accept real task")
	var smith: Dictionary=app.rules.story_npc(q.objectives[0].npc)
	expect(app.rules.story_talk(smith.id,smith.map,Vector2i(smith.cell[0],smith.cell[1])),"complete actual talk event")
	next=app.rules.state.duplicate(true);next.items=[];next.inventory={};next.warehouse={}
	for i in range(47):next.items.append(EditionInventory.make_item("charm",1,"inventory",i))
	next.items.append(EditionInventory.make_item("chicken_meat",2,"inventory",47));EditionInventory.mirror(next)
	expect(app.rules.apply(next,"full_exchange_bag"),"fill bag including exactly two task materials")
	var before: Dictionary=app.rules.state.duplicate(true)
	var disk_before: Dictionary=app.store.load_world(app.rules.character.id)
	# Store.commit writes the world row before it inserts the operation receipt.
	expect(app.store.db.query("CREATE TEMP TRIGGER reject_story_receipt BEFORE INSERT ON operations WHEN NEW.action = 'story_submit' BEGIN SELECT RAISE(ABORT, 'injected receipt insertion failure'); END;"),"install failure after world update")
	expect(not app.rules.story_action(q.id,"submit","border:elder",elder.map,at),"receipt insertion failure rejects reward")
	expect(app.rules.state==before,"memory retains progress, items and wealth")
	expect(app.store.load_world(app.rules.character.id)==disk_before,"world update rolled back with failed operation insertion")
	var operation_id: String=app.rules.character.id+":"+q.id
	app.store.db.query_with_bindings("SELECT COUNT(*) AS total FROM operations WHERE id=?;",[operation_id])
	expect(int(app.store.db.query_result[0].total)==0,"failed transaction leaves no operation receipt")
	expect(app.store.db.query("DROP TRIGGER reject_story_receipt;"),"remove injected failure")
	expect(app.rules.story_action(q.id,"submit","border:elder",elder.map,at),"retry commits complete reward")
	var after: Dictionary=app.rules.state.duplicate(true)
	expect(after.quests[q.id]=="done" and after.inventory.get("potion",0)==2 and not after.inventory.has("chicken_meat") and after.gold==before.gold+180 and after.quest_receipts.has(q.id),"task, potion, gold and receipt commit together")
	expect(JSON.parse_string(JSON.stringify(app.store.load_world(app.rules.character.id)))==JSON.parse_string(JSON.stringify(after)),"complete reward persists")
	expect(not app.rules.story_action(q.id,"submit","border:elder",elder.map,at) and app.rules.state==after,"retry after success cannot duplicate reward")
	expect(after.items.filter(func(item):return item.container=="inventory").size()==48,"reward reuses freed material slot")
	expect(after.quest_receipts[q.id].consumed.get("chicken_meat",0)==2 and after.quest_receipts[q.id].items.get("potion",0)==2,"receipt records exchanged materials and rewards")
	var report:={"checks":checks,"failures":failures,"scope":"full bag with consumed task materials freeing reward slot; SQL failure rolls back exchange and retry succeeds; NPC positions and item fixtures, no hardware input"}
	FileAccess.open("res://../artifacts/world-story/reward-exchange-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
