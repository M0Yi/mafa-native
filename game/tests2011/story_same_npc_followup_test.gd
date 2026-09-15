extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func click(view,node: Control) -> void:
	var ancestor: Node=node.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(node)
		ancestor=ancestor.get_parent()
	await settle()
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=node.get_global_rect().get_center();e.global_position=e.position;root.push_input(e,true)
	await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/same-npc-followup-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"followup","name":"接续委托","job":"战士","gender":"男"});app.world.hide()
	var q: Dictionary=EditionRules.Story.quest("story_mongchon_medicine_purchase")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_mongchon="done";next.quests[q.id]="accepted";next.gold=1000
	expect(app.rules.apply(next,"accepted_prerequisite_fixture"),"prepare purchase task")
	expect(app.rules.save_location("0160",Vector2i(5,9),0) and app.rules.reference_trade("server:merchant:71","potion",true,0) and app.rules.reference_trade("server:merchant:71","mana",true,0),"actual medicine purchases")
	var elder: Dictionary=app.rules.story_npc(q.end_npc)
	expect(app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1])),"prepare elder delivery location");app.world.paused=false
	app.show_story(elder);await settle();var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	await click(view,view.submit_control)
	expect(app.rules.state.quests.get(q.id)=="done","mouse delivers purchase task")
	expect(app.chat_history.any(func(line):return "新委托：" in line and "留在土城的一份补给" in line),"chat identifies newly unlocked followup")
	var successor: Button=null
	for child in view.details.get_children():
		if child is Button and child.text.begins_with("后续：留在土城的一份补给"):successor=child;break
	expect(successor!=null,"followup action visible")
	if successor==null:app.queue_free();await settle();quit(1);return
	await click(view,successor)
	expect(view.selected=="story_mongchon_storage" and view.npc.get("id")==elder.id,"same giver context retained")
	expect(not app.rules.state.quests.has("story_mongchon_storage") and view.submit_control!=null and not view.submit_control.disabled,"followup available but not autoaccepted")
	var before_accept: Dictionary=app.rules.state.duplicate(true)
	app.world.paused=true
	await click(view,view.submit_control)
	expect(app.rules.state==before_accept,"retained context cannot accept while paused")
	app.world.paused=false
	await click(view,view.submit_control)
	expect(app.rules.state.quests.get("story_mongchon_storage")=="accepted","mouse accepts followup without reopening NPC")
	var before: Dictionary=app.rules.state.duplicate(true)
	view.show_prerequisite("story_letter");await settle()
	expect(view.npc.is_empty() and view.submit_control==null and app.rules.state==before,"different giver clears service context without changing state")
	var report:={"checks":checks,"failures":failures,"scope":"Viewport mouse delivery, successor selection and accept at same NPC; prerequisite/location fixtures, real purchase transactions; no physical input or travel"}
	FileAccess.open("res://../artifacts/world-story/same-npc-followup-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
