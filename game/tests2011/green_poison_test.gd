extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/green-poison-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(5):await process_frame
	app.set_process(false);app.start_character({"id":"poison","name":"绿毒检查","gender":"男","job":"战士"})
	var next: Dictionary=app.rules.state.duplicate(true);next.hp=500;app.rules.apply(next,"health_fixture")
	expect(app.rules.receive_damage(10,true,10),"damage and poison applied together")
	expect(app.rules.state.hp==490 and app.rules.state.green_poison.until==70 and app.rules.state.green_poison.next==11,"poison timing initialized")
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.tick_green_poison(10.99) and app.rules.state==before,"no early tick")
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.tick_green_poison(11) and app.rules.state==before,"write failure preserves HP and tick cursor")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.tick_green_poison(11) and app.rules.state.hp==487,"retry settles exactly one tick")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.tick_green_poison(11) and app.rules.state==before,"same instant cannot repeat")
	app.world.paused=true;app.elapsed=12;app.gameplay.update(1)
	expect(app.rules.state==before,"pause prevents poison settlement")
	app.world.paused=false
	app.rules.state=app.store.load_world(app.rules.character.id)
	expect(not app.rules.tick_green_poison(11),"reload cursor prevents repeated tick")
	expect(app.rules.tick_green_poison(70) and app.rules.state.hp==313 and not app.rules.state.has("green_poison"),"catchup counts 59 total ticks before expiration")
	for fps in [30,60,120]:
		next=app.rules.state.duplicate(true);next.hp=100;next.green_poison={"until":104.0,"next":101.0,"power":3};app.rules.apply(next,"timing_fixture")
		for frame in range(fps*4+1):app.rules.tick_green_poison(100.0+float(frame)/fps)
		expect(app.rules.state.hp==91 and not app.rules.state.has("green_poison"),"same duration damage at "+str(fps)+" FPS")
	next=app.rules.state.duplicate(true);next.hp=2;next.green_poison={"until":210.0,"next":201.0,"power":3};app.rules.apply(next,"lethal_fixture")
	app.elapsed=201;app.gameplay.update(0)
	expect(app.rules.state.hp==0 and not app.rules.state.has("green_poison"),"poison death clears status")
	expect(app.gameplay.death_layer!=null,"poison death enters normal death panel")
	next=app.rules.state.duplicate(true);next.hp=100;app.rules.apply(next,"alive_again_fixture");app.gameplay.clear_death();app.world.paused=false;app.elapsed=300
	var traveler: Dictionary={"id":"poison-ally","kind":"traveler","name":"青禾","hp":250,"generation":0,"cell":[app.world.player.cell.x+1,app.world.player.cell.y],"ac":0}
	app.world.entities=[traveler]
	app.gameplay.hit_traveler(traveler,{"damage":10,"green_poison":true})
	expect(traveler.hp==240 and app.rules.state.traveler_health[traveler.id].green_poison.next==301,"traveler damage and poison committed together")
	app.gameplay.hit_traveler(traveler,{"damage":1})
	expect(app.rules.state.traveler_health[traveler.id].has("green_poison"),"ordinary hit preserves poison")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.tick_traveler_poison(301) and app.rules.state==before and traveler.hp==239,"traveler failed tick preserves persisted and scene health")
	app.store.db.query("PRAGMA query_only=OFF;");app.elapsed=301;app.gameplay.update(0)
	expect(traveler.hp==236 and app.rules.state.traveler_health[traveler.id].hp==236,"successful tick updates live traveler after commit")
	before=app.rules.state.duplicate(true);app.gameplay.update(0)
	expect(app.rules.state==before,"same game time cannot double poison ally")
	app.world.paused=true;app.elapsed=302;app.gameplay.update(1)
	expect(app.rules.state==before,"pause freezes ally poison")
	app.world.paused=false;app.rules.state=app.store.load_world(app.rules.character.id)
	expect(not app.rules.tick_traveler_poison(301),"reloaded ally cursor does not duplicate damage")
	next=app.rules.state.duplicate(true);next.traveler_health[traveler.id].hp=2;app.rules.apply(next,"lethal_ally_fixture");traveler.hp=2
	app.gameplay.update(0)
	expect(traveler.hp==0 and traveler.motion=="die" and traveler.generation==1,"ally poison death syncs once to scene")
	expect(not app.rules.state.traveler_health[traveler.id].has("green_poison") and app.rules.state.traveler_health[traveler.id].respawn==332,"ally poison death clears status and schedules recovery")
	expect(app.rules.recover_travelers([traveler.id],332) and app.rules.state.traveler_health[traveler.id].hp==250,"ally recovers without old poison")
	if failures.is_empty():print("PASS: green_poison_test completed without failures")
	DirAccess.make_dir_recursive_absolute("res://../artifacts/world-story")
	var test_path:String=app.store.path
	var report:={"checks":checks,"failures":failures,"scope":"atomic poison application, tick rollback/retry/reload, pause, deterministic 30/60/120 timing, expiration and death UI; duration/damage are documented singleplayer baseline, traveler poison application/preservation/rollback/reload/death/recovery covered; natural chance and full journey unverified"}
	FileAccess.open("res://../artifacts/world-story/green-poison-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		var file_path:String=test_path+suffix
		if FileAccess.file_exists(file_path) and DirAccess.remove_absolute(file_path)!=OK:
			printerr("Cannot remove test database: "+file_path);quit(1);return
	print("TEST_DATABASE_REMOVED ",test_path)
	quit(0 if failures.is_empty() else 1)
