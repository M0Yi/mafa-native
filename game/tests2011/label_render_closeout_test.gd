extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":printerr("Graphical renderer required for label pixel verification");quit(2);return
	root.size=Vector2i(1280,800)
	var app=load("res://edition2011.tscn").instantiate()
	app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-label-render-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"labels","name":"名称测试","job":"战士","gender":"女"})
	app.world.update_world(0,Vector2(1280,800),false,false);app.world.paused=true;app.set_process(true)
	var traveler: Dictionary=app.world.entities.filter(func(e):return e.kind=="traveler")[0]
	var start: Vector2=app.world.actors.anchor(traveler)
	app.world.paused=false
	for i in range(180):await process_frame
	var moved: bool=app.world.actors.anchor(traveler).distance_to(start)>0.1
	app.world.paused=true
	# Keep the observed traveler in view after wandering near the viewport edge.
	app.world.player.reset(app.world.actors.mover(traveler).cell+Vector2i(1,0))
	var report:={"scope":"native renderer, actual AI movement then frozen injured/full-health fixtures; no hardware input or natural damage claim","moved":moved,"phases":{}}
	for phase in ["injured","full"]:
		traveler.hp=int(traveler.max_hp)/2 if phase=="injured" else traveler.max_hp
		for i in range(10):await process_frame
		await RenderingServer.frame_post_draw
		var info: Dictionary=app.world.labels.layout(traveler)
		var im:=root.get_texture().get_image()
		im.save_png("res://../artifacts/closeout-label-"+phase+".png")
		app.world.labels.hide()
		await process_frame;await RenderingServer.frame_post_draw
		var without:=root.get_texture().get_image()
		var region:=Rect2i(info.name_rect).intersection(Rect2i(Vector2i.ZERO,im.get_size()))
		var changed:=0
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				if im.get_pixel(x,y)!=without.get_pixel(x,y):changed+=1
		app.world.labels.show()
		report.phases[phase]={"name_pixels":changed,"health_visible":info.health_rect.has_area()}
	var passed: bool=moved and report.phases.injured.name_pixels>0 and report.phases.full.name_pixels>0 and report.phases.injured.health_visible and not report.phases.full.health_visible
	print(JSON.stringify(report))
	FileAccess.open("res://../artifacts/closeout-label-motion.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit(0 if passed else 1)
