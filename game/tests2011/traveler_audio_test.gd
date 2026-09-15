extends SceneTree
var app
var checks:=0
var failures: Array=[]
var sounds: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func settle() -> void:
	for i in range(5):await process_frame
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/traveler-audio-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"traveler-audio","name":"同行声音","gender":"男","job":"战士"});app.world.paused=false
	app.sound_started.connect(func(id):sounds.append(id))
	for gender in ["男","女"]:
		app.elapsed=0;app.world.elapsed=0
		var entity: Dictionary=app.world.entities.filter(func(e):return e.kind=="traveler" and e.gender==gender)[0]
		app.world.player.reset(Vector2i(entity.cell[0]+1,entity.cell[1]))
		var hurt:=138 if gender=="男" else 139
		var die:=144 if gender=="男" else 145
		check(app.resources.sound_id(hurt)!=null and app.resources.sound_id(die)!=null,"gender voice assets exist")
		sounds.clear();app.gameplay.hit_traveler(entity,{"damage":10})
		check(sounds==[hurt] and entity.motion=="hurt","nonlethal hit voice")
		check(entity.respawn==0,"live traveler has no revival deadline")
		var before: Dictionary=app.rules.state.duplicate(true)
		sounds.clear();app.store.db.query("PRAGMA query_only=ON;");app.gameplay.hit_traveler(entity,{"damage":1000})
		check(sounds.is_empty() and app.rules.state==before and entity.hp>0,"failed hit does not play death or change entity")
		app.store.db.query("PRAGMA query_only=OFF;");app.gameplay.hit_traveler(entity,{"damage":1000})
		check(sounds==[die] and entity.hp==0 and entity.motion=="die","successful death voice once")
		var motion_time: float=entity.motion_time
		app.world.elapsed=1
		for i in range(3):app.gameplay.sync_travelers();app.gameplay.hit_traveler(entity,{"damage":1000})
		check(sounds==[die] and entity.motion_time==motion_time,"repeat sync and corpse hits do not replay voice or animation")
		sounds.clear();var snapshot: Dictionary=entity.duplicate(true);snapshot.hp=250
		app.gameplay.apply_traveler_health(snapshot,app.rules.state.traveler_health[entity.id],false)
		check(sounds.is_empty() and snapshot.motion=="die","initial corpse snapshot restores silently")
		app.elapsed=30;app.world.elapsed=30;app.gameplay.sync_travelers()
		check(entity.hp==250 and entity.motion=="stand" and sounds.is_empty(),"revival resumes quietly")
		app.gameplay.hit_traveler(entity,{"damage":249,"green_poison":true});sounds.clear()
		app.elapsed=31;app.world.elapsed=31
		check(app.rules.tick_traveler_poison(31),"committed poison tick")
		app.gameplay.sync_travelers()
		check(sounds==[die] and entity.hp==0,"poison death voice")
		app.gameplay.sync_travelers();check(sounds==[die],"poison sync voice not repeated")
		app.elapsed=61;app.gameplay.sync_travelers();sounds.clear()
		app.world.player.reset(Vector2i(entity.cell[0]+30,entity.cell[1]))
		app.gameplay.hit_traveler(entity,{"damage":1000})
		check(sounds.is_empty() and entity.hp==0,"distant death respects hearing range")
	if failures.is_empty():print("PASS: traveler_audio_test completed without failures")
	DirAccess.make_dir_recursive_absolute("res://../artifacts/world-story")
	var test_path:String=app.store.path
	var report:={"checks":checks,"failures":failures,"scope":"native audio stream dispatch, male/female hit/death and poison, committed-state failure, repeat sync, silent snapshot, revival and range; isolated fixtures, no listening or LAN test"}
	FileAccess.open("res://../artifacts/world-story/traveler-audio-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		var file_path:String=test_path+suffix
		if FileAccess.file_exists(file_path) and DirAccess.remove_absolute(file_path)!=OK:
			printerr("Cannot remove test database: "+file_path);quit(1);return
	print("TEST_DATABASE_REMOVED ",test_path)
	quit(0 if failures.is_empty() else 1)
