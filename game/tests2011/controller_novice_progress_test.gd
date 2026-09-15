extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func press(button: int) -> void:
	for down in [true,false]:
		var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=down;root.push_input(e,true);await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/controller-novice-progress-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"pad-progress","name":"村庄进度","job":"战士","gender":"男"});app.world.hide()
	var prepared: Dictionary=app.rules.state.duplicate(true)
	prepared.quests={"nv_arrival":"done","nv_equip":"done","nv_hunt":"accepted"};prepared.novice={"chickens":0,"patrol":false}
	expect(app.rules.apply(prepared,"prior_task_fixture"),"prepare hunting task")
	app.show_controller_story(app.rules.story_npc("border:elder"));await settle()
	var view=app.form.get_child(1)
	for i in range(view.rows.size()):
		if view.rows[i].id=="nv_hunt":view.cursor=i;view.list.select(i);break
	await press(JOY_BUTTON_A)
	expect(view.reading and "鸡肉 0/3" in view.text.text,"A opens current novice progress")
	for i in range(3):expect(app.rules.reward_kill("pad-chicken-"+str(i),"village_chicken"),"prepared kill event")
	await settle()
	expect("击败鸡 3/3 · 鸡肉 0/3" in view.text.text,"detail updates kill count live")
	for loot in app.rules.state.ground_loot.duplicate(true):
		if loot.type=="chicken_meat":expect(app.rules.pickup(loot.uid,"0",EditionVillage.SPAWN),"actual ground pickup")
	await settle()
	expect("可以交付 · 返回边界村长" in view.text.text and not "鸡肉 0/3" in view.text.text,"detail replaces stale progress after pickup")
	await press(JOY_BUTTON_B)
	var index: int=view.cursor
	expect(not view.reading and "可以交付" in view.list.get_item_text(index),"B returns to current ready task")
	expect(app.rules.warehouse("chicken_meat",true),"store required meat")
	await settle()
	expect(view.cursor==index and "鸡肉 2/3" in view.list.get_item_text(index),"list updates without changing selection")
	expect(app.rules.warehouse("chicken_meat",false),"retrieve meat")
	await settle()
	expect("可以交付" in view.list.get_item_text(index),"list becomes ready without reopening")
	await press(JOY_BUTTON_A);await press(JOY_BUTTON_A)
	expect(app.rules.state.quests.nv_hunt=="done","A submits at actual elder location")
	var report:={"checks":checks,"failures":failures,"scope":"joypad events open/back/submit plus live list and detail after rule-level kill/warehouse and actual pickup; prior task fixture, no physical controller or natural combat"}
	FileAccess.open("res://../artifacts/world-story/controller-novice-progress-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));var fixture_path: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		var file: String=fixture_path+suffix
		if FileAccess.file_exists(file) and DirAccess.remove_absolute(file)!=OK:failures.append("Cannot clean test database: "+file)
	quit(0 if failures.is_empty() else 1)
