extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/world-story"))!=OK:
		printerr("无法创建测试报告目录");quit(1);return
	call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func text_of(node: Node) -> String:
	var text: String=node.text if node is Label else ""
	for child in node.get_children():text+="\n"+text_of(child)
	return text
func button(title: String) -> Button:
	for control in app.panel.navigation_buttons(app.form):
		if control.text==title:return control
	return null
func press(key: int) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=key;event.pressed=true;root.push_input(event,true);await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/guild-log-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"log","name":"救助记录","gender":"男","job":"战士"});app.world.paused=false
	app.rules.social("guild","云游客");app.rules.social("party","云游客")
	app.show_guild_aid_log();await settle();expect("尚无成功救助记录" in text_of(app.form),"empty history explained")
	var traveler: Dictionary=app.world.entities.filter(func(e):return e.kind=="traveler" and e.name=="云游客")[0]
	traveler.cell=[app.world.player.cell.x+1,app.world.player.cell.y]
	for amount in range(1,7):
		var next: Dictionary=app.rules.state.duplicate(true);next.guild.supplies={"potion":10};next.traveler_health={traveler.id:{"hp":250-amount,"generation":0,"respawn":0}};app.rules.apply(next,"wound_stock_fixture")
		expect(app.rules.guild_aid(traveler,app.world.metadata.id,app.world.player.cell),"real ledger entry created")
	var before: Dictionary=app.rules.state.duplicate(true)
	app.show_guild_aid_log();await settle()
	expect("第 1/2 页" in text_of(app.form) and "实际恢复 6 点" in text_of(app.form) and "实际恢复 1 点" not in text_of(app.form),"newest four entries on first page")
	await press(JOY_BUTTON_DPAD_DOWN);await press(JOY_BUTTON_A)
	expect("第 2/2 页" in text_of(app.form) and "实际恢复 1 点" in text_of(app.form),"controller advances to older page")
	await press(JOY_BUTTON_DPAD_DOWN);await press(JOY_BUTTON_A)
	expect("第 1/2 页" in text_of(app.form),"controller returns to newest page")
	expect(app.rules.state==before,"browsing does not repeat healing or consumption")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/world-story/guild-log-ui.png")
	await press(JOY_BUTTON_B);expect(not app.windows.windows.has("行会救助记录"),"B closes history")
	var report:={"display_backend":DisplayServer.get_name(),"physical_input":false,"capture_enabled":DisplayServer.get_name()!="headless","checks":checks,"failures":failures,"scope":"actual aid-created records with controlled wounds, controller pagination and no mutation; full combat untested"}
	FileAccess.open("res://../artifacts/world-story/guild-log-ui-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));await cleanup_test_store();quit(0 if failures.is_empty() else 1)

func cleanup_test_store() -> void:
	var path: String=app.store.path
	var pattern:=RegEx.new()
	pattern.compile("^/tmp/guild-log-ui-[0-9a-f]{16}\\.sqlite$")
	assert(pattern.search(path)!=null,"refuse cleanup outside this test's random database")
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		if FileAccess.file_exists(path+suffix):assert(DirAccess.remove_absolute(path+suffix)==OK)
	print("PASS: own temporary database cleaned: ",path)
