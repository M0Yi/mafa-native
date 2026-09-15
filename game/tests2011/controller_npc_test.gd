extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/world-story"))!=OK:
		printerr("无法创建测试报告目录");quit(1);return
	call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func press(button: int) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=true;root.push_input(event,true);await settle()
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/controller-npc-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	app.start_character({"id":"controller-npc","name":"委托验收","gender":"男","job":"战士"});app.world.paused=false
	# Let the entry/HUD node transition finish before injecting the first game input.
	await settle()
	var elder: Dictionary={}
	for entity in app.world.entities:
		if entity.id=="border:elder":elder=entity
	expect(not elder.is_empty(),"live elder exists")
	print(JSON.stringify({"input_probe":{"cell":str(app.world.player.cell),"elder":elder.get("cell",[]),"paused":app.world.paused,"mode":app.mode,"windows":app.windows.order,"focus":str(root.gui_get_focus_owner())}}))
	await press(JOY_BUTTON_A)
	expect(not app.windows.order.is_empty() and app.windows.order.back()=="手柄人物委托","controller opens nearby elder task menu")
	if not app.windows.windows.has("手柄人物委托"):
		printerr("NPC input failed: ",app.pending_message);await cleanup_test_store();quit(1);return
	var view=app.form.get_child(1)
	expect(view.rows[0].id=="nv_arrival","novice tasks precede story list")
	await press(JOY_BUTTON_A)
	expect(view.reading and not app.rules.state.quests.has("nv_arrival"),"detail first, no accidental accept")
	await press(JOY_BUTTON_A)
	expect(app.rules.state.quests.get("nv_arrival")=="accepted","A accepts novice task")
	await press(JOY_BUTTON_A)
	var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;");await press(JOY_BUTTON_A)
	expect(app.rules.state==before and view.reading,"failed reward transaction remains retryable")
	app.store.db.query("PRAGMA query_only=OFF;");await press(JOY_BUTTON_A)
	expect(app.rules.state.quests.get("nv_arrival")=="done","retry completes novice task")
	var gold: int=app.rules.state.gold
	await press(JOY_BUTTON_A);await press(JOY_BUTTON_A)
	expect(app.rules.state.gold==gold,"repeat submit cannot duplicate reward")
	# Successful operations refresh the task list; explicitly open detail before testing Back.
	if not view.reading:await press(JOY_BUTTON_A)
	expect(view.reading,"detail is open before testing B")
	await press(JOY_BUTTON_B)
	expect(is_instance_valid(view) and not view.reading,"B returns to list")
	await press(JOY_BUTTON_Y)
	expect(not app.windows.windows.has("手柄人物委托") and not app.windows.order.is_empty(),"original NPC services remain accessible")
	app.windows.close_all()
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.nv_patrol="done";app.rules.apply(next,"story_prerequisite_fixture")
	app.controller_interact(elder);await settle();view=app.form.get_child(1)
	for i in range(view.rows.size()):
		if view.rows[i].id=="story_letter":view.cursor=i
	await press(JOY_BUTTON_A);await press(JOY_BUTTON_A)
	expect(app.rules.state.quests.get("story_letter")=="accepted","controller accepts story quest")
	await press(JOY_BUTTON_A)
	app.world.player.cell+=Vector2i(20,20);before=app.rules.state.duplicate(true)
	await press(JOY_BUTTON_A)
	expect(app.rules.state==before,"stale task panel refuses distant operation")
	app.world.paused=true
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/world-story/controller-npc.png")
	expect(view.get_global_rect().end.x<=800 and view.get_global_rect().end.y<=600,"detail fits minimum viewport")
	await press(JOY_BUTTON_B);await press(JOY_BUTTON_B)
	expect(not app.windows.windows.has("手柄人物委托"),"B closes task panel")
	app.world.paused=false
	var recipient: Dictionary=app.rules.story_npc("server:merchant:4")
	expect(app.enter_map(recipient.map,Vector2i(recipient.cell[0],recipient.cell[1])+Vector2i(1,0)),"load actual story recipient")
	var live: Dictionary={}
	for entity in app.world.entities:
		if entity.id==recipient.id:live=entity
	expect(not live.is_empty(),"recipient runtime entity exists")
	app.controller_interact(live);await settle();view=app.form.get_child(1)
	for i in range(view.rows.size()):
		if view.rows[i].id=="story_letter":view.cursor=i
	await press(JOY_BUTTON_A);await press(JOY_BUTTON_A)
	expect(app.rules.state.quests.get("story_letter")=="done","controller submits at correct recipient")
	expect(app.store.load_world(app.rules.character.id).quests.get("story_letter")=="done","controller story completion persists")
	gold=app.rules.state.gold;await press(JOY_BUTTON_A);await press(JOY_BUTTON_A)
	expect(app.rules.state.gold==gold,"story duplicate submission rejected")
	app.windows.close_all()
	var plain: Dictionary={}
	for entity in app.world.entities:
		if entity.get("kind")=="npc" and app.rules.story_npc(entity.id).is_empty():plain=entity;break
	if not plain.is_empty():
		app.world.player.cell=Vector2i(plain.cell[0],plain.cell[1])+Vector2i(1,0)
		app.controller_interact(plain);await settle()
		expect(not app.windows.order.is_empty(),"NPC without story registry retains interaction")
	var report:={"display_backend":DisplayServer.get_name(),"physical_input":false,"capture_enabled":DisplayServer.get_name()!="headless","checks":checks,"failures":failures,"scope":"injected joypad events, novice reward retry, story accept, distance guard and original service access; prerequisites are fixtures, not a hardware controller playthrough"}
	FileAccess.open("res://../artifacts/world-story/controller-npc-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));await cleanup_test_store();quit(0 if failures.is_empty() else 1)

func cleanup_test_store() -> void:
	var path: String=app.store.path
	var pattern:=RegEx.new()
	pattern.compile("^/tmp/controller-npc-[0-9a-f]{16}\\.sqlite$")
	assert(pattern.search(path)!=null,"refuse cleanup outside this test's random database")
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		if FileAccess.file_exists(path+suffix):assert(DirAccess.remove_absolute(path+suffix)==OK)
	print("PASS: own temporary database cleaned: ",path)
