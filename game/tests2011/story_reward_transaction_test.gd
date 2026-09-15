extends SceneTree
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/reward-transaction-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"atomic-reward","name":"交付一致性","gender":"男","job":"战士"})
	var q: Dictionary=EditionRules.Story.quest("story_home_tools")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.nv_patrol="done";next.novice={"chickens":0,"patrol":true}
	expect(app.rules.apply(next,"prerequisite_fixture"),"prepare prerequisite")
	var elder: Dictionary=app.rules.story_npc("border:elder")
	var at:=Vector2i(elder.cell[0],elder.cell[1])
	expect(app.rules.story_action(q.id,"accept","border:elder",elder.map,at),"accept real task")
	var smith: Dictionary=app.rules.story_npc(q.objectives[0].npc)
	expect(app.rules.story_talk(smith.id,smith.map,Vector2i(smith.cell[0],smith.cell[1])),"complete actual talk event")
	var ordinary: Dictionary=app.rules.state.duplicate(true)
	next=ordinary.duplicate(true);next.items=[];next.inventory={};next.warehouse={}
	for i in range(48):next.items.append(EditionInventory.make_item("mana",1,"inventory",i))
	EditionInventory.mirror(next)
	expect(app.rules.apply(next,"full_bag_fixture"),"fill all slots with eligible light stacks")
	var full: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit","border:elder",elder.map,at) and app.rules.state==full and "空格" in app.rules.message,"full bag refuses reward and preserves eligibility")
	next=ordinary.duplicate(true);next.revision=app.rules.state.revision;next.level=100;next.items=[];next.inventory={"mana":600};next.warehouse={}
	expect(app.rules.apply(next,"full_weight_fixture"),"prepare maximum-level exact weight limit")
	var heavy: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit","border:elder",elder.map,at) and app.rules.state==heavy and "负重" in app.rules.message,"overweight reward refuses without consuming eligibility")
	ordinary.revision=app.rules.state.revision
	expect(app.rules.apply(ordinary,"restore_available_space"),"restore room for reward")
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
	expect(after.quests[q.id]=="done" and after.inventory.potion==before.inventory.potion+1 and after.gold==before.gold+120 and after.quest_receipts.has(q.id),"task, potion, gold and receipt commit together")
	expect(JSON.parse_string(JSON.stringify(app.store.load_world(app.rules.character.id)))==JSON.parse_string(JSON.stringify(after)),"complete reward persists")
	expect(not app.rules.story_action(q.id,"submit","border:elder",elder.map,at) and app.rules.state==after,"retry after success cannot duplicate reward")
	var report:={"checks":checks,"failures":failures,"scope":"SQL trigger abort after world-row write before operation receipt, rollback and retry; NPC positions and prerequisite fixtures; no forced termination during COMMIT or power-loss simulation"}
	FileAccess.open("res://../artifacts/world-story/reward-transaction-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
