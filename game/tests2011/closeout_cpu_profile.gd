extends SceneTree
# Isolated CPU diagnostic; does not measure GPU rendering or real input.
var app
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate()
	app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-cpu-profile-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app)
	app.set_process(false)
	app.start_character({"id":"cpu","name":"性能诊断","job":"战士","gender":"女"})
	app.world.paused=false;app.show_bag()
	for i in range(10):await process_frame
	var methods:={"main_process":func():app._process(1.0/60),"hud_process":func():app.classic_hud._process(1.0/60),"world_update":func():app.world.update_world(1.0/60,Vector2(1280,800),false,false),"story_tracker":func():EditionRules.Story.tracker_text(app.rules.state)}
	var report:={"scope":"headless isolated CPU method timings; excludes draw/GPU and is not gameplay FPS","methods":{}}
	for key in methods:
		var samples: Array=[]
		for i in range(120):
			var start:=Time.get_ticks_usec();methods[key].call();samples.append(Time.get_ticks_usec()-start)
		samples.sort()
		report.methods[key]={"median_us":samples[60],"p95_us":samples[114],"max_us":samples[-1]}
	print(JSON.stringify(report))
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
