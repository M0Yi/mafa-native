extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
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
func reload_scene() -> void:
	var path: String=app.store.path
	app.queue_free();await settle()
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path=path
	root.add_child(app);await settle()
	app.start_character({"id":"tracker","name":"追踪验收","gender":"男","job":"战士"});app.world.paused=true;await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-tracker-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	app.start_character({"id":"tracker","name":"追踪验收","gender":"男","job":"战士"});app.world.paused=true
	expect(Story.tracked(app.rules.state).is_empty(),"old save default does not need migration")
	await settle()
	expect(app.world.task_markers.get("border:elder")=="可接取","fresh village shows available task marker")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/world-story/npc-markers.png")
	var witness: Dictionary=app.rules.state.duplicate(true)
	witness.quests.story_island_shops="accepted"
	witness.quests.story_home_repair="accepted"
	expect(Story.npc_markers(witness).get("server:merchant:32")=="任务服务","pending repair marks service NPC")
	expect(Story.npc_markers(witness).get("server:merchant:144")=="任务见闻","pending witness is marked")
	witness.story_progress={"story_island_shops":{"0":1,"1":1}}
	expect(not Story.npc_markers(witness).has("server:merchant:144") and Story.npc_markers(witness).get("server:merchant:153")=="可交付","recorded witnesses clear and recipient becomes ready")

	expect(not app.rules.track_story("story_mine"),"cannot track unaccepted quest")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_supplies="done";app.rules.apply(next,"prerequisite_fixture")
	var npc: Dictionary=app.rules.story_npc("server:merchant:4");var cell:=Vector2i(npc.cell[0],npc.cell[1])
	expect(app.rules.story_action("story_woma","accept",npc.id,npc.map,cell),"first quest accepted")
	expect(Story.tracked(app.rules.state).id=="story_woma","first quest automatically tracked")
	expect(app.rules.story_action("story_mine","accept",npc.id,npc.map,cell),"second quest accepted")
	expect(Story.tracked(app.rules.state).id=="story_woma","second quest does not steal tracking")
	expect(app.rules.track_story("story_mine"),"explicit tracking selection")
	expect(Story.tracked(app.store.load_world(app.rules.character.id)).id=="story_mine","selection persists")
	var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.track_story("story_woma") and app.rules.state==before,"failed tracking save leaves original")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(Story.next_objective(app.rules.state,Story.quest("story_mine")).map=="d401","tracker selects unmet objective")
	expect(app.rules.save_location("d401",Vector2i(1,1),0.0),"visit objective fixture")
	expect("返回交付" in Story.tracker_text(app.rules.state),"ready task changes instruction")
	await settle()
	expect(app.world.task_markers.get(npc.id)=="可交付","committed progress refreshes world marker")
	var gold: int=app.rules.state.gold
	await reload_scene()
	expect(Story.tracked(app.rules.state).get("id")=="story_mine","fresh scene restores tracked task")
	expect(Story.ready(app.rules.state,Story.quest("story_mine")) and "返回交付" in Story.tracker_text(app.rules.state),"fresh scene restores ready-to-submit instruction")
	expect(app.rules.state.gold==gold and app.rules.state.quests.story_mine=="accepted","reload never grants pending reward")

	await settle()
	expect(app.classic_hud.quest_tracker.get_global_rect().end.x<=800,"tracker fits minimum screen")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/world-story/tracker.png")
	expect(app.rules.story_action("story_mine","submit",npc.id,npc.map,cell),"submit tracked task")
	expect(Story.tracked(app.rules.state).is_empty(),"completed tracked task clears selection")
	gold=app.rules.state.gold
	await reload_scene()
	expect(Story.tracked(app.rules.state).is_empty() and app.rules.state.quests.story_mine=="done","fresh scene retains completed task without stale tracking")
	expect(app.rules.state.gold==gold,"completed reload does not duplicate reward")

	expect(not app.rules.track_story("story_mine"),"completed task cannot be tracked")
	expect(app.rules.track_story("story_woma") and app.rules.track_story(""),"can cancel tracked task")
	expect(Story.tracked(app.store.load_world(app.rules.character.id)).is_empty(),"cancel persists")
	app.world.paused=false;app.show_controller_panel();await settle()
	var controller=app.form.get_child(1)
	var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_LEFT_SHOULDER;event.pressed=true;root.push_input(event,true);await settle()
	expect(controller.page==3 and controller.rows.size()==1,"controller independent story list")
	event=event.duplicate();event.button_index=JOY_BUTTON_A;root.push_input(event,true);await settle()
	expect(Story.tracked(app.rules.state).id=="story_woma","controller A tracks selected quest")
	event=event.duplicate();event.button_index=JOY_BUTTON_Y;root.push_input(event,true);await settle()
	expect(Story.tracked(app.rules.state).is_empty(),"controller Y cancels selected tracking")
	var report:={"display_backend":DisplayServer.get_name(),"physical_input":false,"capture_enabled":DisplayServer.get_name()!="headless","checks":checks,"failures":failures,"scope":"tracking selection, persistence, completion transition and HUD bounds; map visit is a fixture"}
	FileAccess.open("res://../artifacts/world-story/tracker-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));await cleanup_test_store();quit(0 if failures.is_empty() else 1)

func cleanup_test_store() -> void:
	var path: String=app.store.path
	var pattern:=RegEx.new()
	pattern.compile("^/tmp/story-tracker-[0-9a-f]{16}\\.sqlite$")
	assert(pattern.search(path)!=null,"refuse cleanup outside this test's random database")
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		if FileAccess.file_exists(path+suffix):assert(DirAccess.remove_absolute(path+suffix)==OK)
	print("PASS: own temporary database cleaned: ",path)
