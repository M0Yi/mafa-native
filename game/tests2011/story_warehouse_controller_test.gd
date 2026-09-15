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
	for i in range(6):await process_frame
func press(key: int) -> void:
	var e:=InputEventJoypadButton.new();e.button_index=key;e.pressed=true;root.push_input(e,true);await settle()
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/warehouse-controller-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"keeper","name":"仓储操作","gender":"男","job":"战士"})
	var quest_id:=OS.get_environment("MAFA_WAREHOUSE_QUEST")
	if quest_id.is_empty():quest_id="story_seal_warehouse_practice"
	var q: Dictionary=Story.quest(quest_id)
	var npc: Dictionary=app.rules.story_npc(q.start_npc)
	var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN
	app.enter_map(npc.map,at);app.world.paused=false;app.save_world()
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.requires[0]]="done"
	expect(app.rules.apply(next,"prerequisite_fixture"),"prerequisite fixture")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"accept fixture")
	app.controller_interact(npc);await settle();await press(JOY_BUTTON_Y)
	var target: Button=null
	for b in app.panel.navigation_buttons(app.panel.body):
		if b.text=="手柄仓库存取":target=b
	expect(target!=null,"NPC services offer dedicated controller storage")
	if target!=null:
		for i in range(20):
			if root.gui_get_focus_owner()==target:break
			await press(JOY_BUTTON_DPAD_DOWN)
		expect(root.gui_get_focus_owner()==target,"dpad selects storage service")
		await press(JOY_BUTTON_A)
	expect(app.windows.windows.has("手柄仓库"),"A opens dedicated storage")
	if app.windows.windows.has("手柄仓库"):
		var view=app.form.get_child(1)
		expect(Story.progress(app.rules.state,q,0)==0,"opening does not transfer items")
		for i in range(view.rows.size()):
			if view.rows[view.cursor].type=="potion":break
			await press(JOY_BUTTON_DPAD_DOWN)
		var uid: String=view.rows[view.cursor].uid
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;");await press(JOY_BUTTON_A)
		expect(app.rules.state==before and not view.result.text.is_empty(),"failed deposit is visible and preserves state")
		app.store.db.query("PRAGMA query_only=OFF;");await press(JOY_BUTTON_A)
		expect(EditionInventory.find_item(app.rules.state,uid).container=="warehouse" and Story.progress(app.rules.state,q,0)==1,"A retries deposit")
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		expect(view.page==1 and view.rows.size()==1,"RB switches to warehouse")
		before=app.rules.state.duplicate(true);app.world.player.cell+=Vector2i(20,0);await press(JOY_BUTTON_A)
		expect(app.rules.state==before and "身边" in view.result.text,"distance blocks stale panel")
		app.world.player.reset(at);app.world.paused=true;await press(JOY_BUTTON_A)
		expect(app.rules.state==before,"pause blocks transfer")
		app.world.paused=false;await press(JOY_BUTTON_A)
		expect(EditionInventory.find_item(app.rules.state,uid).container=="inventory" and Story.ready(app.rules.state,q),"A withdraw completes task")
		expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(app.panel.get_global_rect()),"panel fits 800x600")
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://../artifacts/world-story/warehouse-controller.png")
		await press(JOY_BUTTON_B);expect(not app.windows.windows.has("手柄仓库"),"B closes storage")
	var report:={"checks":checks,"failures":failures,"scope":"native joypad events from NPC services through actual inventory transactions; initial map, acceptance and prerequisites are fixtures, not hardware controller acceptance"}
	FileAccess.open("res://../artifacts/world-story/warehouse-controller-"+quest_id+"-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	var fixture: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		if FileAccess.file_exists(fixture+suffix) and DirAccess.remove_absolute(fixture+suffix)!=OK:failures.append("fixture cleanup failed")
	quit(0 if failures.is_empty() else 1)
