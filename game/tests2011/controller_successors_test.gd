extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func press(key: int) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=key;event.pressed=true;root.push_input(event,true);await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/controller-successors-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"successors","name":"分支验收","gender":"男","job":"战士"})
	var npc: Dictionary=app.rules.story_npc("server:merchant:4")
	expect(app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i(1,0)),"load actual NPC map")
	app.world.paused=false
	app.controller_interact(npc);await settle()
	var view=app.form.get_child(1)
	for i in range(1,view.rows.size()):expect(view.row_priority(view.rows[i-1])<=view.row_priority(view.rows[i]),"NPC list ordered by actionable priority")
	for i in range(view.rows.size()):
		if view.rows[i].id=="story_letter":view.cursor=i
	var before: Dictionary=app.rules.state.duplicate(true)
	await press(JOY_BUTTON_A)
	expect(view.reading and "RB" in view.hint.text,"detail exposes successor control")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	expect(not view.reading and view.related_from=="story_letter","RB opens successor list")
	expect(view.rows.size()>1,"branch alternatives preserved")
	for row in view.rows:expect("story_letter" in EditionRules.Story.quest(row.id).requires,"only direct successors listed")
	for i in range(view.rows.size()):
		if view.rows[i].id=="story_apprentice_book":view.cursor=i
	await press(JOY_BUTTON_A)
	expect(view.reading and view.rows[view.cursor].id=="story_apprentice_book","open foreign NPC successor")
	await press(JOY_BUTTON_A)
	expect(app.rules.state==before,"viewing or attempting foreign task never accepts remotely")
	expect("人物" in app.pending_message,"wrong NPC gives guidance")
	await press(JOY_BUTTON_B)
	expect(not view.reading and view.related_from=="story_letter","B returns to branch list")
	await press(JOY_BUTTON_B)
	expect(view.reading and view.rows[view.cursor].id=="story_letter" and view.related_from.is_empty(),"B restores parent detail")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	expect(view.prerequisites and view.rows.size()==1 and view.rows[0].id=="nv_patrol","LB exposes legacy novice prerequisite")
	await press(JOY_BUTTON_A)
	expect(view.reading and view.rows[view.cursor].novice,"legacy prerequisite detail opens")
	await press(JOY_BUTTON_A)
	expect(app.rules.state==before and "村长" in app.pending_message,"legacy task cannot be operated at foreign NPC")
	await press(JOY_BUTTON_B);await press(JOY_BUTTON_B)
	expect(view.reading and not view.prerequisites and view.rows[view.cursor].id=="story_letter","return restores prior navigation mode")
	expect(app.rules.state==before,"navigation leaves gameplay unchanged")
	await press(JOY_BUTTON_B);await press(JOY_BUTTON_B)
	expect(not app.windows.windows.has("手柄人物委托"),"B closes after returning to NPC list")
	var report:={"checks":checks,"failures":failures,"scope":"joypad events via viewport, real NPC map, branch navigation and foreign NPC refusal; cursor selection and travel are fixtures, no hardware test"}
	FileAccess.open("res://../artifacts/world-story/controller-successors-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
