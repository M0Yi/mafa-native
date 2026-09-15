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
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/atomic-door-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"atomic","name":"跨门事务","gender":"男","job":"战士"});app.world.paused=false
	var route: Dictionary=app.resources.connections.by_map["d2081"].filter(func(r):return r.target_map=="d2082")[0]
	var door:=Vector2i(route.cell[0],route.cell[1]);app.enter_map(route.map,door);app.rules.save_location(route.map,door,app.elapsed)
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_leiyan_depths="accepted";next.tracked_story="story_leiyan_depths";app.rules.apply(next,"accepted_fixture")
	var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("CREATE TEMP TRIGGER fail_door BEFORE INSERT ON operations WHEN NEW.action='save_location' BEGIN SELECT RAISE(ABORT, 'door failure'); END;")
	expect(not app.cross_passage(route),"final door save refused")
	expect(app.rules.state==before,"failed door leaves no in-memory visit commit")
	var saved: Dictionary=app.store.load_world(app.rules.character.id)
	var serialized: Dictionary=JSON.parse_string(JSON.stringify(before))
	expect(JSON.parse_string(JSON.stringify(saved))==serialized,"failed door leaves no persisted visit commit")
	expect(app.world.metadata.id==route.map and app.world.player.cell==door,"failed door restores exact origin")
	app.store.db.query("DROP TRIGGER fail_door;")
	expect(app.cross_passage(route),"door retry succeeds")
	expect(app.rules.state.map=="d2082" and Story.progress(app.rules.state,Story.quest("story_leiyan_depths"),0)==1,"door location and visit committed together")
	var report:={"checks":checks,"failures":failures,"scope":"actual door and landing, selective final-commit failure, full persisted state comparison and retry; accepted quest and initial doorway placement are fixtures"}
	FileAccess.open("res://../artifacts/world-story/atomic-door-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
