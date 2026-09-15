extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/traveler-recovery-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"recovery","name":"同行恢复","gender":"男","job":"战士"});app.world.paused=false;app.elapsed=0
	var traveler: Dictionary=app.world.entities.filter(func(e):return e.kind=="traveler")[0]
	app.gameplay.hit_traveler(traveler,{"damage":1000})
	expect(traveler.hp==0 and app.rules.state.traveler_health[traveler.id].hp==0,"actual damage records death")
	app.elapsed=29.9;app.gameplay.sync_travelers();expect(traveler.hp==0,"no early recovery")
	app.elapsed=30;app.world.paused=true;app.gameplay.sync_travelers();expect(traveler.hp==0,"paused world does not recover")
	app.world.paused=false;var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;");app.gameplay.sync_travelers()
	expect(traveler.hp==0 and app.rules.state==before,"failed recovery leaves actor and state dead")
	app.store.db.query("PRAGMA query_only=OFF;");app.gameplay.sync_travelers()
	expect(traveler.hp==250 and traveler.motion=="stand","retry restores life and standing motion")
	var saved: Dictionary=app.store.load_world(app.rules.character.id)
	expect(saved.traveler_health[traveler.id].hp==250 and saved.traveler_health[traveler.id].respawn==0 and saved.time>=30,"recovery and world time persisted")
	var revision: int=app.rules.state.revision;app.gameplay.sync_travelers()
	expect(app.rules.state.revision==revision,"synchronizing live travelers does not write again")
	app.gameplay.hit_traveler(traveler,{"damage":10});expect(app.rules.state.traveler_health[traveler.id].hp==240,"recovered traveler can take new damage correctly")
	app.rules.character.job="道士"
	traveler.cell=[app.world.player.cell.x,app.world.player.cell.y]
	app.gameplay.hit_traveler(traveler,{"damage":1,"green_poison":true,"stone":true})
	var prepared:Dictionary=app.rules.state.duplicate(true)
	prepared.level=40;prepared.mp=100;prepared.party=[str(traveler.name)]
	prepared.skills.groupheal={"rank":1,"proficiency":0}
	expect(app.rules.apply(prepared,"test_groupheal_fixture"),"groupheal fixture saved")
	var health_before:Dictionary=app.rules.state.traveler_health[traveler.id].duplicate(true)
	var state_before:Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.gameplay.cast("groupheal") and app.rules.state==state_before,"failed groupheal preserves mana and health status")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.gameplay.cast("groupheal"),"groupheal retries after failed save")
	var expected:Dictionary=health_before.duplicate(true);expected.hp=250
	expect(app.rules.state.traveler_health[traveler.id]==expected,"healing preserves poison, stone, name and generation")
	app.gameplay.sync_travelers()
	expect(traveler.hp==250 and traveler.green_poison==health_before.green_poison and traveler.stone_until==health_before.stone_until,"healed entity restores committed status")
	expect(app.store.load_world(app.rules.character.id).traveler_health[traveler.id]==JSON.parse_string(JSON.stringify(expected)),"healing status survives database reload")
	traveler.ac=20;traveler.mac=3
	for hit in [{"damage":30},{"damage":30,"skill":"flame"},{"damage":30,"skill":"fireball"},{"damage":30,"skill":"talisman"},{"damage":30,"magic_attack":true}]:
		var hp_before:int=traveler.hp
		app.gameplay.hit_traveler(traveler,hit)
		var wanted:int=10 if hit.get("skill","") in ["","flame"] and not hit.get("magic_attack",false) else 27
		expect(traveler.hp==hp_before-wanted,"correct physical/magic defense for "+JSON.stringify(hit))
	app.elapsed=40
	app.gameplay.hit_traveler(traveler,{"damage":1,"skill":"poison"})
	expect(traveler.green_poison.until==50 and traveler.green_poison.next==41.5,"player poison establishes ten-second skill status")
	var poisoned_hp:int=traveler.hp
	expect(not app.rules.tick_traveler_poison(41.49),"skill poison waits full interval")
	expect(app.rules.tick_traveler_poison(41.5),"skill poison ticks at 1.5 seconds")
	expect(app.rules.state.traveler_health[traveler.id].hp==poisoned_hp-8,"skill poison uses existing level and magic defense rule")
	var tick_revision:int=app.rules.state.revision
	expect(not app.rules.tick_traveler_poison(41.5) and app.rules.state.revision==tick_revision,"same poison instant cannot apply twice")
	if failures.is_empty():print("PASS: traveler_recovery_test completed without failures")
	DirAccess.make_dir_recursive_absolute("res://../artifacts/world-story")
	var test_path:String=app.store.path
	var report:={"checks":checks,"failures":failures,"scope":"actual traveler damage, world-time boundary and pause, selective database failure/retry, persistence and repeat sync; time advanced by fixture"}
	FileAccess.open("res://../artifacts/world-story/traveler-recovery-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		var file_path:String=test_path+suffix
		if FileAccess.file_exists(file_path) and DirAccess.remove_absolute(file_path)!=OK:
			printerr("Cannot remove test database: "+file_path);quit(1);return
	print("TEST_DATABASE_REMOVED ",test_path)
	quit(0 if failures.is_empty() else 1)
