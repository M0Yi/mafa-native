extends SceneTree
var app
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	if not ok:failures.append(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func press(key: int) -> void:
	var e:=InputEventJoypadButton.new();e.button_index=key;e.pressed=true;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/mafa-controller-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	app.start_character({"id":"controller","name":"手柄验收","gender":"男","job":"战士"});app.world.paused=false
	app.show_bag();await settle();expect(app.windows.windows.has("冒险面板"),"mouse bag entry remains")
	await press(JOY_BUTTON_BACK);expect(app.windows.windows.has("手柄操作"),"separate controller entry")
	var view=app.form.get_child(1);var count: int=app.rules.state.inventory.potion
	await press(JOY_BUTTON_Y);expect(app.rules.state.quickbar[0]=="potion" and app.rules.state.inventory.potion==count,"controller binding preserves stack")
	var selected_uid: String=view.rows[view.cursor].uid
	var next: Dictionary=app.rules.state.duplicate(true)
	EditionInventory.find_item(next,selected_uid).count-=1;EditionInventory.mirror(next)
	expect(app.rules.apply(next,"external_inventory_fixture"),"external inventory update")
	await settle()
	expect(view.rows[view.cursor].uid==selected_uid and view.list.get_item_text(view.cursor).ends_with("×"+str(count-1)),"live count refresh preserves selected instance")
	await press(JOY_BUTTON_RIGHT_SHOULDER);expect(view.page==1,"equipment page")
	await press(JOY_BUTTON_LEFT_SHOULDER);expect(view.page==0,"inventory page")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/controller-panel/panel.png")
	var quest_id: String=EditionRules.Story.data().quests[0].id
	next=app.rules.state.duplicate(true);next.quests[quest_id]="accepted"
	expect(app.rules.apply(next,"accepted_story_fixture"),"prepare accepted story")
	await press(JOY_BUTTON_RIGHT_SHOULDER);await press(JOY_BUTTON_RIGHT_SHOULDER);await press(JOY_BUTTON_RIGHT_SHOULDER)
	expect(view.page==3 and view.rows.any(func(row):return row.get("quest")==quest_id),"controller lists accepted story")
	next=app.rules.state.duplicate(true);next.quests[quest_id]="done"
	expect(app.rules.apply(next,"external_story_completion_fixture"),"external story completion")
	await settle()
	expect(not view.rows.any(func(row):return row.get("quest")==quest_id),"completed story disappears without reopening controller")
	expect(view.rows.is_empty() and "没有已接受" in view.detail.text,"empty task page replaces stale description")
	await press(JOY_BUTTON_B);expect(not app.windows.windows.has("手柄操作") and app.windows.windows.has("冒险面板"),"controller close preserves mouse menu")
	var e:=InputEventKey.new();e.keycode=KEY_B;e.physical_keycode=KEY_B;e.pressed=true;root.push_input(e,true);await settle();expect(not app.windows.windows.has("冒险面板"),"B toggles mouse bag closed")
	print(JSON.stringify({"failures":failures}));FileAccess.open("res://../artifacts/controller-panel/tests.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures},"  "))
	var fixture_path: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		var file: String=fixture_path+suffix
		if FileAccess.file_exists(file) and DirAccess.remove_absolute(file)!=OK:failures.append("Cannot clean test database: "+file)
	quit(0 if failures.is_empty() else 1)
