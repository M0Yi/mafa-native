extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String):
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate()
	app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-audio-queue-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"queue","name":"音效队列","job":"战士","gender":"女"})
	var sounds: Array=[];app.sound_started.connect(func(id):sounds.append(id))
	for fps in [30,60,120]:
		sounds.clear();app.elapsed=0;app.world.paused=true
		app.gameplay.spell_events=[{"at":0.14,"map":"0","skill":"halfmoon","stage":1}]
		for i in range(10):app.gameplay.update(1.0/fps)
		check(sounds.is_empty() and app.gameplay.spell_events.size()==1,"pause "+str(fps))
		app.world.paused=false
		for i in range(fps):
			app.elapsed+=1.0/fps;app.gameplay.update_spell_effects()
		check(sounds.count(133)==1 and app.gameplay.spell_events.is_empty(),"once "+str(fps))
	# An overdue event after a frame stall must still play only once.
	sounds.clear();app.gameplay.spell_events=[{"at":app.elapsed+0.14,"map":"0","skill":"flame","stage":1}]
	app.elapsed+=3;app.gameplay.update_spell_effects();app.gameplay.update_spell_effects()
	check(sounds.count(137)==1,"stall once")
	sounds.clear();app.gameplay.spell_events=[{"at":0,"map":"3","skill":"flame","stage":1}]
	app.gameplay.update_spell_effects()
	check(sounds.is_empty() and app.gameplay.spell_events.is_empty(),"different map discarded")
	app.gameplay.spell_events=[{"at":app.elapsed+1,"map":"0","skill":"flame","stage":1}]
	var next: Dictionary=app.rules.state.duplicate(true);next.hp=0
	check(app.rules.apply(next,"queue_death_fixture"),"death fixture committed")
	app.gameplay.update(0)
	check(app.gameplay.spell_events.is_empty(),"death queue cleared")
	print(JSON.stringify({"failures":failures,"scope":"real gameplay queue and sound_started signal; 30/60/120 simulated Hz, pause, stall, map mismatch and death fixture; not listening or actual cast input"}))
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit(0 if failures.is_empty() else 1)
