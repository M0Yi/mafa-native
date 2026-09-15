extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate()
	app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-reservation-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"reserve","name":"占位测试","job":"战士","gender":"女"})
	var travelers: Array=app.world.entities.filter(func(e):return e.kind=="traveler")
	app.world.entities=travelers;app.world.paused=false
	var moved:=false
	for fps in [30,60,120]:
		for step in range(fps*4):
			var before: Dictionary={}
			for e in travelers:before[e.id]=app.world.actors.anchor(e)
			app.world.update_world(1.0/fps,Vector2(1280,800),false,false)
			var owners: Dictionary={}
			for e in travelers:
				var motion: ClassicPlayer=app.world.actors.mover(e)
				var distance: float=before[e.id].distance_to(motion.anchor)
				moved=moved or distance>0
				if distance>400.0/fps:failures.append("teleport")
				if not app.world.navigation.walkable(motion.cell):failures.append("wall")
				for cell in [motion.cell,motion.destination]:
					if owners.has(cell) and owners[cell]!=e.id:failures.append("shared step endpoint")
					if cell==app.world.player.cell:failures.append("player overlap")
					owners[cell]=e.id
	if not moved:failures.append("no movement")
	print(JSON.stringify({"scope":"four actual village travelers, 12 simulated seconds at 30/60/120 Hz; endpoint collision and smooth movement; no hardware FPS claim","failures":failures,"moved":moved}))
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit(0 if failures.is_empty() else 1)
