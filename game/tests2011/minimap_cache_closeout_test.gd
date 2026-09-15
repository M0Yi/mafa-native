extends SceneTree
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	if DisplayServer.get_name()=="headless":printerr("Requires graphical renderer");quit(2);return
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-minimap-cache-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"cache","name":"地图缓存","job":"战士","gender":"女"})
	app.world.hide() # Only the minimap renders the deliberately minimal marker fixture.
	var mini=app.classic_hud.minimap
	var cell: Vector2i=app.world.player.cell
	app.world.entities=[{"id":"marker","kind":"monster","hp":10,"cell":[cell.x+1,cell.y]}]
	await settle()
	var original: Array=mini.cached_specs.duplicate(true)
	assert(original.size()==2 and mini.marker_mesh.get_surface_count()==1)
	await settle();assert(mini.cached_specs==original)
	app.world.entities[0].cell=[cell.x+2,cell.y];await settle()
	assert(mini.cached_specs!=original and mini.cached_specs.size()==2)
	app.world.entities[0].hp=0;await settle();assert(mini.cached_specs.size()==1)
	mini.cycle_style();await settle();assert(mini.style==1 and mini.cached_specs.size()==1)
	var full: Array=mini.cached_specs.duplicate(true)
	mini.cycle_style();await settle();assert(mini.style==2)
	app.world.entities[0].hp=10
	mini.cycle_style();await settle()
	assert(mini.style==0 and mini.cached_specs.size()==2 and mini.cached_specs!=full)
	print("PASS: stationary cache, moving marker, dead marker removed, full/collapsed/nearby styles refreshed")
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
